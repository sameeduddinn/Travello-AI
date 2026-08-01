import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/utils/column_row_utils.dart';
import 'package:flight_app/utils/booking_service.dart';
import 'package:flight_app/services/notification_service.dart';
import 'package:flight_app/services/transactional_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/route_manager.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'dart:math' show pi;
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flight_app/screens/railway/train_results_screen.dart';
import 'package:flight_app/models/airport.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  🎯 PROFESSIONAL PAYMENT SUCCESS PAGE
//  Travello AI - Industry-Level Booking Confirmation
//  Designed with best practices from Wego, Expedia, Booking.com
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ── Data classes for travel info & extras ──
class _CheckItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  const _CheckItem(this.icon, this.title, this.subtitle, this.tag);
}

class _TravelExtra {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String tag;
  final Color tagColor;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  const _TravelExtra({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });
}

class PaymentStatus extends StatefulWidget {
  const PaymentStatus({super.key});

  @override
  State<PaymentStatus> createState() => _PaymentStatusState();
}

class _PaymentStatusState extends State<PaymentStatus>
    with TickerProviderStateMixin {
  // ── State Management ──
  bool _isLoading = false;
  bool _downloadingPdf = false;
  bool _copyingPnr = false;

  // ── Booking Data from Arguments ──
  Map<String, dynamic> _bookingData = {};

  // ── Animation Controllers ──
  late AnimationController _animationController;
  late AnimationController _checkmarkController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkmarkScale;
  late Animation<double> _checkmarkRotation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBookingData();
  }

  void _initializeAnimations() {
    // Main container animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Checkmark animation with bounce and rotation
    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _checkmarkScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_checkmarkController);

    _checkmarkRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkmarkController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
  }

  void _playSuccessAnimations() {
    _animationController
      ..reset()
      ..forward();

    _checkmarkController.reset();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _checkmarkController.forward();
      }
    });
  }

  Future<void> _loadBookingData() async {
    setState(() => _isLoading = true);

    // Get arguments from navigation
    final args = Get.arguments as Map<String, dynamic>? ?? {};

    // Detect booking type
    final bookingType = args['bookingType'] as String? ?? 'flight';

    // Common data
    final passengers = args['passengers'] as List<dynamic>? ?? [];
    final grandTotal = args['grandTotal'] as double? ?? 0.0;
    final baseFare = args['baseFare'] as double? ?? 0.0;
    final taxes = args['taxes'] as double? ?? 0.0;
    final serviceFee = args['serviceFee'] as double? ?? 0.0;
    final baggageFee = args['baggageFee'] as double? ?? 0.0;
    final insuranceFee = args['insuranceFee'] as double? ?? 0.0;
    final discount = args['discount'] as double? ?? 0.0;
    final isRoundTrip = args['isRoundTrip'] == true;
    final departureDate = args['departureDate'] as DateTime?;
    final returnDate = args['returnDate'] as DateTime?;

    // Format date
    final dateFormatter = DateFormat('dd MMM yyyy');

    _bookingData = {
      'pnr': args['pnr'] ?? 'N/A',
      'transactionId': args['transactionId'] ?? 'N/A',
      'date': dateFormatter.format(DateTime.now()),
      'paymentMethod': args['paymentMethod'] ?? 'N/A',
      'amount': baseFare,
      'tax': taxes,
      'serviceFee': serviceFee,
      'baggageFee': baggageFee,
      'insuranceFee': insuranceFee,
      'discount': discount,
      'total': grandTotal,
      'currency': 'PKR ',
      'status': 'success',
      'bookingType': bookingType,
      'passengerName': passengers.isNotEmpty
          ? '${passengers[0]['firstName']} ${passengers[0]['lastName']}'
          : 'N/A',
      'email': args['contactEmail'] ?? 'N/A',
      'phone': args['contactPhone'] ?? 'N/A',
      'isRoundTrip': isRoundTrip,
      'returnDate': returnDate?.toIso8601String(),
      'departureDate': departureDate?.toIso8601String(),
      'passengerCount': passengers.length,
      // ── Full passenger list for e-ticket ──
      'allPassengers': passengers
          .map((p) => <String, dynamic>{
                'firstName': p['firstName']?.toString() ?? '',
                'lastName': p['lastName']?.toString() ?? '',
                'name':
                    '${(p['firstName'] ?? '')} ${(p['lastName'] ?? '')}'.trim(),
                'passportOrId':
                    (p['passportNumber']?.toString().isNotEmpty == true)
                        ? p['passportNumber'].toString()
                        : (p['idNumber']?.toString().isNotEmpty == true)
                            ? p['idNumber'].toString()
                            : (p['bForm']?.toString().isNotEmpty == true)
                                ? p['bForm'].toString()
                                : (p['cnic']?.toString().isNotEmpty == true)
                                    ? p['cnic'].toString()
                                    : (p['nationalId']?.toString() ?? ''),
                'documentType': p['documentType']?.toString() ?? 'Passport',
                'nationality': p['nationality']?.toString() ?? '',
                'salutation': p['salutation']?.toString() ?? '',
                // Document numbers - preserve all fields
                'cnic': p['nationalId']?.toString() ?? '',
                'nationalId': p['nationalId']?.toString() ?? '',
                'bForm': p['bForm']?.toString() ?? '',
                'passportNumber': p['passportNumber']?.toString() ?? '',
                // Other fields
                'phone': p['phone']?.toString() ?? '',
                'age': p['age']?.toString() ?? '',
                'gender': p['gender']?.toString() ?? 'Male',
                'concessionType': p['concessionType']?.toString() ?? 'ADULT',
                'dateOfBirth': p['dateOfBirth']?.toString() ?? '',
              })
          .toList(),
      'weather': {
        'temp': '28°C',
        'condition': 'Sunny',
      },
    };

    if (bookingType == 'train') {
      // Load train-specific data
      final train = args['train'] as TrainResult?;
      final outboundTrain = args['outboundTrain'] as TrainResult?;
      final returnTrain = args['returnTrain'] as TrainResult?;
      final selectedClass = args['selectedClass'] as String? ?? 'Economy';
      final fromStation = args['fromStation'] as String? ?? 'N/A';
      final toStation = args['toStation'] as String? ?? 'N/A';
      final fromStationCode = args['fromStationCode'] as String? ?? 'N/A';
      final toStationCode = args['toStationCode'] as String? ?? 'N/A';

      _bookingData['trainDetails'] = {
        'trainName':
            (isRoundTrip ? outboundTrain?.trainName : train?.trainName) ??
                'N/A',
        'trainNumber':
            (isRoundTrip ? outboundTrain?.trainNumber : train?.trainNumber) ??
                'N/A',
        'from': fromStation,
        'to': toStation,
        'fromCode': fromStationCode,
        'toCode': toStationCode,
        'departure': (isRoundTrip
                ? outboundTrain?.departureTime
                : train?.departureTime) ??
            'N/A',
        'arrival':
            (isRoundTrip ? outboundTrain?.arrivalTime : train?.arrivalTime) ??
                'N/A',
        'duration':
            (isRoundTrip ? outboundTrain?.duration : train?.duration) ?? 'N/A',
        'date':
            departureDate != null ? dateFormatter.format(departureDate) : 'N/A',
        'class': selectedClass,
        'arrivesNextDay': (isRoundTrip
                ? outboundTrain?.arrivesNextDay
                : train?.arrivesNextDay) ??
            false,
      };

      // Train-specific booking reference fields (generated by railway_booking_payment)
      _bookingData['coach'] = args['coach'] ?? 'B-1';
      _bookingData['seatNumbers'] =
          (args['seatNumbers'] as List<dynamic>?) ?? <dynamic>[];
      _bookingData['ticketNumbers'] =
          (args['ticketNumbers'] as List<dynamic>?) ?? <dynamic>[];

      // Store actual seat selections for round trip
      if (isRoundTrip) {
        final rawOutbound =
            (args['outboundSeatSelections'] as List<dynamic>?) ?? [];
        _bookingData['outboundSeatSelections'] = rawOutbound
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();

        final rawReturn =
            (args['returnSeatSelections'] as List<dynamic>?) ?? [];
        _bookingData['returnSeatSelections'] =
            rawReturn.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      } else {
        final rawSeats = (args['seatSelections'] as List<dynamic>?) ?? [];
        _bookingData['seatSelections'] =
            rawSeats.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      }

      if (isRoundTrip && returnTrain != null) {
        _bookingData['returnTrainDetails'] = {
          'trainName': returnTrain.trainName,
          'trainNumber': returnTrain.trainNumber,
          'from': toStation,
          'to': fromStation,
          'fromCode': toStationCode,
          'toCode': fromStationCode,
          'departure': returnTrain.departureTime,
          'arrival': returnTrain.arrivalTime,
          'duration': returnTrain.duration,
          'date': returnDate != null ? dateFormatter.format(returnDate) : 'N/A',
          'class': args['returnClass'] as String? ?? selectedClass,
          'arrivesNextDay': returnTrain.arrivesNextDay,
        };
      }
    } else {
      // Load flight-specific data
      final flight = args['flight'] as FlightResult?;
      final fromAirport = args['fromAirport'] as Airport?;
      final toAirport = args['toAirport'] as Airport?;
      final returnFlight = args['returnFlight'] as FlightResult?;

      _bookingData['flightDetails'] = {
        'airline': flight?.airlineName ?? 'N/A',
        'flightNumber': flight?.airlineCode ?? 'N/A',
        'from': '${fromAirport?.name ?? 'N/A'} (${fromAirport?.code ?? 'N/A'})',
        'to': '${toAirport?.name ?? 'N/A'} (${toAirport?.code ?? 'N/A'})',
        'departure': flight?.departureTime ?? 'N/A',
        'arrival': flight?.arrivalTime ?? 'N/A',
        'duration': flight?.duration ?? 'N/A',
        'date':
            departureDate != null ? dateFormatter.format(departureDate) : 'N/A',
        'class': flight?.cabinClass ?? 'Economy',
        'seats': [],
        'departureTerminal': _getTerminal(fromAirport?.code, isDeparture: true),
        'arrivalTerminal': _getTerminal(toAirport?.code, isDeparture: false),
        'gate': _generateGate(flight?.airlineCode),
      };

      // Store flight seat selections
      if (isRoundTrip) {
        final rawOutbound =
            (args['outboundSeatSelections'] as List<dynamic>?) ?? [];
        _bookingData['outboundSeatSelections'] = rawOutbound
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();

        final rawReturn =
            (args['returnSeatSelections'] as List<dynamic>?) ?? [];
        _bookingData['returnSeatSelections'] =
            rawReturn.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      } else {
        final rawSeats = (args['seatSelections'] as List<dynamic>?) ?? [];
        _bookingData['seatSelections'] =
            rawSeats.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      }
      _bookingData['seatTotal'] = (args['seatTotal'] as double?) ?? 0.0;

      // ── Baggage data ──
      final rawBaggage = (args['baggageData'] as List<dynamic>?) ?? [];
      _bookingData['baggageData'] =
          rawBaggage.map((b) => Map<String, dynamic>.from(b as Map)).toList();
      final rawReturnBaggage =
          (args['returnBaggageData'] as List<dynamic>?) ?? [];
      _bookingData['returnBaggageData'] = rawReturnBaggage
          .map((b) => Map<String, dynamic>.from(b as Map))
          .toList();

      if (isRoundTrip && returnFlight != null) {
        _bookingData['returnFlightDetails'] = {
          'airline': returnFlight.airlineName,
          'flightNumber': returnFlight.airlineCode,
          'from': '${toAirport?.name ?? 'N/A'} (${toAirport?.code ?? 'N/A'})',
          'to': '${fromAirport?.name ?? 'N/A'} (${fromAirport?.code ?? 'N/A'})',
          'departure': returnFlight.departureTime,
          'arrival': returnFlight.arrivalTime,
          'duration': returnFlight.duration,
          'date': returnDate != null ? dateFormatter.format(returnDate) : 'N/A',
          'class': returnFlight.cabinClass,
          'departureTerminal': _getTerminal(toAirport?.code, isDeparture: true),
          'arrivalTerminal':
              _getTerminal(fromAirport?.code, isDeparture: false),
          'gate': _generateGate(returnFlight.airlineCode),
        };
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // 💾 Save booking to local storage — use backend booking_id (TRV-FL-...)
    // as bookingId so my_bookings.dart dedup correctly matches the backend entry.
    final backendBookingId = args['backendBookingId']?.toString() ?? '';
    _bookingData['bookingId'] = backendBookingId.isNotEmpty
        ? backendBookingId
        : (_bookingData['pnr']?.toString() ?? 'BK${DateTime.now().millisecondsSinceEpoch}');
    await BookingService.saveBooking(_bookingData);

    // ☁️ Sync booking/payment to Supabase and trigger transactional email.
    // These calls are non-blocking for UX; local success screen still proceeds.
    final bookingId =
        (_bookingData['bookingId'] ?? _bookingData['pnr'] ?? '').toString();
    final resolvedBookingId = bookingId.isNotEmpty
        ? bookingId
        : 'BK${DateTime.now().millisecondsSinceEpoch}';

    await TransactionalService.saveBookingToSupabase(_bookingData);
    await TransactionalService.savePaymentAttemptToSupabase(
      bookingId: resolvedBookingId,
      paymentMethod: (_bookingData['paymentMethod'] ?? 'unknown').toString(),
      amount: (_bookingData['total'] as num?)?.toDouble() ?? 0,
      status: 'success',
      metadata: {
        'transactionId': _bookingData['transactionId'],
        'bookingType': _bookingData['bookingType'],
      },
    );
    final emailSent = await TransactionalService.sendBookingConfirmationEmail(
      bookingData: _bookingData,
    );
    final emailAddress = (_bookingData['email'] ?? '').toString();
    if (mounted) {
      if (emailSent && emailAddress.isNotEmpty && emailAddress != 'N/A') {
        Get.snackbar(
          'Confirmation Email Sent',
          'Booking confirmation sent to $emailAddress. Check your inbox (and spam folder).',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF34A853).withValues(alpha: 0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.all(12),
        );
      } else {
        final reason = TransactionalService.lastError ??
            (emailAddress.isEmpty || emailAddress == 'N/A'
                ? 'No contact email found.'
                : 'Email service unavailable.');
        Get.snackbar(
          'Email Not Sent',
          reason,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade700.withValues(alpha: 0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 6),
          margin: const EdgeInsets.all(12),
        );
      }
    }

    // 🔔 Push notification for this booking
    _pushBookingNotification(bookingType, args);

    if (!mounted) return;
    setState(() => _isLoading = false);
    _playSuccessAnimations();
  }

  void _pushBookingNotification(String bookingType, Map<String, dynamic> args) {
    try {
      final pnr = _bookingData['pnr']?.toString() ?? 'N/A';
      if (bookingType == 'train') {
        final td = _bookingData['trainDetails'] as Map? ?? {};
        final seats =
            (_bookingData['seatNumbers'] as List?)?.join(', ') ?? 'N/A';
        final coach = _bookingData['coach']?.toString() ?? 'N/A';
        NotificationService.instance.trainBooked(
          trainName: td['trainName']?.toString() ?? 'N/A',
          fromStation: td['from']?.toString() ?? 'N/A',
          toStation: td['to']?.toString() ?? 'N/A',
          date: td['date']?.toString() ?? 'N/A',
          departure: td['departure']?.toString() ?? 'N/A',
          seatClass: td['class']?.toString() ?? 'Economy',
          coach: coach,
          seat: seats,
          pnr: pnr,
        );
      } else {
        final fd = _bookingData['flightDetails'] as Map? ?? {};
        final airline = fd['airline']?.toString() ?? 'Flight';
        final flightNum = fd['flightNumber']?.toString() ?? '';
        final from = fd['from']?.toString() ?? 'N/A';
        final to = fd['to']?.toString() ?? 'N/A';

        // Detect round-trip return details
        final isRoundTrip =
            args['isRoundTrip'] == true || _bookingData['tripType'] == 'round';
        final rfd = _bookingData['returnFlightDetails'] as Map?;
        NotificationService.instance.flightBooked(
          airline: airline,
          flightNumber: flightNum,
          fromCode: from,
          toCode: to,
          date: fd['date']?.toString() ?? 'N/A',
          departure: fd['departure']?.toString() ?? 'N/A',
          pnr: pnr,
          seatClass: fd['class']?.toString() ?? 'Economy',
          // Round-trip return fields
          returnDate: isRoundTrip
              ? (rfd?['date']?.toString() ?? args['returnDate']?.toString())
              : null,
          returnDeparture: isRoundTrip
              ? (rfd?['departure']?.toString() ??
                  args['returnDeparture']?.toString())
              : null,
          returnFlightNumber: isRoundTrip
              ? (rfd?['flightNumber']?.toString() ??
                  args['returnFlightNumber']?.toString() ??
                  '')
              : null,
        );
      }
    } catch (_) {
      // Never crash on notification injection failure
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  // ── Terminal & Gate Helper Functions ──
  String _getTerminal(String? airportCode, {required bool isDeparture}) {
    if (airportCode == null) return '1';

    // Pakistani airport terminal mapping
    switch (airportCode.toUpperCase()) {
      case 'KHI': // Jinnah International Airport, Karachi
        return isDeparture ? '2' : '2'; // Domestic Terminal 2
      case 'LHE': // Allama Iqbal International Airport, Lahore
        return '3'; // Terminal 3 for domestic
      case 'ISB': // Islamabad International Airport
        return '1'; // Main terminal
      case 'PEW': // Bacha Khan International Airport, Peshawar
        return '1';
      case 'UET': // Quetta International Airport
        return '1';
      case 'MUX': // Multan International Airport
        return '1';
      case 'LYP': // Faisalabad International Airport
        return '1';
      case 'SKT': // Sialkot International Airport
        return '1';
      default:
        return '1';
    }
  }

  String _generateGate(String? flightCode) {
    if (flightCode == null || flightCode.isEmpty) return 'A1';

    // Generate gate based on flight code for consistency
    final hashCode = flightCode.hashCode.abs();
    final gateNumber = (hashCode % 30) + 1; // Gates 1-30
    final gateLetter = String.fromCharCode(65 + (hashCode % 8)); // A-H

    return '$gateLetter$gateNumber';
  }

  // ── Helper Functions ──
  Color _statusColor(String status) {
    switch (status) {
      case 'error':
        return const Color(0xFFDC2626);
      case 'waiting':
        return const Color(0xFFF59E0B);
      case 'success':
        return const Color(0xFF10B981);
      default:
        return Colors.transparent;
    }
  }

  String _formatPKR(double? amount) {
    if (amount == null) return 'PKR 0';
    final formatter = NumberFormat('#,##,###', 'en_PK');
    return 'PKR ${formatter.format(amount.round())}';
  }

  String _calculateArrivalTime(String departureTime) {
    try {
      // Parse departure time (format: HH:mm)
      final parts = departureTime.split(':');
      if (parts.length != 2) return '$departureTime + 2h';

      int hours = int.parse(parts[0]);
      int minutes = int.parse(parts[1]);

      // Add 2 hours for estimated flight duration
      hours += 2;
      if (hours >= 24) hours -= 24;

      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } catch (e) {
      return '$departureTime + 2h';
    }
  }

  Future<void> _copyPnr() async {
    setState(() => _copyingPnr = true);
    await Clipboard.setData(ClipboardData(text: _bookingData['pnr'] ?? 'N/A'));
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _copyingPnr = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('PNR copied to clipboard!'),
            ],
          ),
          backgroundColor: _statusColor('success'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── real PDF helpers (reused from ProfessionalETicket) ──
  static const _pdfNavy = PdfColor(0.059, 0.176, 0.361);
  static const _pdfBlue = PdfColor(0.145, 0.388, 0.922);
  static const _pdfEmerald = PdfColor(0.063, 0.725, 0.506);
  static const _pdfRose = PdfColor(0.957, 0.247, 0.369);
  static const _pdfIce = PdfColor(0.941, 0.965, 1.0);
  static const _pdfBorder = PdfColor(0.886, 0.922, 0.965);
  static const _pdfTextSec = PdfColor(0.392, 0.455, 0.545);
  static const _pdfBlueIce = PdfColor(0.937, 0.965, 1.0);

  pw.Widget _pdfChip(String label, String val, PdfColor accent) =>
      pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 7, color: _pdfTextSec)),
        pw.SizedBox(height: 2),
        pw.Text(val,
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent)),
      ]);

  pw.Widget _pdfVDiv() => pw.Container(width: 1, height: 28, color: _pdfBorder);

  pw.Widget _pdfTile(String label, String val) => pw.Container(
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          color: _pdfIce,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: _pdfBorder),
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 7,
                      color: _pdfTextSec,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.3)),
              pw.SizedBox(height: 3),
              pw.Text(val,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfNavy),
                  overflow: pw.TextOverflow.clip),
            ]),
      );

  void _addTicketPage(
    pw.Document doc, {
    required bool isReturn,
    required String passengerName,
    required String passportOrId,
    String documentType = 'Passport',
    String nationality = '',
    String seatNumber = 'N/A',
  }) {
    final fd = _bookingData['flightDetails'] as Map<String, dynamic>?;
    final rfd = _bookingData['returnFlightDetails'] as Map<String, dynamic>?;
    final src = isReturn ? (rfd ?? fd) : fd;
    final airline = src?['airline'] as String? ?? 'Airline';
    final fltNum = src?['flightNumber'] as String? ?? 'N/A';
    final cabin = src?['class'] as String? ?? 'Economy';
    final depTime = src?['departure'] as String? ?? '--:--';
    final arrTime = src?['arrival'] as String? ?? '--:--';
    final dur = src?['duration'] as String? ?? '--';
    final date = src?['date'] as String? ?? '--';
    final fromFull = isReturn
        ? (src?['from'] as String? ?? (fd?['to'] as String? ?? 'Origin'))
        : (fd?['from'] as String? ?? 'Origin');
    final toFull = isReturn
        ? (src?['to'] as String? ?? (fd?['from'] as String? ?? 'Dest'))
        : (fd?['to'] as String? ?? 'Dest');

    // city-code helper
    String code(String s) {
      final m = RegExp(r'\(([^)]+)\)').firstMatch(s);
      return m?.group(1) ?? s.substring(0, s.length.clamp(0, 3)).toUpperCase();
    }

    String city(String s) => s.split('(').first.trim();
    String shortDate(String raw) {
      try {
        return DateFormat('EEE, MMM d')
            .format(DateFormat('dd MMM yyyy').parse(raw));
      } catch (_) {
        return raw;
      }
    }

    final fromCode = code(fromFull);
    final toCode = code(toFull);
    final fromCity = city(fromFull);
    final toCity = city(toFull);
    final pnr = _bookingData['pnr'] as String? ?? 'TRV000000';
    final payMethod = _bookingData['paymentMethod'] as String? ?? 'N/A';
    final barcodeD = '$pnr-${isReturn ? 'R' : 'O'}-$fltNum';
    final qrStr = 'TRAVELLO|PNR:$pnr|PAX:$passengerName|FLT:$fltNum';
    final dirLabel = isReturn ? 'RETURN FLIGHT' : 'OUTBOUND FLIGHT';

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: isReturn ? _pdfEmerald : _pdfNavy,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Text(dirLabel,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1)),
            ),
            pw.SizedBox(width: 10),
            pw.Text('PNR: $pnr',
                style: const pw.TextStyle(fontSize: 10, color: _pdfTextSec)),
            pw.Spacer(),
            pw.Text('Travello AI  -  E-Ticket',
                style: pw.TextStyle(
                    fontSize: 10,
                    color: _pdfNavy,
                    fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 10),
          pw.Container(
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
              border: pw.Border.all(color: _pdfBorder),
              color: PdfColors.white,
            ),
            child: pw.Column(children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: const pw.BoxDecoration(
                  color: _pdfNavy,
                  borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(14),
                      topRight: pw.Radius.circular(14)),
                ),
                child: pw.Row(children: [
                  pw.Container(
                    width: 42,
                    height: 42,
                    decoration: const pw.BoxDecoration(
                      color: PdfColor(0.18, 0.28, 0.48),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                    ),
                    child: pw.Center(
                      child: pw.Text('FL',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(airline,
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: const pw.BoxDecoration(
                              color: PdfColor(0.18, 0.28, 0.48),
                              borderRadius:
                                  pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(fltNum,
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 0.8)),
                          ),
                        ]),
                  ),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor(0.063, 0.725, 0.506, 0.22),
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(12)),
                            border: pw.Border.all(
                                color:
                                    const PdfColor(0.063, 0.725, 0.506, 0.55)),
                          ),
                          child: pw.Text('CONFIRMED',
                              style: pw.TextStyle(
                                  color: _pdfEmerald,
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8)),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor(0.18, 0.28, 0.48),
                            borderRadius:
                                pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Text(cabin,
                              style: const pw.TextStyle(
                                  color: PdfColors.white, fontSize: 9)),
                        ),
                      ]),
                ]),
              ),
              // Route
              pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.fromLTRB(24, 20, 24, 14),
                child: pw.Column(children: [
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(fromCity,
                                    style: const pw.TextStyle(
                                        fontSize: 8, color: _pdfTextSec)),
                                pw.SizedBox(height: 3),
                                pw.Text(fromCode,
                                    style: pw.TextStyle(
                                        fontSize: 28,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _pdfNavy,
                                        letterSpacing: 2)),
                                pw.SizedBox(height: 5),
                                pw.Text(depTime,
                                    style: pw.TextStyle(
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _pdfNavy)),
                                pw.SizedBox(height: 2),
                                pw.Text(date,
                                    style: const pw.TextStyle(
                                        fontSize: 8, color: _pdfTextSec)),
                              ]),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(dur,
                                    style: const pw.TextStyle(
                                        fontSize: 8, color: _pdfTextSec)),
                                pw.SizedBox(height: 5),
                                pw.Row(children: [
                                  pw.Container(
                                      width: 6,
                                      height: 6,
                                      decoration: pw.BoxDecoration(
                                          border: pw.Border.all(
                                              color: _pdfBlue, width: 1.5),
                                          shape: pw.BoxShape.circle)),
                                  pw.Container(
                                      width: 18,
                                      height: 1.5,
                                      color: const PdfColor(
                                          0.145, 0.388, 0.922, 0.3)),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(4),
                                    decoration: const pw.BoxDecoration(
                                        color: _pdfBlueIce,
                                        shape: pw.BoxShape.circle),
                                    child: pw.Text('>',
                                        style: pw.TextStyle(
                                            color: _pdfBlue,
                                            fontSize: 9,
                                            fontWeight: pw.FontWeight.bold)),
                                  ),
                                  pw.Container(
                                      width: 18,
                                      height: 1.5,
                                      color: const PdfColor(
                                          0.145, 0.388, 0.922, 0.3)),
                                  pw.Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const pw.BoxDecoration(
                                          color: _pdfBlue,
                                          shape: pw.BoxShape.circle)),
                                ]),
                                pw.SizedBox(height: 5),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: const pw.BoxDecoration(
                                    color: _pdfBlueIce,
                                    borderRadius: pw.BorderRadius.all(
                                        pw.Radius.circular(4)),
                                  ),
                                  child: pw.Text('NON-STOP',
                                      style: pw.TextStyle(
                                          color: _pdfBlue,
                                          fontSize: 7,
                                          fontWeight: pw.FontWeight.bold,
                                          letterSpacing: 0.5)),
                                ),
                              ]),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(toCity,
                                    textAlign: pw.TextAlign.right,
                                    style: const pw.TextStyle(
                                        fontSize: 8, color: _pdfTextSec)),
                                pw.SizedBox(height: 3),
                                pw.Text(toCode,
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(
                                        fontSize: 28,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _pdfNavy,
                                        letterSpacing: 2)),
                                pw.SizedBox(height: 5),
                                pw.Text(arrTime,
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(
                                        fontSize: 14,
                                        fontWeight: pw.FontWeight.bold,
                                        color: _pdfNavy)),
                                pw.SizedBox(height: 2),
                                pw.Text(date,
                                    textAlign: pw.TextAlign.right,
                                    style: const pw.TextStyle(
                                        fontSize: 8, color: _pdfTextSec)),
                              ]),
                        ),
                      ]),
                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: _pdfIce,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: _pdfBorder),
                    ),
                    child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _pdfChip('SEAT', seatNumber,
                              seatNumber == 'N/A' ? _pdfTextSec : _pdfBlue),
                          _pdfVDiv(),
                          _pdfChip('GATE', src?['gate'] as String? ?? 'N/A',
                              _pdfRose),
                          _pdfVDiv(),
                          _pdfChip(
                              'TERMINAL',
                              src?['departureTerminal'] as String? ?? 'N/A',
                              _pdfTextSec),
                          _pdfVDiv(),
                          _pdfChip('BOARDS AT', depTime, _pdfBlue),
                        ]),
                  ),
                ]),
              ),
              // Tear-line
              pw.Row(children: [
                pw.Container(
                    width: 14,
                    height: 14,
                    decoration: const pw.BoxDecoration(
                        color: PdfColor(0.945, 0.961, 0.973),
                        shape: pw.BoxShape.circle)),
                pw.Expanded(child: pw.Divider(color: _pdfBorder, thickness: 1)),
                pw.Container(
                    width: 14,
                    height: 14,
                    decoration: const pw.BoxDecoration(
                        color: PdfColor(0.945, 0.961, 0.973),
                        shape: pw.BoxShape.circle)),
              ]),
              // Passenger
              pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: pw.Column(children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: _pdfBlueIce,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(10)),
                      border: pw.Border.all(color: _pdfBorder),
                    ),
                    child: pw.Row(children: [
                      pw.Container(
                        width: 36,
                        height: 36,
                        decoration: const pw.BoxDecoration(
                          color: PdfColor(0.145, 0.388, 0.922, 0.12),
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text('PAX',
                              style: pw.TextStyle(
                                  color: _pdfBlue,
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('PASSENGER',
                                  style: pw.TextStyle(
                                      fontSize: 7,
                                      color: _pdfTextSec,
                                      fontWeight: pw.FontWeight.bold,
                                      letterSpacing: 0.5)),
                              pw.SizedBox(height: 3),
                              pw.Text(passengerName,
                                  style: pw.TextStyle(
                                      fontSize: 13,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _pdfNavy)),
                            ]),
                      ),
                      if (passportOrId.isNotEmpty)
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                  nationality == 'Pakistan' &&
                                          documentType == 'CNIC'
                                      ? 'CNIC'
                                      : 'PASSPORT',
                                  style: const pw.TextStyle(
                                      fontSize: 7, color: _pdfTextSec)),
                              pw.SizedBox(height: 3),
                              pw.Text(passportOrId,
                                  style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _pdfNavy)),
                            ]),
                    ]),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(children: [
                    pw.Expanded(child: _pdfTile('THIS TICKET', '1 Passenger')),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: _pdfTile('PAID VIA', payMethod)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: _pdfTile('DATE', shortDate(date))),
                  ]),
                  pw.SizedBox(height: 12),
                ]),
              ),
              // Scan
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(14),
                      bottomRight: pw.Radius.circular(14)),
                ),
                padding: const pw.EdgeInsets.fromLTRB(22, 0, 22, 18),
                child: pw.Column(children: [
                  pw.Row(children: [
                    pw.Expanded(
                        child: pw.Divider(color: _pdfBorder, thickness: 1)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                      child: pw.Text('SCAN AT GATE',
                          style: pw.TextStyle(
                              fontSize: 7,
                              color: _pdfTextSec,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5)),
                    ),
                    pw.Expanded(
                        child: pw.Divider(color: _pdfBorder, thickness: 1)),
                  ]),
                  pw.SizedBox(height: 10),
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Column(children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.code128(),
                              data: barcodeD,
                              width: double.infinity,
                              height: 50,
                              drawText: false,
                              color: _pdfNavy,
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(pnr,
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 3,
                                    color: _pdfTextSec)),
                            pw.SizedBox(height: 2),
                            pw.Text('Scan at boarding gate',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                    fontSize: 7, color: _pdfTextSec)),
                          ]),
                        ),
                        pw.Container(
                            margin:
                                const pw.EdgeInsets.symmetric(horizontal: 14),
                            width: 1,
                            height: 66,
                            color: _pdfBorder),
                        pw.Column(children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(8)),
                              border:
                                  pw.Border.all(color: _pdfBorder, width: 1.5),
                            ),
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrStr,
                              width: 62,
                              height: 62,
                              color: _pdfNavy,
                              drawText: false,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('QUICK SCAN',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                  fontSize: 7,
                                  color: _pdfTextSec,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.5)),
                        ]),
                      ]),
                  pw.SizedBox(height: 12),
                  pw.Center(
                    child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
                      pw.Container(
                        width: 16,
                        height: 16,
                        decoration: const pw.BoxDecoration(
                          color: _pdfNavy,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Center(
                            child: pw.Text('T',
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold))),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text('Travello AI  -  Verified & Secure Ticket',
                          style: const pw.TextStyle(
                              fontSize: 8, color: _pdfTextSec)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          pw.SizedBox(height: 14),
          // Tips
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: _pdfBorder),
              color: PdfColors.white,
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Travel Guidelines',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _pdfNavy)),
                  pw.SizedBox(height: 8),
                  ...[
                    'Arrive at least 2 hours before departure',
                    'Carry valid CNIC / Passport and this e-ticket',
                    'Check-in closes 45 minutes before departure',
                    'Baggage allowance: 20 kg checked + 7 kg cabin',
                    'Web check-in opens 24 hours before departure',
                  ].map((tip) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 5),
                        child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('•  ',
                                  style: pw.TextStyle(
                                      color: _pdfBlue,
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Expanded(
                                  child: pw.Text(tip,
                                      style: const pw.TextStyle(
                                          fontSize: 9, color: _pdfTextSec))),
                            ]),
                      )),
                  pw.SizedBox(height: 4),
                  pw.Divider(color: _pdfBorder, thickness: 1),
                  pw.Center(
                    child: pw.Text('support@travello.pk  -  +92 300 1234567',
                        style: const pw.TextStyle(
                            fontSize: 8, color: _pdfTextSec)),
                  ),
                ]),
          ),
        ],
      ),
    ));
  }

  Future<void> _downloadTicket() async {
    setState(() => _downloadingPdf = true);
    try {
      // Load Unicode-supporting font to eliminate warnings
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
      );
      final actualPax = _bookingData['allPassengers'] is List &&
              (_bookingData['allPassengers'] as List).isNotEmpty
          ? (_bookingData['allPassengers'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [
              {
                'name': _bookingData['passengerName'] ?? 'Passenger',
                'passportOrId': ''
              }
            ];

      // Get seat selections
      final isRoundTrip = _bookingData['isRoundTrip'] == true;
      final outboundSeats = isRoundTrip
          ? ((_bookingData['outboundSeatSelections'] as List<dynamic>?) ?? [])
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList()
          : ((_bookingData['seatSelections'] as List<dynamic>?) ?? [])
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList();

      final returnSeats = isRoundTrip
          ? ((_bookingData['returnSeatSelections'] as List<dynamic>?) ?? [])
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList()
          : <Map<String, dynamic>>[];

      // Outbound tickets
      for (int i = 0; i < actualPax.length; i++) {
        final pax = actualPax[i];
        final seatNumber = i < outboundSeats.length
            ? (outboundSeats[i]['seatName'] as String? ?? 'N/A')
            : 'N/A';

        _addTicketPage(doc,
            isReturn: false,
            passengerName: pax['name'] as String? ?? 'Passenger',
            passportOrId: pax['passportOrId'] as String? ?? '',
            seatNumber: seatNumber);
      }

      // Return tickets
      if (isRoundTrip) {
        for (int i = 0; i < actualPax.length; i++) {
          final pax = actualPax[i];
          final seatNumber = i < returnSeats.length
              ? (returnSeats[i]['seatName'] as String? ?? 'N/A')
              : 'N/A';

          _addTicketPage(doc,
              isReturn: true,
              passengerName: pax['name'] as String? ?? 'Passenger',
              passportOrId: pax['passportOrId'] as String? ?? '',
              seatNumber: seatNumber);
        }
      }
      final pdfBytes = await doc.save();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.grey.shade100,
              appBar: AppBar(
                title: const Text('E-Ticket Preview'),
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: PdfPreview(
                build: (_) async => pdfBytes,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                initialPageFormat: PdfPageFormat.a4,
                pdfFileName:
                    'travello_eticket_${_bookingData['pnr'] ?? 'ticket'}.pdf',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('PDF generation failed. Please try again.'),
          backgroundColor: _statusColor('error'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  Future<void> _shareTicket() async {
    final pnr = _bookingData['pnr'] as String? ?? 'N/A';
    final name = _bookingData['passengerName'] as String? ?? 'N/A';
    final fd = _bookingData['flightDetails'] as Map<String, dynamic>?;
    final from = fd?['from'] as String? ?? 'N/A';
    final to = fd?['to'] as String? ?? 'N/A';
    final dep = fd?['departure'] as String? ?? 'N/A';
    final date = fd?['date'] as String? ?? 'N/A';
    final fltNum = fd?['flightNumber'] as String? ?? 'N/A';
    final isRT = _bookingData['isRoundTrip'] == true;
    final summary = 'Travello AI - E-Ticket\n'
        'PNR: $pnr\n'
        'Passenger: $name\n'
        'Flight: $fltNum  (${isRT ? "Round Trip" : "One Way"})\n'
        'Route: $from  →  $to\n'
        'Date: $date  |  Dep: $dep\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━\n'
        'Booked via Travello AI';
    await Clipboard.setData(ClipboardData(text: summary));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.copy_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Booking details copied to clipboard'),
        ]),
        backgroundColor: _statusColor('success'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  🚆 RAILWAY TICKET PDF (Pakistan Railways style)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _downloadRailwayTicket() async {
    setState(() => _downloadingPdf = true);
    try {
      // Load Unicode-supporting font to eliminate warnings
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
      );
      final td = _bookingData['trainDetails'] as Map<String, dynamic>?;
      final returnTd =
          _bookingData['returnTrainDetails'] as Map<String, dynamic>?;
      final isRoundTrip =
          _bookingData['isRoundTrip'] == true && returnTd != null;
      final passengers = _bookingData['allPassengers'] as List<dynamic>? ?? [];
      final rawSeats = _bookingData['seatNumbers'] as List<dynamic>? ?? [];
      final rawTickets = _bookingData['ticketNumbers'] as List<dynamic>? ?? [];
      final coach = _bookingData['coach'] as String? ?? 'B-1';
      final pnr = _bookingData['pnr'] as String? ?? 'N/A';
      final grandTotal = _bookingData['total'] as double? ?? 0.0;
      final baseFare = _bookingData['amount'] as double? ?? 0.0;
      final paxCount = passengers.isEmpty ? 1 : passengers.length;
      final farePerPax = paxCount > 0 ? baseFare / paxCount : baseFare;
      const rabta = 10.0; // Pakistan Railways standard RABTA fee

      // Get seat selections for both journeys
      final outboundSeats = isRoundTrip
          ? (_bookingData['outboundSeatSelections'] as List<dynamic>? ?? [])
          : (_bookingData['seatSelections'] as List<dynamic>? ?? []);
      final returnSeats = isRoundTrip
          ? (_bookingData['returnSeatSelections'] as List<dynamic>? ?? [])
          : [];

      // Generate outbound tickets for all passengers
      for (int i = 0; i < passengers.length; i++) {
        final pax = passengers[i] as Map<String, dynamic>;
        final paxName = pax['name'] as String? ?? 'Passenger ${i + 1}';
        final rawCnic = pax['cnic'] as String? ?? '';
        final cnic = rawCnic.isNotEmpty
            ? rawCnic.replaceAll('-', '').replaceAll(' ', '')
            : (pax['passportOrId'] as String?)
                    ?.replaceAll('-', '')
                    .replaceAll(' ', '') ??
                '--';
        final phone = pax['phone'] as String? ?? '--';
        // Calculate age from DOB if age field is missing
        String age = pax['age'] as String? ?? '';
        if (age.isEmpty) {
          final dobStr = pax['dateOfBirth'] as String? ?? '';
          if (dobStr.isNotEmpty) {
            try {
              final dob = DateTime.parse(dobStr);
              final now = DateTime.now();
              int ageNum = now.year - dob.year;
              if (now.month < dob.month ||
                  (now.month == dob.month && now.day < dob.day)) {
                ageNum--;
              }
              age = ageNum.toString();
            } catch (_) {
              age = '--';
            }
          } else {
            age = '--';
          }
        }
        final gender = pax['gender'] as String? ?? 'Male';
        final rawType = pax['concessionType'] as String? ?? 'ADULT';
        final paxType = rawType == 'CHILD_3_10'
            ? 'CHILD'
            : rawType == 'INFANT'
                ? 'INFANT'
                : 'ADULT';

        // Get seat and coach from actual selections (outbound)
        String seat = '${i + 1}'; // fallback
        String seatCoach = coach; // fallback
        if (i < outboundSeats.length) {
          final seatData = outboundSeats[i] as Map<String, dynamic>;
          final seatName = (seatData['seatName'] ?? '').toString();
          if (seatName.isNotEmpty) {
            seat = seatName;
            seatCoach = (seatData['coach'] ?? coach).toString();
          }
        } else if (i < rawSeats.length) {
          seat = rawSeats[i].toString();
        }

        final ticketNo = i < rawTickets.length ? rawTickets[i].toString() : pnr;

        // Per-passenger fare
        final double thisFare = rawType == 'CHILD_3_10'
            ? farePerPax * 0.5
            : rawType == 'INFANT'
                ? 0.0
                : farePerPax;
        final double thisTotal = thisFare + (rawType == 'ADULT' ? rabta : 0.0);

        _addRailwayTicketPage(
          doc,
          td: td,
          pnr: pnr,
          coach: seatCoach,
          seat: seat,
          ticketNo: ticketNo,
          paxName: paxName,
          phone: phone,
          cnic: cnic,
          age: age,
          gender: gender,
          paxType: paxType,
          fare: thisFare,
          rabta: rawType == 'ADULT' ? rabta : 0.0,
          total: thisTotal,
          grandTotal: grandTotal,
          paxIndex: i,
          paxCount: passengers.length,
          isReturn: false,
        );
      }
      // If no passengers (edge case), add one page
      if (passengers.isEmpty) {
        _addRailwayTicketPage(
          doc,
          td: td,
          pnr: pnr,
          coach: coach,
          seat: '1',
          ticketNo: pnr,
          paxName: _bookingData['passengerName'] as String? ?? 'Passenger',
          phone: _bookingData['phone'] as String? ?? '--',
          cnic: '--',
          age: '--',
          gender: 'Male',
          paxType: 'ADULT',
          fare: baseFare,
          rabta: rabta,
          total: baseFare + rabta,
          grandTotal: grandTotal,
          paxIndex: 0,
          paxCount: 1,
          isReturn: false,
        );
      }

      // Generate return tickets if round trip
      if (isRoundTrip) {
        for (int i = 0; i < passengers.length; i++) {
          final pax = passengers[i] as Map<String, dynamic>;
          final paxName = pax['name'] as String? ?? 'Passenger ${i + 1}';
          final rawCnic = pax['cnic'] as String? ?? '';
          final cnic = rawCnic.isNotEmpty
              ? rawCnic.replaceAll('-', '').replaceAll(' ', '')
              : (pax['passportOrId'] as String?)
                      ?.replaceAll('-', '')
                      .replaceAll(' ', '') ??
                  '--';
          final phone = pax['phone'] as String? ?? '--';
          // Calculate age from DOB if age field is missing
          String age = pax['age'] as String? ?? '';
          if (age.isEmpty) {
            final dobStr = pax['dateOfBirth'] as String? ?? '';
            if (dobStr.isNotEmpty) {
              try {
                final dob = DateTime.parse(dobStr);
                final now = DateTime.now();
                int ageNum = now.year - dob.year;
                if (now.month < dob.month ||
                    (now.month == dob.month && now.day < dob.day)) {
                  ageNum--;
                }
                age = ageNum.toString();
              } catch (_) {
                age = '--';
              }
            } else {
              age = '--';
            }
          }
          final gender = pax['gender'] as String? ?? 'Male';
          final rawType = pax['concessionType'] as String? ?? 'ADULT';
          final paxType = rawType == 'CHILD_3_10'
              ? 'CHILD'
              : rawType == 'INFANT'
                  ? 'INFANT'
                  : 'ADULT';

          // Get seat and coach from actual selections (return)
          String seat = '${i + 1}'; // fallback
          String seatCoach = coach; // fallback
          if (i < returnSeats.length) {
            final seatData = returnSeats[i] as Map<String, dynamic>;
            final seatName = (seatData['seatName'] ?? '').toString();
            if (seatName.isNotEmpty) {
              seat = seatName;
              seatCoach = (seatData['coach'] ?? coach).toString();
            }
          } else if (i < rawSeats.length) {
            seat = rawSeats[i].toString();
          }

          final ticketNo =
              i < rawTickets.length ? rawTickets[i].toString() : pnr;

          // Per-passenger fare
          final double thisFare = rawType == 'CHILD_3_10'
              ? farePerPax * 0.5
              : rawType == 'INFANT'
                  ? 0.0
                  : farePerPax;
          final double thisTotal =
              thisFare + (rawType == 'ADULT' ? rabta : 0.0);

          _addRailwayTicketPage(
            doc,
            td: returnTd,
            pnr: pnr,
            coach: seatCoach,
            seat: seat,
            ticketNo: ticketNo,
            paxName: paxName,
            phone: phone,
            cnic: cnic,
            age: age,
            gender: gender,
            paxType: paxType,
            fare: thisFare,
            rabta: rawType == 'ADULT' ? rabta : 0.0,
            total: thisTotal,
            grandTotal: grandTotal,
            paxIndex: i,
            paxCount: passengers.length,
            isReturn: true,
          );
        }
        // If no passengers (edge case), add one page for return
        if (passengers.isEmpty) {
          _addRailwayTicketPage(
            doc,
            td: returnTd,
            pnr: pnr,
            coach: coach,
            seat: '1',
            ticketNo: pnr,
            paxName: _bookingData['passengerName'] as String? ?? 'Passenger',
            phone: _bookingData['phone'] as String? ?? '--',
            cnic: '--',
            age: '--',
            gender: 'Male',
            paxType: 'ADULT',
            fare: baseFare,
            rabta: rabta,
            total: baseFare + rabta,
            grandTotal: grandTotal,
            paxIndex: 0,
            paxCount: 1,
            isReturn: true,
          );
        }
      }
      final pdfBytes = await doc.save();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.grey.shade100,
              appBar: AppBar(
                title: const Text('E-Ticket Preview'),
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: PdfPreview(
                build: (_) async => pdfBytes,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                initialPageFormat: PdfPageFormat.a4,
                pdfFileName:
                    'travello_train_ticket_${_bookingData['pnr'] ?? 'ticket'}.pdf',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('PDF generation failed. Please try again.'),
          backgroundColor: _statusColor('error'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  void _addRailwayTicketPage(
    pw.Document doc, {
    required Map<String, dynamic>? td,
    required String pnr,
    required String coach,
    required String seat,
    required String ticketNo,
    required String paxName,
    required String phone,
    required String cnic,
    required String age,
    required String gender,
    required String paxType,
    required double fare,
    required double rabta,
    required double total,
    required double grandTotal,
    required int paxIndex,
    required int paxCount,
    required bool isReturn,
  }) {
    const pgGreen = PdfColor(0.114, 0.388, 0.114); // #1D631D
    const pgGreenLight = PdfColor(0.882, 0.961, 0.878); // #E1F5E0
    const pgText = PdfColor(0.1, 0.1, 0.1);
    const pgGrey = PdfColor(0.45, 0.45, 0.45);
    const pgBorder = PdfColor(0.82, 0.82, 0.82);

    final trainName = td?['trainName'] as String? ?? 'Pakistan Express';
    final trainNumber = td?['trainNumber'] as String? ?? '45UP';
    final fromStation = td?['from'] as String? ?? 'N/A';
    final toStation = td?['to'] as String? ?? 'N/A';
    final fromCode = td?['fromCode'] as String? ?? '';
    final toCode = td?['toCode'] as String? ?? '';
    final depTime = td?['departure'] as String? ?? '--:--';
    final classType = td?['class'] as String? ?? 'Economy';
    final date = td?['date'] as String? ?? '--';

    final fromLabel =
        fromCode.isNotEmpty ? '${fromCode.toUpperCase()} JN.' : fromStation;
    final toLabel =
        toCode.isNotEmpty ? '${toCode.toUpperCase()} JN.' : toStation;
    final coachSeat = '$seat/$coach';
    final qrData =
        'PR|PNR:$pnr|TRN:$trainNumber|PAX:$paxName|SEAT:$coachSeat|DT:$date';

    pw.Widget row(String labelEn, String value, {bool bold = false}) {
      return pw.Container(
        decoration: const pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: pgBorder, width: 0.5))),
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 4,
              child: pw.Text(labelEn,
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: pgText,
                      fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11,
                      color: pgText,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
          ],
        ),
      );
    }

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header: Pakistan Railways logo area ──
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: const pw.BoxDecoration(
              color: pgGreen,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PAKISTAN RAILWAYS',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Online Ticket',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                    if (paxCount > 1)
                      pw.Text('${paxIndex + 1} of $paxCount',
                          style: const pw.TextStyle(
                              color: PdfColors.white, fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // ── Title ──
          pw.Center(
            child: pw.Text('Pakistan Railway Ticket',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: pgText)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: pw.BoxDecoration(
                color: isReturn ? const PdfColor(0.9, 0.5, 0.2) : pgGreen,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                isReturn ? 'RETURN JOURNEY' : 'OUTBOUND JOURNEY',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),

          // ── Train info subtitle ──
          pw.Center(
            child: pw.Column(children: [
              pw.Text('$trainNumber/$trainName',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: pgText)),
              pw.Text('$fromLabel to $toLabel',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: pgText)),
            ]),
          ),
          pw.SizedBox(height: 8),

          // ── Details table ──
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: pgBorder),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Column(children: [
              row('Departure Date', '$date $depTime'),
              row('Class', classType),
              row('Coach/Seat', coachSeat, bold: true),
              row('Name', paxName, bold: true),
              row('CNIC', cnic),
              row('Age', age),
              row('Gender', gender),
              row('Phone', phone),
              row('Type', paxType),
              pw.SizedBox(height: 2),
              row('Fare', 'Rs.${fare.toStringAsFixed(2)}'),
              if (rabta > 0)
                row('RABTA (Database)', 'Rs.${rabta.toStringAsFixed(2)}'),
              row('Reservation (Online)', 'Rs.0.00'),
              pw.SizedBox(height: 2),
              pw.Container(
                color: pgGreenLight,
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                child: pw.Row(children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text('Total:',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: pgText)),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Rs.${total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: pgGreen)),
                  ),
                ]),
              ),
              row('Voucher', '--'),
            ]),
          ),
          pw.SizedBox(height: 10),

          // ── Legal notices (bilingual) ──
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: pgGreenLight,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    'A traveler must provide his/her original Name, CNIC No and Mobile No.',
                    style: const pw.TextStyle(fontSize: 9, color: pgText)),
                pw.SizedBox(height: 3),
                pw.Text(
                    'Traveling with fake information on Ticket is not allowed.',
                    style: const pw.TextStyle(fontSize: 9, color: pgText)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // ── QR code + ticket number ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: 90,
                height: 90,
                color: pgGreen,
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(ticketNo,
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: pgGrey,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Online Ticket',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: pgGreen,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Pakistan Railways Official',
                        style: const pw.TextStyle(fontSize: 8, color: pgGrey)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Future<void> _shareRailwayTicket() async {
    final pnr = _bookingData['pnr'] as String? ?? 'N/A';
    final name = _bookingData['passengerName'] as String? ?? 'N/A';
    final td = _bookingData['trainDetails'] as Map<String, dynamic>?;
    final trainName = td?['trainName'] as String? ?? 'N/A';
    final trainNumber = td?['trainNumber'] as String? ?? 'N/A';
    final from = td?['from'] as String? ?? 'N/A';
    final to = td?['to'] as String? ?? 'N/A';
    final dep = td?['departure'] as String? ?? 'N/A';
    final date = td?['date'] as String? ?? 'N/A';
    final coach = _bookingData['coach'] as String? ?? 'N/A';
    final seats = (_bookingData['seatNumbers'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .join(', ') ??
        'N/A';
    final total = _bookingData['total'] as double? ?? 0.0;

    final text = 'Pakistan Railways Ticket - Travello AI\n'
        '━━━━━━━━━━━━━━━━━━━━━━━\n'
        'PNR        : $pnr\n'
        'Train      : $trainNumber / $trainName\n'
        'Route      : $from  →  $to\n'
        'Date       : $date  $dep\n'
        'Coach/Seat : $coach  |  Seat: $seats\n'
        'Passenger  : $name\n'
        'Total Fare : PKR ${total.toStringAsFixed(0)}\n'
        '━━━━━━━━━━━━━━━━━━━━━━━\n'
        'Carry valid CNIC at station.\n'
        'Booked via Travello AI';

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Ticket details copied to clipboard'),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  🎨 UI COMPONENTS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_isLoading)
            _buildLoadingSkeleton()
          else
            Column(
              children: [
                // Step Progress Indicator
                _buildStepProgress(),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 2️⃣ Success Header with Animation
                          _buildSuccessHeader(context),
                          const SizedBox(height: 20),

                          // 3️⃣ Booking Reference & PNR
                          _buildBookingReference(context),
                          const SizedBox(height: 16),

                          // 4️⃣ Transaction Details
                          _buildTransactionDetails(context),
                          const SizedBox(height: 16),

                          // 5️⃣ E-Ticket & QR Code Section
                          _buildETicketSection(context),
                          const SizedBox(height: 16),

                          // 6️⃣ Payment Summary
                          _buildPaymentSummary(context),
                          const SizedBox(height: 16),

                          // 7️⃣ Important Travel Information
                          _buildTravelInformation(context),
                          const SizedBox(height: 16),

                          // 8️⃣ AI Smart Add-ons
                          _buildSmartAddons(context),
                          const SizedBox(height: 16),

                          // 🔟 Action Buttons
                          _buildActionButtons(context),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── App Bar ──
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isTrain =
        (_bookingData['bookingType'] as String? ?? 'flight') == 'train';
    final appBarColor =
        isTrain ? const Color(0xFFD4AF37) : TravelloTheme.primaryMain;
    return AppBar(
      elevation: 0,
      backgroundColor: appBarColor,
      leading: IconButton(
        onPressed: () => Get.offAllNamed(AppLink.home),
        icon: const Icon(Icons.arrow_back, size: 24),
        color: Colors.white,
      ),
      centerTitle: true,
      title: const Text(
        'Done',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white),
          onPressed: () => Get.toNamed('/faq'),
        ),
      ],
    );
  }

  // ── 2️⃣ Success Header with Animation ──
  Widget _buildSuccessHeader(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                _statusColor('success'),
                _statusColor('success').withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _statusColor('success').withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Animated Success Icon with Rotation & Bounce
              AnimatedBuilder(
                animation: _checkmarkController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _checkmarkScale.value,
                    child: Transform.rotate(
                      angle: _checkmarkRotation.value * 2 * pi,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 20 * _checkmarkScale.value,
                              spreadRadius: 5 * _checkmarkScale.value,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Payment Success',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: R.sp(context, 24),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _formatPKR(_bookingData['total']),
                  style: TextStyle(
                    color: _statusColor('success'),
                    fontSize: R.sp(context, 32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Your booking is confirmed!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3️⃣ Booking Reference & PNR ──
  Widget _buildBookingReference(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  color: TravelloTheme.primaryMain,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Booking Reference',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // PNR with Copy Button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PNR / Booking Code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _bookingData['pnr'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _copyPnr,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _copyingPnr
                            ? _statusColor('success')
                            : TravelloTheme.primaryMain,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _copyingPnr ? Icons.check : Icons.copy,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4️⃣ Transaction Details ──
  Widget _buildTransactionDetails(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DETAIL TRANSACTION',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _detailRow('Date:', _bookingData['date'] ?? 'N/A'),
            _divider(),
            _detailRow(
                'Transaction Number:', _bookingData['transactionId'] ?? 'N/A'),
            _divider(),
            _detailRow(
              'Base Fare:',
              _formatPKR(_bookingData['amount']),
            ),
            _divider(),
            _detailRow(
              _bookingData['bookingType'] == 'train'
                  ? 'Reservation Fee:'
                  : 'Taxes & Fees:',
              _formatPKR(_bookingData['tax']),
            ),
            if ((_bookingData['serviceFee'] ?? 0) > 0) ...[
              _divider(),
              _detailRow(
                'Service Fee:',
                _formatPKR(_bookingData['serviceFee']),
              ),
            ],
            if ((_bookingData['baggageFee'] ?? 0) > 0) ...[
              _divider(),
              _detailRow(
                'Baggage Fee:',
                _formatPKR(_bookingData['baggageFee']),
              ),
            ],
            if ((_bookingData['insuranceFee'] ?? 0) > 0) ...[
              _divider(),
              _detailRow(
                'Travel Insurance:',
                _formatPKR(_bookingData['insuranceFee']),
              ),
            ],
            if ((_bookingData['discount'] ?? 0) > 0) ...[
              _divider(),
              _detailRow(
                'Discount:',
                '-${_formatPKR(_bookingData['discount'])}',
                valueColor: Colors.green,
              ),
            ],
            _divider(),
            _detailRow(
              'Total Amount:',
              _formatPKR(_bookingData['total']),
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade200,
              Colors.grey.shade100,
              Colors.grey.shade200,
            ],
          ),
        ),
      ),
    );
  }

  // ── 5️⃣ E-Ticket & QR Code Section ──
  Widget _buildETicketSection(BuildContext context) {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';

    if (bookingType == 'train') {
      return _buildRailwayTicketSection(context);
    }

    return _buildFlightTicketSection(context);
  }

  // ── Railway Ticket Section (Pakistan Railways) ── fintech redesign ──────
  Widget _buildRailwayTicketSection(BuildContext context) {
    const railwayGreen = Color(0xFFD4AF37);
    const emerald = Color(0xFF10B981);

    // ── Data extraction ──────────────────────────────────────────────────
    final pnr = _bookingData['pnr'] as String? ?? '0000000000';
    final coach = _bookingData['coach'] as String? ?? 'B-1';
    final td = _bookingData['trainDetails'] as Map<String, dynamic>?;
    final trainName = td?['trainName'] as String? ?? 'Pakistan Express';
    final trainNumber = td?['trainNumber'] as String? ?? '45UP';
    final from = td?['from'] as String? ?? 'Karachi';
    final to = td?['to'] as String? ?? 'Lahore';
    final fromCode = td?['fromCode'] as String? ?? 'KHI';
    final toCode = td?['toCode'] as String? ?? 'LHE';
    final dep = td?['departure'] as String? ?? '--:--';
    final duration = td?['duration'] as String? ?? 'N/A';
    final date = td?['date'] as String? ?? '--';
    final classType = td?['class'] as String? ?? 'Economy';
    final passengers = _bookingData['allPassengers'] as List<dynamic>? ?? [];
    final isRoundTrip = _bookingData['isRoundTrip'] == true;
    final returnTd =
        _bookingData['returnTrainDetails'] as Map<String, dynamic>?;

    // ━━━ Professional Railway Barcode/QR Data Format ━━━
    final passengerName = passengers.isNotEmpty
        ? (passengers[0]['name'] as String? ?? 'PASSENGER')
        : 'PASSENGER';
    final qrData =
        'TRAVELLO|TYPE:TRAIN|PNR:$pnr|TRAIN:$trainNumber|NAME:$trainName|ROUTE:$fromCode-$toCode|DATE:$date|PAX:$passengerName|CLASS:$classType|COACH:$coach';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(children: [
          // ── Header bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8935C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.train_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('E-Ticket',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isRoundTrip ? 'ROUND TRIP' : 'ONE WAY',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: emerald.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: emerald.withValues(alpha: 0.55)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: emerald, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  const Text('CONFIRMED',
                      style: TextStyle(
                          color: emerald,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ]),
              ),
            ]),
          ),

          // ── Route strip ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              // FROM
              Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fromCode,
                          style: TextStyle(
                              fontSize: R.sp(context, 34),
                              fontWeight: FontWeight.w900,
                              color: railwayGreen,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(from,
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              // Route line
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(children: [
                    Text(dep,
                        style: const TextStyle(
                            color: railwayGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: railwayGreen, width: 1.5))),
                      Expanded(
                          child: Container(
                              height: 1.5,
                              color: railwayGreen.withValues(alpha: 0.3))),
                      const Icon(Icons.train_rounded,
                          color: railwayGreen, size: 14),
                      Expanded(
                          child: Container(
                              height: 1.5,
                              color: railwayGreen.withValues(alpha: 0.3))),
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: railwayGreen, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 6),
                    Text(duration,
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 9,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              // TO
              Flexible(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(toCode,
                          style: TextStyle(
                              fontSize: R.sp(context, 34),
                              fontWeight: FontWeight.w900,
                              color: railwayGreen,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(to,
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
            ]),
          ),

          // ── Main content: Passenger info (left) + QR (right) ───────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxHeight < 600;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: Passenger info box
                    Expanded(
                      flex: isSmallScreen ? 1 : 2,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FFF8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: railwayGreen.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PASSENGER',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              Text(
                                  passengers.isNotEmpty
                                      ? (passengers[0]['name'] as String?) ??
                                          'Passenger'
                                      : 'Passenger',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: railwayGreen),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2),
                              const SizedBox(height: 12),
                              Text('PNR',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: _copyPnr,
                                child: Row(children: [
                                  Flexible(
                                    child: Text(pnr,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: railwayGreen,
                                            letterSpacing: 1.2),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.copy_rounded,
                                      size: 13, color: Colors.grey.shade400),
                                ]),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _miniChip(Icons.calendar_today_rounded, date,
                                      railwayGreen),
                                  _miniChip(Icons.chair_outlined, classType,
                                      railwayGreen),
                                ],
                              ),
                            ]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // RIGHT: QR code
                    Column(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.grey.shade200, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: railwayGreen.withValues(alpha: 0.08),
                                blurRadius: 12)
                          ],
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 120,
                          eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square, color: railwayGreen),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: railwayGreen),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Scan at Check-in',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ],
                );
              },
            ),
          ),

          // ── Additional Details (expandable) ─────────────────────────────
          if (isRoundTrip || passengers.length > 1 || trainName.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    leading: Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.grey.shade600),
                    title: Text('View Full Details',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700)),
                    children: [
                      // Train Info
                      if (trainName.isNotEmpty) ...[
                        Row(children: [
                          Icon(Icons.train_rounded,
                              size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('$trainName (Train No. $trainNumber)',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: railwayGreen),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      // Return Journey
                      if (isRoundTrip && returnTd != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(Icons.sync_alt_rounded,
                                      size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text('RETURN JOURNEY',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey.shade700,
                                          letterSpacing: 0.8)),
                                ]),
                                const SizedBox(height: 10),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                            '${returnTd['trainNumber']}/${returnTd['trainName']}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: railwayGreen),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(returnTd['date'] as String? ?? '--',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade600)),
                                    ]),
                                const SizedBox(height: 8),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                returnTd['fromCode']
                                                        as String? ??
                                                    '',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: railwayGreen)),
                                            Text(
                                                returnTd['departure']
                                                        as String? ??
                                                    '--:--',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade500,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ]),
                                      Icon(Icons.arrow_forward,
                                          size: 16,
                                          color: Colors.grey.shade400),
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                                returnTd['toCode'] as String? ??
                                                    '',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: railwayGreen)),
                                            Text(
                                                returnTd['arrival']
                                                        as String? ??
                                                    '--:--',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade500,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ]),
                                    ]),
                              ]),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // All Passengers
                      if (passengers.length > 1) ...[
                        Row(children: [
                          const Icon(Icons.people_alt_outlined,
                              size: 13, color: railwayGreen),
                          const SizedBox(width: 6),
                          Text('ALL PASSENGERS (${passengers.length})',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: railwayGreen,
                                  letterSpacing: 0.8)),
                        ]),
                        const SizedBox(height: 8),
                        ...List.generate(passengers.length, (i) {
                          final pax = passengers[i] as Map<String, dynamic>;
                          final paxName =
                              pax['name'] as String? ?? 'Passenger ${i + 1}';
                          final rawType =
                              pax['concessionType'] as String? ?? 'ADULT';
                          final paxType = rawType == 'CHILD_3_10'
                              ? 'CHILD'
                              : rawType == 'INFANT'
                                  ? 'INFANT'
                                  : 'ADULT';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FFF8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: railwayGreen.withValues(alpha: 0.15)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: railwayGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          color: railwayGreen,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(paxName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        color: Color(0xFF1A1A1A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (paxType != 'ADULT')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFFF9800),
                                        width: 0.5),
                                  ),
                                  child: Text(paxType,
                                      style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFE65100))),
                                ),
                            ]),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── VIEW FULL TRAIN TICKET button ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GestureDetector(
              onTap: _downloadRailwayTicket,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: railwayGreen.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: _downloadingPdf
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Icon(Icons.train_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text('VIEW & DOWNLOAD TICKET',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.5),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1),
                            ),
                          ]),
              ),
            ),
          ),

          // ── Action bar: Download / Share ──────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(children: [
              Expanded(
                  child: _ticketActionButton(
                icon: Icons.sim_card_download_rounded,
                label: 'Download',
                onTap: _downloadRailwayTicket,
                isLoading: _downloadingPdf,
                accent: railwayGreen,
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _ticketActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: _shareRailwayTicket,
                accent: emerald,
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Booking info chip (Coach / Class / Date / Train No.) ─────────────────
  // ── Flight E-Ticket Section ──
  Widget _buildFlightTicketSection(BuildContext context) {
    const navy = Color(0xFF1A1A2E);
    const blue = Color(0xFFD4AF37);
    const emerald = Color(0xFF10B981);
    final pnr = _bookingData['pnr'] as String? ?? 'TRV000000';
    final name = _bookingData['passengerName'] as String? ?? 'Passenger';
    final fd = _bookingData['flightDetails'] as Map<String, dynamic>?;
    final from = fd?['from'] as String? ?? '--';
    final to = fd?['to'] as String? ?? '--';
    final dep = fd?['departure'] as String? ?? '--';
    final date = fd?['date'] as String? ?? '--';
    final fltNum = fd?['flightNumber'] as String? ?? '--';
    final fltClass = fd?['class'] as String? ?? 'Economy';
    final isRT = _bookingData['isRoundTrip'] == true;

    // IATA code helper
    String code(String s) {
      final m = RegExp(r'\(([^)]+)\)').firstMatch(s);
      return m?.group(1) ?? s.substring(0, s.length.clamp(0, 3)).toUpperCase();
    }

    final fromCode = code(from);
    final toCode = code(to);

    // ━━━ Professional IATA-Style Data Format ━━━
    final qrData =
        'TRAVELLO|TYPE:FLIGHT|PNR:$pnr|FLT:$fltNum|ROUTE:$fromCode-$toCode|DATE:$date|PAX:$name|CLASS:$fltClass';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: navy.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(children: [
          // ── Header bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8935C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.airplane_ticket_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'E-Ticket & Boarding Pass',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: emerald.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: emerald.withValues(alpha: 0.55)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: emerald, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        const Text('CONFIRMED',
                            style: TextStyle(
                                color: emerald,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),

          // ── Route strip ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFBF5DC),
              border: Border(bottom: BorderSide(color: Color(0xFFE8D5A3))),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 80,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fromCode,
                              style: TextStyle(
                                  fontSize: R.sp(context, 26),
                                  fontWeight: FontWeight.w900,
                                  color: navy,
                                  letterSpacing: 2)),
                          Text(from.split('(').first.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blueGrey.shade500)),
                        ]),
                  ),
                  Expanded(
                      child: Column(children: [
                    Text(dep,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: navy)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: blue, width: 1.5))),
                      Expanded(
                          child: Container(
                              height: 1.5, color: blue.withValues(alpha: 0.3))),
                      Transform.rotate(
                        angle: 1.5708, // 90 degrees (pi/2) to face right
                        child: const Icon(Icons.flight, color: blue, size: 16),
                      ),
                      Expanded(
                          child: Container(
                              height: 1.5, color: blue.withValues(alpha: 0.3))),
                      Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: blue, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(
                          fd?['duration'] as String? ??
                              (isRT ? 'ROUND TRIP' : 'ONE WAY'),
                          style: const TextStyle(
                              color: blue,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                  ])),
                  SizedBox(
                    width: 80,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(toCode,
                              style: TextStyle(
                                  fontSize: R.sp(context, 26),
                                  fontWeight: FontWeight.w900,
                                  color: navy,
                                  letterSpacing: 2)),
                          Text(to.split('(').first.trim(),
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blueGrey.shade500)),
                        ]),
                  ),
                ]),
          ),

          // ── PNR + passenger row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF5DC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8D5A3)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PASSENGER',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.blueGrey.shade400,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 3),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: navy),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text('PNR',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.blueGrey.shade400,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: _copyPnr,
                          child: Row(children: [
                            Text(pnr,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: blue,
                                    letterSpacing: 1.5)),
                            const SizedBox(width: 6),
                            Icon(Icons.copy_rounded,
                                size: 12, color: Colors.blueGrey.shade400),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Flexible(
                            child: _miniChip(
                                Icons.calendar_today_rounded, date, navy),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _miniChip(
                                Icons.flight_takeoff_rounded, fltNum, blue),
                          ),
                        ]),
                      ]),
                ),
              ),
              const SizedBox(width: 14),
              // ── Real QR code ──────────────────────────
              Column(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.blueGrey.shade100, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: navy.withValues(alpha: 0.07), blurRadius: 10)
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 110,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: navy),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square, color: navy),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Scan at Check-in',
                    style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.blueGrey.shade500,
                        fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),

          // ── View E-Ticket button ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: GestureDetector(
              onTap: () => Get.toNamed(
                AppLink.eTicket,
                arguments: {
                  ..._bookingData,
                  'hidePdfOption': true,
                },
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFB8935C)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.airplane_ticket_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('VIEW FULL E-TICKET',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5)),
                    ]),
              ),
            ),
          ),

          // ── Action bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Row(children: [
              Expanded(
                  child: _ticketActionButton(
                icon: Icons.sim_card_download_rounded,
                label: 'Download',
                onTap: _downloadTicket,
                isLoading: _downloadingPdf,
                accent: blue,
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _ticketActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: _shareTicket,
                accent: emerald,
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 9, color: color, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        ]),
      );

  Widget _ticketActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
    Color accent = const Color(0xFF2563EB),
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, valueColor: AlwaysStoppedAnimation(accent)),
            )
          else
            Icon(icon, size: 20, color: accent),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── 6️⃣ Payment Summary ──
  Widget _buildPaymentSummary(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: TravelloTheme.primaryMain,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Payment Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    _showInvoiceModal();
                  },
                  child: const Text('View Invoice'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _paymentDetailRow(
                'Payment Method', _bookingData['paymentMethod'] ?? 'N/A'),
            _paymentDetailRow(
                'Transaction ID', _bookingData['transactionId'] ?? 'N/A'),
            _paymentDetailRow(
              'Date',
              DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor('success').withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _statusColor('success').withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: _statusColor('success'),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment verified and processed securely',
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor('success'),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7️⃣ Pre-Flight/Train Checklist ──
  Widget _buildTravelInformation(BuildContext context) {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
    final isRailway = bookingType == 'train';
    const navy = Color(0xFFD4AF37);
    const railwayGreen = Color(0xFFD4AF37);
    const divider = Color(0xFFF0F2F5);

    // Dynamic checklist based on booking type
    final List<_CheckItem> checks;
    final String headerTitle;
    final Color headerColor;
    final String supportLabel;
    final String supportNumber;

    if (isRailway) {
      // PRE-TRAIN CHECKLIST - Pakistan Railways Standards
      checks = const [
        _CheckItem(Icons.access_time_rounded, 'Station Arrival',
            'Arrive 30 mins before departure', '30M'),
        _CheckItem(Icons.badge_rounded, 'Travel Docs',
            'Original CNIC / Passport required', 'ID'),
        _CheckItem(Icons.confirmation_number_rounded, 'Boarding Info',
            'Verify coach & seat, board 15 mins early', 'TKT'),
      ];
      headerTitle = 'PRE-TRAIN CHECKLIST';
      headerColor = railwayGreen;
      supportLabel = 'Railway Support';
      supportNumber = '117'; // Pakistan Railways Helpline
    } else {
      // PRE-FLIGHT CHECKLIST
      checks = const [
        _CheckItem(Icons.how_to_reg_rounded, 'Check-in',
            'Opens 24 hrs before departure', '24H'),
        _CheckItem(Icons.access_time_rounded, 'Airport Arrival',
            'Be at gate 2 hrs before flight', '2HR'),
        _CheckItem(Icons.badge_rounded, 'Travel Docs',
            'Valid CNIC / Passport required', 'ID'),
        _CheckItem(Icons.luggage_rounded, 'Baggage',
            '7 kg cabin  +  20 kg checked', 'BAG'),
      ];
      headerTitle = 'PRE-FLIGHT CHECKLIST';
      headerColor = navy;
      supportLabel = 'Airline Support';
      supportNumber = '+92 21 111 786 786';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isRailway ? Icons.train_rounded : Icons.checklist_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  headerTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${checks.length} ITEMS',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // ── Checklist Items ──
          ...checks.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Column(
              children: [
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                headerColor.withValues(alpha: 0.1),
                                headerColor.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(c.icon, size: 20, color: headerColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  )),
                              const SizedBox(height: 3),
                              Text(c.subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: headerColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(c.tag,
                              style: TextStyle(
                                fontSize: 11,
                                color: headerColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < checks.length - 1)
                  Container(
                      height: 1,
                      color: divider,
                      margin: const EdgeInsets.symmetric(horizontal: 20)),
              ],
            );
          }),
          // ── Support Footer ──
          InkWell(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    headerColor.withValues(alpha: 0.05),
                    headerColor.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: headerColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: headerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.headset_mic_rounded,
                        size: 18, color: headerColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supportLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2)),
                        const SizedBox(height: 2),
                        Text(supportNumber,
                            style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: headerColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: headerColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.phone_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text('CALL',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 8️⃣ Enhance Your Journey ──
  Widget _buildSmartAddons(BuildContext context) {
    final weatherData = _bookingData['weather'] as Map? ?? {};
    final weatherTemp = weatherData['temp'] ?? '28°C';
    final weatherCond = weatherData['condition'] ?? 'Sunny';

    // Destination city name for hotel card
    final fd = _bookingData['flight'] as Map?;
    final toFull = fd?['to'] as String? ?? '';
    final toCity = toFull.isNotEmpty
        ? toFull.split('(').first.trim()
        : (_bookingData['to'] as String? ?? 'Destination')
            .split('(')
            .first
            .trim();

    final extras = [
      _TravelExtra(
        icon: Icons.wb_sunny_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBg: const Color(0xFFFFF8EB),
        tag: 'LIVE',
        tagColor: const Color(0xFFF59E0B),
        title: 'Destination Weather',
        subtitle: '$weatherTemp · $weatherCond',
        action: 'View Forecast',
        onTap: () => Get.toNamed(AppLink.weather),
      ),
      _TravelExtra(
        icon: Icons.hotel_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFEFF6FF),
        tag: 'PARTNER',
        tagColor: const Color(0xFF2563EB),
        title: 'Hotels in $toCity',
        subtitle: 'Best rates · Free cancellation',
        action: 'Explore',
        onTap: () => Get.toNamed(AppLink.hotelSearch),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ENHANCE YOUR JOURNEY',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Powered by Travello',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blueGrey.shade300,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
              height: 1,
              color: const Color(0xFFF0F2F5),
              margin: const EdgeInsets.symmetric(horizontal: 20)),
          const SizedBox(height: 4),
          // ── Cards ──
          ...extras.map((ex) => _buildExtraCard(ex)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildExtraCard(_TravelExtra ex) => _ExtraCardTile(ex: ex);

  // ── 🔟 Action Buttons ──
  Widget _buildActionButtons(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ColRow(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        switched: ThemeBreakpoints.smUp(context),
        children: [
          SizedBox(
            width: ThemeBreakpoints.smUp(context) ? 250 : double.infinity,
            child: FilledButton(
              onPressed: () => Get.offAllNamed(AppLink.myTicket),
              style:
                  ThemeButton.btnBig.merge(ThemeButton.tonalPrimary(context)),
              child: const Text('VIEW MY BOOKINGS'),
            ),
          ),
          SizedBox(
            height: ThemeBreakpoints.smUp(context) ? 0 : 16,
            width: ThemeBreakpoints.smUp(context) ? 16 : 0,
          ),
          SizedBox(
            width: ThemeBreakpoints.smUp(context) ? 250 : double.infinity,
            child: OutlinedButton(
              onPressed: () => Get.toNamed(AppLink.home),
              style: ThemeButton.btnBig
                  .merge(ThemeButton.outlinedPrimary(context)),
              child: const Text('BOOK ANOTHER TRIP'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Progress (Numbered Circles) ──
  Widget _buildStepProgress() {
    const steps = ['PASSENGERS', 'FACILITIES', 'CHECKOUT', 'PAYMENT', 'DONE'];
    final isTrain =
        (_bookingData['bookingType'] as String? ?? 'flight') == 'train';
    final stepColor =
        isTrain ? const Color(0xFFD4AF37) : TravelloTheme.primaryMain;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 8 : 16,
        horizontal: isMobile ? 8 : 16,
      ),
      child: Row(
        children: List.generate(9, (i) {
          if (i.isOdd) {
            // Connecting line
            final stepBefore = i ~/ 2;
            final isCompleted = stepBefore < 4;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: isCompleted ? stepColor : Colors.grey.shade300,
              ),
            );
          }
          // Circle
          final index = i ~/ 2;
          final isActive = index == 4; // DONE
          final isCompleted = index < 4;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 24 : 32,
                height: isMobile ? 24 : 32,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? stepColor
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted && index < 4
                      ? Icon(Icons.check,
                          color: Colors.white, size: isMobile ? 12 : 14)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCompleted || isActive
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontSize: isMobile ? 10 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 7 : 9,
                  color: isCompleted || isActive
                      ? stepColor
                      : Colors.grey.shade600,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Invoice Modal ──
  void _showInvoiceModal() {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
    final isRailway = bookingType == 'train';
    final invoiceTitle = isRailway ? 'Booking Receipt' : 'Tax Invoice';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header with Download PDF
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoiceTitle,
                        style: TextStyle(
                          fontSize: R.sp(context, 22),
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadInvoicePdf(),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              // Invoice Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: _buildInvoiceContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Invoice Content Widget ──
  Widget _buildInvoiceContent() {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
    final isRailway = bookingType == 'train';
    final invoiceNumber = _bookingData['pnr'] ?? 'N/A';
    final eTicketNumber = _bookingData['transactionId'] ?? 'N/A';
    final issuedDate =
        DateFormat('ddMMMyy').format(DateTime.now()).toUpperCase();
    final paxCount = _bookingData['passengerCount'] ?? 1;
    final tripType = _bookingData['isRoundTrip'] == true ? 'RT' : 'OW';

    // Build barcode data based on booking type
    String barcodeData;
    if (isRailway) {
      final trainDetails =
          _bookingData['trainDetails'] as Map<String, dynamic>? ?? {};
      final trainNum = (trainDetails['trainNumber'] ?? 'XX').toString();
      final fromStation = (trainDetails['from'] ?? '').toString();
      final toStation = (trainDetails['to'] ?? '').toString();
      final trainDate =
          (trainDetails['date'] ?? DateFormat('ddMMMyy').format(DateTime.now()))
              .toString();
      barcodeData =
          'PR|$invoiceNumber|$trainNum|$fromStation-$toStation|$trainDate|${paxCount}PAX|$tripType';
    } else {
      final flightDetails =
          _bookingData['flightDetails'] as Map<String, dynamic>? ?? {};
      final fltNum = (flightDetails['flightNumber'] ?? 'XX').toString();
      final fromStr = (flightDetails['from'] ?? '').toString();
      final toStr = (flightDetails['to'] ?? '').toString();
      final fromCode =
          RegExp(r'\(([A-Z]{3})\)').firstMatch(fromStr)?.group(1) ?? fromStr;
      final toCode =
          RegExp(r'\(([A-Z]{3})\)').firstMatch(toStr)?.group(1) ?? toStr;
      final fltDate = (flightDetails['date'] ??
              DateFormat('ddMMMyy').format(DateTime.now()))
          .toString();
      barcodeData =
          '$invoiceNumber/$fltNum/$fromCode-$toCode/$fltDate/${paxCount}PAX/$tripType';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══ Header: Logo + Title + Barcode ═══
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRailway
                    ? const Color(0xFF2E7D32)
                    : TravelloTheme.primaryMain,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isRailway ? Icons.train : Icons.flight_takeoff,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 20),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Travello AI',
                    style: TextStyle(
                      fontSize: R.sp(context, 22),
                      fontWeight: FontWeight.w900,
                      color: isRailway
                          ? const Color(0xFF2E7D32)
                          : TravelloTheme.primaryMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRailway
                        ? 'Railway E-Ticket'
                        : 'e-Ticket Receipt & Itinerary',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // PNR Barcode
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: barcodeData,
                  width: 160,
                  height: 52,
                  drawText: false,
                  color: Colors.black,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 4),
                Text(
                  invoiceNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  eTicketNumber,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ═══ Introduction Text ═══
        Text(
          isRailway
              ? 'Your railway e-ticket is stored in our computer reservations system. This booking receipt is your official record of your train journey. Please keep this receipt for the duration of your travel. You may need to show this to railway staff during travel or at the station.'
              : 'Your electronic ticket is stored in our computer reservations system. This e-Ticket receipt/itinerary is your record of your electronic ticket and where applicable, your contract of carriage. You may need to show this receipt to enter the airport and/or to prove this booking to customs and immigration officials.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade800,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          isRailway
              ? 'Your attention is drawn to the Pakistan Railways Terms and Conditions. Please visit us on www.travelloai.com for journey updates and station information.'
              : 'Your attention is drawn to the Conditions of Contract and Other Important Notices set out in the attached document. Please visit us on www.travelloai.com to check-in online and for more information.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade800,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 24),

        // ═══ PASSENGER AND TICKET INFORMATION ═══
        _buildSectionHeader('PASSENGER AND TICKET INFORMATION'),
        const SizedBox(height: 12),
        _buildInfoTable([
          // Show passenger count and names
          ['PASSENGER(S)', _buildPassengerNamesString()],
          ['TOTAL PASSENGERS', '${_bookingData['passengerCount'] ?? 1}'],
          ['BOOKING REFERENCE', invoiceNumber],
          ['E-TICKET NUMBER', eTicketNumber],
          [
            'ISSUED BY / DATE',
            isRailway
                ? 'PAKISTAN RAILWAYS / TRAVELLO AI\n($issuedDate/${DateFormat('HHmm').format(DateTime.now())}hr)'
                : '${(_bookingData['flightDetails']?['airline'] as String?) ?? 'AIRLINE'} / TRAVELLO AI\n($issuedDate/${DateFormat('HHmm').format(DateTime.now())}hr)'
          ],
        ]),

        const SizedBox(height: 24),

        // ═══ TRAVEL INFORMATION ═══
        _buildSectionHeader(_bookingData['isRoundTrip'] == true
            ? (isRailway
                ? 'JOURNEY INFORMATION (ROUND TRIP)'
                : 'TRAVEL INFORMATION (ROUND TRIP)')
            : (isRailway
                ? 'JOURNEY INFORMATION (ONE-WAY)'
                : 'TRAVEL INFORMATION (ONE-WAY)')),
        const SizedBox(height: 12),
        isRailway ? _buildTrainTravelTable() : _buildTravelTable(),
        // Show return journey if round trip
        if (_bookingData['isRoundTrip'] == true &&
            (isRailway
                ? _bookingData['returnTrainDetails'] != null
                : _bookingData['returnFlightDetails'] != null)) ...[
          const SizedBox(height: 12),
          isRailway ? _buildReturnTrainTable() : _buildReturnFlightTable(),
        ],

        const SizedBox(height: 24),

        // ═══ FARE AND ADDITIONAL INFORMATION ═══
        _buildSectionHeader('FARE AND ADDITIONAL INFORMATION'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFareBreakdown(),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildAdditionalInfo(),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ═══ FARE CALCULATIONS ═══
        _buildSectionHeader('FARE CALCULATIONS'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            _buildFareCalculationString(),
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ═══ Footer Notice ═══
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Important Notice',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRailway
                    ? 'Please arrive at the station at least 30 minutes before departure time. Carry original CNIC/Passport for verification.'
                    : 'Please check with departure airport for restrictions on the carriage of liquids, aerosols and gels in hand baggage.',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For customer support, please contact: support@travelloai.com | +92 300 1234567',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.grey.shade400,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoTable(List<List<String>> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: rows.map((row) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    row[0],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row[1],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTravelTable() {
    final flightDetails = _bookingData['flightDetails'];
    final departureDate = flightDetails?['date'] ?? 'N/A';
    final departureTime = flightDetails?['departure'] ?? 'N/A';
    final arrivalTime = flightDetails?['arrival'] ?? 'N/A';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(520.0, MediaQuery.of(context).size.width),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 60,
                        child: Text('FLIGHT',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 90,
                        child: Text('DEPART/ARRIVE',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('AIRPORT/TERMINAL',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 90,
                        child: Text('CHECK-IN OPENS',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 70,
                        child: Text('CLASS',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 100,
                        child: Text('COUPON VALIDITY',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              // Flight Row 1 - Departure
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: Colors.grey.shade300, width: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            flightDetails?['flightNumber'] ?? 'N/A',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'CONFIRMED',
                            style:
                                TextStyle(fontSize: 9, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$departureDate\n$departureTime',
                              style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            flightDetails?['from'] ?? 'N/A',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                          Text(
                              'TERMINAL ${flightDetails?['departureTerminal'] ?? '0'}',
                              style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text('$departureDate\n0730',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    const SizedBox(
                      width: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ECONOMY', style: TextStyle(fontSize: 10)),
                          Text('27 K', style: TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                          'NOT AFTER ${DateFormat('dd MMM yy').format(DateTime.now().add(const Duration(days: 365))).toUpperCase()}',
                          style: const TextStyle(fontSize: 9)),
                    ),
                  ],
                ),
              ),
              // Flight Row 2 - Arrival
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 60),
                    SizedBox(
                      width: 90,
                      child: Text('$departureDate\n$arrivalTime',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            flightDetails?['to'] ?? 'N/A',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                          Text(
                              'TERMINAL ${flightDetails?['arrivalTerminal'] ?? '1'}',
                              style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 90),
                    const SizedBox(
                      width: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BAGGAGE', style: TextStyle(fontSize: 9)),
                          Text('ALLOWANCE 30KGS',
                              style: TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFareBreakdown() {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
    final isRailway = bookingType == 'train';
    final passengerCount = _bookingData['passengerCount'] ?? 1;
    final baseFare = _bookingData['amount'] ?? 0.0;
    final perPassengerFare =
        passengerCount > 0 ? baseFare / passengerCount : baseFare;
    final serviceFee = _bookingData['serviceFee'] ?? 0.0;

    // Calculate RABTA fee for trains (Rs. 10 per adult passenger)
    final passengers = _bookingData['allPassengers'] as List<dynamic>? ?? [];
    final adultCount = passengers
        .where((p) => (p['concessionType'] ?? 'ADULT') == 'ADULT')
        .length;
    final rabtaFee = isRailway ? (adultCount * 10.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FARE',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (passengerCount > 1) ...[
          _buildFareRow('Base Fare (per passenger)', perPassengerFare),
          _buildFareRow('Base Fare (x$passengerCount passengers)', baseFare),
        ] else
          _buildFareRow('Base Fare', baseFare),
        if (serviceFee > 0) _buildFareRow('Service Fee', serviceFee),
        const SizedBox(height: 8),
        const Text(
          'TAXES/FEES/CHARGES',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (isRailway) ...[
          // Railway-specific charges
          if (rabtaFee > 0)
            _buildTaxRow(
                'RABTA Database', 'PKR ${rabtaFee.toStringAsFixed(2)}'),
          _buildTaxRow('Reservation (Online)', 'PKR 0.00'),
          if (serviceFee > 0)
            _buildTaxRow('Service Fee', 'PKR ${serviceFee.toStringAsFixed(2)}'),
        ] else ...[
          // Flight-specific charges — the actual FED/airport/security fee
          // total already charged (see booking_payment.dart's _taxes), not
          // invented IATA-style tax codes.
          if ((_bookingData['tax'] ?? 0.0) > 0)
            _buildTaxRow('Taxes & Government Fees',
                'PKR ${(_bookingData['tax'] ?? 0.0).toStringAsFixed(2)}'),
          if ((_bookingData['insuranceFee'] ?? 0.0) > 0)
            _buildTaxRow('Travel Insurance',
                'PKR ${(_bookingData['insuranceFee'] ?? 0.0).toStringAsFixed(2)}'),
        ],
        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade400, thickness: 1),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_bookingData['currency']}${(_bookingData['total'] ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'FORM OF PAYMENT',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _bookingData['paymentMethod']?.toUpperCase() ?? 'CREDIT CARD',
          style: const TextStyle(fontSize: 10),
        ),
        Text(
          '*You may be asked to present the card used for this payment at check-in.*',
          style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildFareRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${_bookingData['currency']}${amount.toStringAsFixed(2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxRow(String code1, String code2) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$code1   $code2',
        style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
    final isRailway = bookingType == 'train';
    final passengerCount = _bookingData['passengerCount'] ?? 1;
    final isRoundTrip = _bookingData['isRoundTrip'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ADDITIONAL INFORMATION',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (!isRailway) ...[
          const Text(
            '* NON-REFUNDABLE. NON-ENDORSABLE TO ANOTHER CARRIER.',
            style: TextStyle(fontSize: 9),
          ),
          const Text(
            'FARE RULES AND CHANGE/CANCELLATION PENALTIES APPLY AS PER AIRLINE POLICY.',
            style: TextStyle(fontSize: 9),
          ),
        ] else ...[
          const Text(
            '* NON-REFUNDABLE',
            style: TextStyle(fontSize: 9),
          ),
          const Text(
            'TICKET VALID FOR SPECIFIED TRAIN ONLY',
            style: TextStyle(fontSize: 9),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Trip Type: ${isRoundTrip ? "ROUND TRIP" : "ONE-WAY"}',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Total Passengers: $passengerCount',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Transaction ID: ${_bookingData['transactionId'] ?? 'N/A'}',
          style: const TextStyle(fontSize: 9),
        ),
        const SizedBox(height: 4),
        Text(
          'Booking Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
          style: const TextStyle(fontSize: 9),
        ),
        const SizedBox(height: 4),
        Text(
          'Status: CONFIRMED',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
      ],
    );
  }

  String _buildFareCalculationString() {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
    final isRailway = bookingType == 'train';

    if (isRailway) {
      // Train fare calculation
      final trainDetails = _bookingData['trainDetails'];
      final fromStation = trainDetails?['from']?.toString() ?? 'N/A';
      final toStation = trainDetails?['to']?.toString() ?? 'N/A';
      final classType = _bookingData['class'] ?? 'Economy';
      final passengerCount = _bookingData['passengerCount'] ?? 1;
      final baseFare = _bookingData['amount'] ?? 0.0;
      final perPaxFare =
          passengerCount > 0 ? baseFare / passengerCount : baseFare;

      return 'PR $fromStation X $toStation / $classType\n'
          'BASE FARE: PKR ${perPaxFare.toStringAsFixed(2)} x $passengerCount PAX\n'
          'TOTAL BASE: PKR ${baseFare.toStringAsFixed(2)}';
    } else {
      // Flight fare calculation
      final flightDetails = _bookingData['flightDetails'];
      final from = flightDetails?['from']?.toString() ?? 'N/A';
      final to = flightDetails?['to']?.toString() ?? 'N/A';
      final fromCode =
          RegExp(r'\(([A-Z]{3})\)').firstMatch(from)?.group(1) ?? 'XXX';
      final toCode =
          RegExp(r'\(([A-Z]{3})\)').firstMatch(to)?.group(1) ?? 'XXX';
      final classType = flightDetails?['class'] ?? 'Economy';
      final passengerCount = _bookingData['passengerCount'] ?? 1;
      final baseFare = _bookingData['amount'] ?? 0.0;
      final perPaxFare =
          passengerCount > 0 ? baseFare / passengerCount : baseFare;

      return '$fromCode X $toCode / $classType\n'
          'BASE FARE: PKR ${perPaxFare.toStringAsFixed(2)} x $passengerCount PAX\n'
          'TOTAL BASE: PKR ${baseFare.toStringAsFixed(2)}';
    }
  }

  // Helper: Build passenger names string
  String _buildPassengerNamesString() {
    final allPassengers = _bookingData['allPassengers'];
    if (allPassengers == null ||
        allPassengers is! List ||
        allPassengers.isEmpty) {
      return (_bookingData['passengerName']?.toUpperCase() ?? 'N/A');
    }

    // Get seat selections for displaying seat info
    final isRoundTrip = _bookingData['isRoundTrip'] == true;
    final outboundSeats = isRoundTrip
        ? ((_bookingData['outboundSeatSelections'] as List<dynamic>?) ?? [])
        : ((_bookingData['seatSelections'] as List<dynamic>?) ?? []);

    // If only 1 passenger, return single name with seat
    if (allPassengers.length == 1) {
      final passenger = allPassengers[0] as Map;
      final name = passenger['name']?.toString().toUpperCase() ?? 'N/A';
      final seat = outboundSeats.isNotEmpty && outboundSeats[0] is Map
          ? (outboundSeats[0]['seatName'] ?? '')
          : '';
      return seat.isNotEmpty ? '$name (Seat: $seat)' : name;
    }

    // For multiple passengers, list all names with seat assignments
    final names = <String>[];
    for (int i = 0; i < allPassengers.length; i++) {
      final passenger = allPassengers[i] as Map;
      final name =
          passenger['name']?.toString().toUpperCase() ?? 'PASSENGER ${i + 1}';
      final seat = i < outboundSeats.length && outboundSeats[i] is Map
          ? (outboundSeats[i]['seatName'] ?? '')
          : '';
      final seatInfo = seat.isNotEmpty ? ' (Seat: $seat)' : '';
      names.add('${i + 1}. $name$seatInfo');
    }
    return names.join('\n');
  }

  // Helper: Build return flight table for round trips
  Widget _buildReturnFlightTable() {
    final returnFlightDetails = _bookingData['returnFlightDetails'];
    if (returnFlightDetails == null) {
      return const SizedBox.shrink();
    }

    final departureDate = returnFlightDetails['date'] ?? 'N/A';
    final departureTime = returnFlightDetails['departure'] ?? 'N/A';
    final arrivalTime = returnFlightDetails['arrival'] ?? 'N/A';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(520.0, MediaQuery.of(context).size.width),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                color: Colors.blue.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 60,
                        child: Text('RETURN',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 90,
                        child: Text('DEPART/ARRIVE',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('AIRPORT/TERMINAL',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 90,
                        child: Text('CHECK-IN OPENS',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 70,
                        child: Text('CLASS',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 100,
                        child: Text('COUPON VALIDITY',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              // Return Flight Departure Row
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: Colors.grey.shade300, width: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            returnFlightDetails['flightNumber'] ?? 'N/A',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'CONFIRMED',
                            style:
                                TextStyle(fontSize: 9, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$departureDate\n$departureTime',
                              style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            returnFlightDetails['from'] ?? 'N/A',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                          Text(
                              'TERMINAL ${returnFlightDetails['departureTerminal'] ?? '1'}',
                              style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text('$departureDate\n0730',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    SizedBox(
                      width: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(returnFlightDetails['class'] ?? 'ECONOMY',
                              style: const TextStyle(fontSize: 10)),
                          const Text('27 K', style: TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                          'NOT AFTER ${DateFormat('dd MMM yy').format(DateTime.now().add(const Duration(days: 365))).toUpperCase()}',
                          style: const TextStyle(fontSize: 9)),
                    ),
                  ],
                ),
              ),
              // Return Flight Arrival Row
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 60),
                    SizedBox(
                      width: 90,
                      child: Text('$departureDate\n$arrivalTime',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            returnFlightDetails['to'] ?? 'N/A',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                          Text(
                              'TERMINAL ${returnFlightDetails['arrivalTerminal'] ?? '0'}',
                              style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 90),
                    const SizedBox(
                      width: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BAGGAGE', style: TextStyle(fontSize: 9)),
                          Text('ALLOWANCE 30KGS',
                              style: TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainTravelTable() {
    final trainDetails = _bookingData['trainDetails'];
    final departureDate = trainDetails?['date'] ?? 'N/A';
    final departureTime = trainDetails?['departure'] ?? 'N/A';
    final arrivalTime = trainDetails?['arrival'] ?? 'N/A';
    final duration = trainDetails?['duration'] ?? 'N/A';
    final classType = _bookingData['class'] ?? 'Economy';
    final isRoundTrip = _bookingData['isRoundTrip'] == true;

    // Get seat information from actual selections
    String coach = _bookingData['coach'] ?? 'B-1';
    String seatStr = 'N/A';

    if (isRoundTrip) {
      // For round trip, use outbound seat selections
      final outboundSeats =
          _bookingData['outboundSeatSelections'] as List<dynamic>? ?? [];
      if (outboundSeats.isNotEmpty) {
        // Extract unique coaches and seat names
        final coaches = <String>{};
        final seats = <String>[];

        for (var seatData in outboundSeats) {
          if (seatData is Map) {
            final seatName = (seatData['seatName'] ?? '').toString();
            final coachName = (seatData['coach'] ?? '').toString();
            if (seatName.isNotEmpty) {
              seats.add(seatName);
              if (coachName.isNotEmpty) coaches.add(coachName);
            }
          }
        }

        if (seats.isNotEmpty) {
          seatStr = seats.join(', ');
          if (coaches.isNotEmpty) coach = coaches.first;
        }
      }
    } else {
      // For one-way, use regular seat selections
      final seatSelections =
          _bookingData['seatSelections'] as List<dynamic>? ?? [];
      if (seatSelections.isNotEmpty) {
        final coaches = <String>{};
        final seats = <String>[];

        for (var seatData in seatSelections) {
          if (seatData is Map) {
            final seatName = (seatData['seatName'] ?? '').toString();
            final coachName = (seatData['coach'] ?? '').toString();
            if (seatName.isNotEmpty) {
              seats.add(seatName);
              if (coachName.isNotEmpty) coaches.add(coachName);
            }
          }
        }

        if (seats.isNotEmpty) {
          seatStr = seats.join(', ');
          if (coaches.isNotEmpty) coach = coaches.first;
        }
      } else {
        // Fallback to legacy seatNumbers if no selections stored
        final seats = _bookingData['seatNumbers'] ?? [];
        seatStr = seats.isNotEmpty ? (seats as List).join(', ') : 'N/A';
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(540.0, MediaQuery.of(context).size.width),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text('TRAIN',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 100,
                        child: Text('DEPART/ARRIVE',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('STATION',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 80,
                        child: Text('DURATION',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 100,
                        child: Text('CLASS/COACH',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 80,
                        child: Text('SEAT(S)',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              // Train Row 1 - Departure
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: Colors.grey.shade300, width: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trainDetails?['trainNumber']?.toString() ?? 'N/A',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'CONFIRMED',
                            style:
                                TextStyle(fontSize: 9, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text('$departureDate\n$departureTime',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    Expanded(
                      child: Text(
                        trainDetails?['from']?.toString() ?? 'N/A',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child:
                          Text(duration, style: const TextStyle(fontSize: 10)),
                    ),
                    SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(classType, style: const TextStyle(fontSize: 10)),
                          Text('Coach $coach',
                              style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child:
                          Text(seatStr, style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
              // Train Row 2 - Arrival
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 80),
                    SizedBox(
                      width: 100,
                      child: Text('$departureDate\n$arrivalTime',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    Expanded(
                      child: Text(
                        trainDetails?['to']?.toString() ?? 'N/A',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 80),
                    const SizedBox(width: 100),
                    const SizedBox(width: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnTrainTable() {
    final returnTrainDetails = _bookingData['returnTrainDetails'];
    final departureDate = returnTrainDetails?['date'] ?? 'N/A';
    final departureTime = returnTrainDetails?['departure'] ?? 'N/A';
    final arrivalTime = returnTrainDetails?['arrival'] ?? 'N/A';
    final duration = returnTrainDetails?['duration'] ?? 'N/A';
    final classType = _bookingData['class'] ?? 'Economy';

    // Get return seat information from actual selections
    String coach = _bookingData['coach'] ?? 'B-1';
    String seatStr = 'N/A';

    final returnSeats =
        _bookingData['returnSeatSelections'] as List<dynamic>? ?? [];
    if (returnSeats.isNotEmpty) {
      final coaches = <String>{};
      final seats = <String>[];

      for (var seatData in returnSeats) {
        if (seatData is Map) {
          final seatName = (seatData['seatName'] ?? '').toString();
          final coachName = (seatData['coach'] ?? '').toString();
          if (seatName.isNotEmpty) {
            seats.add(seatName);
            if (coachName.isNotEmpty) coaches.add(coachName);
          }
        }
      }

      if (seats.isNotEmpty) {
        seatStr = seats.join(', ');
        if (coaches.isNotEmpty) coach = coaches.first;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(540.0, MediaQuery.of(context).size.width),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text('RETURN TRAIN',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 100,
                        child: Text('DEPART/ARRIVE',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Text('STATION',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 80,
                        child: Text('DURATION',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 100,
                        child: Text('CLASS/COACH',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                    SizedBox(
                        width: 80,
                        child: Text('SEAT(S)',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              // Train Row 1 - Departure
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: Colors.grey.shade300, width: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            returnTrainDetails?['trainNumber']?.toString() ??
                                'N/A',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'CONFIRMED',
                            style:
                                TextStyle(fontSize: 9, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text('$departureDate\n$departureTime',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    Expanded(
                      child: Text(
                        returnTrainDetails?['from']?.toString() ?? 'N/A',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child:
                          Text(duration, style: const TextStyle(fontSize: 10)),
                    ),
                    SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(classType, style: const TextStyle(fontSize: 10)),
                          Text('Coach $coach',
                              style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child:
                          Text(seatStr, style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
              // Train Row 2 - Arrival
              Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 80),
                    SizedBox(
                      width: 100,
                      child: Text('$departureDate\n$arrivalTime',
                          style: const TextStyle(fontSize: 10)),
                    ),
                    Expanded(
                      child: Text(
                        returnTrainDetails?['to']?.toString() ?? 'N/A',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 80),
                    const SizedBox(width: 100),
                    const SizedBox(width: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Download Invoice PDF ──
  Future<void> _downloadInvoicePdf() async {
    try {
      final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
      final isRailway = bookingType == 'train';
      final invoiceNumber = _bookingData['pnr'] ?? 'N/A';
      final eTicketNumber = _bookingData['transactionId'] ?? 'N/A';
      final issuedDate =
          DateFormat('ddMMMyy').format(DateTime.now()).toUpperCase();
      final issuedTime = DateFormat('HHmm').format(DateTime.now());

      // Load Unicode-supporting font to eliminate warnings
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      final pdf = pw.Document(
        title: 'Tax Invoice - $invoiceNumber',
        author: 'Travello AI',
        creator: 'Travello AI',
        subject: isRailway ? 'Railway E-Ticket' : 'e-Ticket Receipt & Itinerary',
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // ═══ Header: Logo + Title + Barcode ═══
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Logo
                  pw.Container(
                    width: 60,
                    height: 60,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor(0.145, 0.388, 0.922),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'AI',
                        style: pw.TextStyle(
                          fontSize: 22,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Title
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Travello AI',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor(0.145, 0.388, 0.922),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          isRailway
                              ? 'Railway E-Ticket'
                              : 'e-Ticket Receipt & Itinerary',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // PNR Barcode
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          border:
                              pw.Border.all(color: PdfColors.black, width: 2),
                        ),
                        child: pw.Text(
                          invoiceNumber,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        eTicketNumber,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Introduction text
              pw.Text(
                isRailway
                    ? 'Your railway e-ticket is stored in our computer reservations system. This booking receipt is your official record of your train journey. Please keep this receipt for the duration of your travel. You may need to show this to railway staff during travel or at the station.'
                    : 'Your electronic ticket is stored in our computer reservations system. This e-Ticket receipt/itinerary is your record of your electronic ticket and where applicable, your contract of carriage. You may need to show this receipt to enter the airport and/or to prove this booking to customs and immigration officials.',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey800,
                  height: 1.5,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                isRailway
                    ? 'Your attention is drawn to the Pakistan Railways Terms and Conditions. Please visit us on www.travelloai.com for journey updates and station information.'
                    : 'Your attention is drawn to the Conditions of Contract and Other Important Notices set out in the attached document. Please visit us on www.travelloai.com to check-in online and for more information.',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey800,
                  height: 1.5,
                ),
              ),

              pw.SizedBox(height: 20),

              // PASSENGER AND TICKET INFORMATION
              _buildPdfSectionHeader('PASSENGER AND TICKET INFORMATION'),
              pw.SizedBox(height: 8),
              _buildPdfInfoTable([
                ['PASSENGER(S)', _buildPassengerNamesString()],
                ['TOTAL PASSENGERS', '${_bookingData['passengerCount'] ?? 1}'],
                ['BOOKING REFERENCE', invoiceNumber],
                ['E-TICKET NUMBER', eTicketNumber],
                [
                  'ISSUED BY / DATE',
                  (_bookingData['bookingType'] == 'train')
                      ? 'PAKISTAN RAILWAYS / TRAVELLO AI\n($issuedDate/${issuedTime}hr)'
                      : '${(_bookingData['flightDetails']?['airline'] as String?) ?? 'AIRLINE'} / TRAVELLO AI\n($issuedDate/${issuedTime}hr)'
                ],
              ]),

              pw.SizedBox(height: 20),

              // TRAVEL INFORMATION
              _buildPdfSectionHeader(_bookingData['isRoundTrip'] == true
                  ? 'TRAVEL INFORMATION (ROUND TRIP)'
                  : 'TRAVEL INFORMATION (ONE-WAY)'),
              pw.SizedBox(height: 8),
              _buildPdfTravelTable(),
              // Add return flight if round trip
              if (_bookingData['isRoundTrip'] == true &&
                  _bookingData['returnFlightDetails'] != null) ...[
                pw.SizedBox(height: 12),
                _buildPdfReturnFlightTable(),
              ],

              pw.SizedBox(height: 20),

              // FARE AND ADDITIONAL INFORMATION
              _buildPdfSectionHeader('FARE AND ADDITIONAL INFORMATION'),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildPdfFareBreakdown()),
                  pw.SizedBox(width: 20),
                  pw.Expanded(child: _buildPdfAdditionalInfo()),
                ],
              ),

              pw.SizedBox(height: 20),

              // FARE CALCULATIONS
              _buildPdfSectionHeader('FARE CALCULATIONS'),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(0.96, 0.96, 0.96),
                  border: pw.Border.all(color: const PdfColor(0.8, 0.8, 0.8)),
                ),
                child: pw.Text(
                  _buildFareCalculationString(),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // Footer Notice
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  color: PdfColor(0.95, 0.95, 0.95),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Important Notice',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Please check with departure airport for restrictions on the carriage of liquids, aerosols and gels in hand baggage.',
                      style: const pw.TextStyle(fontSize: 10, height: 1.4),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'For customer support, please contact: support@travelloai.com | +92 300 1234567',
                      style: const pw.TextStyle(fontSize: 10, height: 1.4),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.grey.shade100,
              appBar: AppBar(
                title: const Text('Invoice Preview'),
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: PdfPreview(
                build: (_) async => pdfBytes,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                initialPageFormat: PdfPageFormat.a4,
                pdfFileName: 'travello_invoice_$invoiceNumber.pdf',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  // PDF Helper Methods for Emirates Format

  pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const PdfColor(0.7, 0.7, 0.7),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  pw.Widget _buildPdfInfoTable(List<List<String>> rows) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor(0.8, 0.8, 0.8)),
      ),
      child: pw.Column(
        children: rows.map((row) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom:
                    pw.BorderSide(color: PdfColor(0.9, 0.9, 0.9), width: 0.5),
              ),
            ),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 150,
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    row[1],
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _buildPdfTravelTable() {
    final flightNumber =
        _bookingData['flightDetails']?['flightNumber'] ?? 'N/A';
    final from = _bookingData['flightDetails']?['from'] ?? 'N/A';
    final to = _bookingData['flightDetails']?['to'] ?? 'N/A';
    final date = _bookingData['flightDetails']?['date'] ?? 'N/A';
    final time = _bookingData['flightDetails']?['time'] ?? 'N/A';
    final departureTerminal =
        _bookingData['flightDetails']?['departureTerminal'] ?? '1';
    final arrivalTerminal =
        _bookingData['flightDetails']?['arrivalTerminal'] ?? '1';

    return pw.Table(
      border: pw.TableBorder.all(color: const PdfColor(0.8, 0.8, 0.8)),
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        1: const pw.FixedColumnWidth(80),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(90),
      },
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor(0.9, 0.9, 0.9)),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('FLIGHT',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('DEPART/\nARRIVE',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('AIRPORT/TERMINAL',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('CHECK-IN\nOPENS',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('CLASS',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('COUPON\nVALIDITY',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        // Departure Row
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(flightNumber,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('CONFIRMED',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                '$date\n$time',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(from,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('TERMINAL $departureTerminal',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                '$date\n0730',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ECONOMY', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 2),
                  pw.Text('27 K',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'NOT AFTER\n${DateFormat('dd MMM yy').format(DateTime.now().add(const Duration(days: 365))).toUpperCase()}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
        // Arrival Row
        pw.TableRow(
          children: [
            pw.Container(), // Empty for flight column
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                '$date\n${_calculateArrivalTime(time)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(to,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('TERMINAL $arrivalTerminal',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Container(), // Empty
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BAGGAGE',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('ALLOWANCE\n30KGS',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.Container(), // Empty
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfFareBreakdown() {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
    final isRailway = bookingType == 'train';
    final passengerCount = _bookingData['passengerCount'] ?? 1;
    final amount = _bookingData['amount'] ?? 0.0;
    final perPassengerFare =
        passengerCount > 0 ? amount / passengerCount : amount;
    final serviceFee = _bookingData['serviceFee'] ?? 0.0;
    final tax = _bookingData['tax'] ?? 0.0;
    final insuranceFee = _bookingData['insuranceFee'] ?? 0.0;
    final total = _bookingData['total'] ?? 0.0;
    final currency = _bookingData['currency'] ?? 'PKR';
    final paymentMethod = _bookingData['paymentMethod'] ?? 'N/A';

    // RABTA fee for trains (Rs. 10 per adult passenger) — mirrors the
    // in-app breakdown in _buildFareBreakdown().
    final passengers = _bookingData['allPassengers'] as List<dynamic>? ?? [];
    final adultCount = passengers
        .where((p) => (p['concessionType'] ?? 'ADULT') == 'ADULT')
        .length;
    final rabtaFee = isRailway ? (adultCount * 10.0) : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FARE',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (passengerCount > 1) ...[
          _buildPdfFareRow(
              'Base Fare (per passenger)', perPassengerFare, currency),
          _buildPdfFareRow(
              'Base Fare (x$passengerCount passengers)', amount, currency),
        ] else
          _buildPdfFareRow('Base Fare', amount, currency),
        if (serviceFee > 0)
          _buildPdfFareRow('Service Fee', serviceFee, currency),
        pw.SizedBox(height: 10),
        pw.Text(
          'TAXES/FEES/CHARGES',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (isRailway) ...[
          if (rabtaFee > 0)
            _buildPdfFareRow('RABTA Database', rabtaFee, currency),
          _buildPdfFareRow('Reservation (Online)', 0.0, currency),
        ] else ...[
          if (tax > 0)
            _buildPdfFareRow('Taxes & Government Fees', tax, currency),
          if (insuranceFee > 0)
            _buildPdfFareRow('Travel Insurance', insuranceFee, currency),
        ],
        pw.SizedBox(height: 10),
        pw.Divider(color: const PdfColor(0.7, 0.7, 0.7), thickness: 1),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              '$currency ${total.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'FORM OF PAYMENT',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          paymentMethod.toUpperCase(),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '*You may be asked to present the card used for this payment at check-in.*',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _buildPdfAdditionalInfo() {
    final bookingType = _bookingData['bookingType'] as String? ?? 'flight';
    final isRailway = bookingType == 'train';
    final passengerCount = _bookingData['passengerCount'] ?? 1;
    final isRoundTrip = _bookingData['isRoundTrip'] == true;
    final transactionId = _bookingData['transactionId'] ?? 'N/A';
    final date = DateFormat('dd MMM yyyy').format(DateTime.now());

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ADDITIONAL INFORMATION',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (isRailway) ...[
          pw.Text(
            '* NON-REFUNDABLE',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'TICKET VALID FOR SPECIFIED TRAIN ONLY',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ] else ...[
          pw.Text(
            '* NON-REFUNDABLE. NON-ENDORSABLE TO ANOTHER CARRIER.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'FARE RULES AND CHANGE/CANCELLATION PENALTIES APPLY AS PER AIRLINE POLICY.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        pw.SizedBox(height: 12),
        pw.Text(
          'Trip Type: ${isRoundTrip ? "ROUND TRIP" : "ONE-WAY"}',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Total Passengers: $passengerCount',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Transaction ID: $transactionId',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          'Booking Date: $date',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          'Status: CONFIRMED',
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor(0.2, 0.6, 0.2)),
        ),
      ],
    );
  }

  pw.Widget _buildPdfFareRow(String label, double amount, String currency) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            '$currency ${amount.toStringAsFixed(2)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfReturnFlightTable() {
    final returnFlightDetails = _bookingData['returnFlightDetails'];
    if (returnFlightDetails == null) {
      return pw.SizedBox.shrink();
    }

    final departureDate = returnFlightDetails['date'] ?? 'N/A';
    final departureTime = returnFlightDetails['departure'] ?? 'N/A';
    final arrivalTime = returnFlightDetails['arrival'] ?? 'N/A';
    final departureTerminal = returnFlightDetails['departureTerminal'] ?? '1';
    final arrivalTerminal = returnFlightDetails['arrivalTerminal'] ?? '1';

    return pw.Table(
      border: pw.TableBorder.all(color: const PdfColor(0.8, 0.8, 0.8)),
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        1: const pw.FixedColumnWidth(80),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(90),
      },
      children: [
        // Table Header for Return Flight
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor(0.7, 0.85, 1.0)),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('RETURN',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('DEPART/\nARRIVE',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('AIRPORT/TERMINAL',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('CHECK-IN\nOPENS',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('CLASS',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('COUPON\nVALIDITY',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        // Departure Row
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(returnFlightDetails['flightNumber'] ?? 'N/A',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('CONFIRMED',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                '$departureDate\n$departureTime',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(returnFlightDetails['from'] ?? 'N/A',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('TERMINAL $departureTerminal',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                '$departureDate\n0730',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(returnFlightDetails['class'] ?? 'ECONOMY',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 2),
                  pw.Text('27 K',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                'NOT AFTER\n${DateFormat('dd MMM yy').format(DateTime.now().add(const Duration(days: 365))).toUpperCase()}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
        ),
        // Arrival Row
        pw.TableRow(
          children: [
            pw.Container(), // Empty for flight column
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                '$departureDate\n$arrivalTime',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(returnFlightDetails['to'] ?? 'N/A',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('TERMINAL $arrivalTerminal',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Container(), // Empty
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BAGGAGE',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('ALLOWANCE\n30KGS',
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.Container(), // Empty
          ],
        ),
      ],
    );
  }

  // ── Loading Skeleton ──
  Widget _buildLoadingSkeleton() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(TravelloTheme.primaryMain),
          ),
          SizedBox(height: 16),
          Text(
            'Loading booking details...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hoverable extra card tile ─────────────────────────────────────────────────
class _ExtraCardTile extends StatefulWidget {
  final _TravelExtra ex;
  const _ExtraCardTile({required this.ex});
  @override
  State<_ExtraCardTile> createState() => _ExtraCardTileState();
}

class _ExtraCardTileState extends State<_ExtraCardTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.ex;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: ex.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _hovered
                ? ex.iconColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: ex.iconColor.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                AnimatedScale(
                  scale: _hovered ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ex.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(ex.icon, color: ex.iconColor, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(ex.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                )),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ex.tagColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color:
                                          ex.tagColor.withValues(alpha: 0.25)),
                                ),
                                child: Text(ex.tag,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: ex.tagColor,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    )),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(ex.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 94),
                    child: AnimatedSlide(
                      offset: _hovered ? const Offset(0.15, 0) : Offset.zero,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(ex.action,
                              style: TextStyle(
                                fontSize: 11,
                                color: ex.iconColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                          const SizedBox(height: 2),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: ex.iconColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
