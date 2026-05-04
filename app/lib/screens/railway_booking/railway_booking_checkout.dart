import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flight_app/screens/railway/train_results_screen.dart';
import 'package:flight_app/models/railway_station.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PROFESSIONAL TRAIN CHECKOUT SCREEN - Green Theme
// ═════════════════════════════════════════════════════════════════════════════

class RailwayBookingCheckout extends StatefulWidget {
  const RailwayBookingCheckout({super.key});

  @override
  State<RailwayBookingCheckout> createState() => _RailwayBookingCheckoutState();
}

class _RailwayBookingCheckoutState extends State<RailwayBookingCheckout> {
  late TrainResult _train;
  late List<Map<String, dynamic>> _passengers;
  late String _contactEmail;
  late String _contactPhone;
  late String _fromStation;
  late String _toStation;
  late String _fromStationCode;
  late String _toStationCode;
  late DateTime _departureDate;
  late String _selectedClass;
  String? _outboundClass;
  String? _returnClass;

  // Round trip support
  bool _isRoundTrip = false;
  TrainResult? _outboundTrain;
  TrainResult? _returnTrain;
  DateTime? _returnDate;

  // Seat selections
  List<Map<String, dynamic>> _seatSelections = [];
  List<Map<String, dynamic>> _outboundSeatSelections = [];
  List<Map<String, dynamic>> _returnSeatSelections = [];
  double _seatTotal = 0.0;

  // Ground Transfer
  bool _transferAdded = false;
  String _transferVehicleType = 'Sedan';
  double _transferFee = 0.0;

  bool _agreedToTerms = false;
  bool _showTermsError = false;
  bool _isCreatingBooking = false;
  String? _backendBookingId;
  String? _backendPnr;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map<String, dynamic>?) ?? {};

    // Round trip detection
    _isRoundTrip = args['isRoundTrip'] as bool? ?? false;
    _outboundTrain = args['outboundTrain'] as TrainResult?;
    _returnTrain = args['returnTrain'] as TrainResult?;
    _selectedClass = args['selectedClass'] as String? ?? 'Economy';
    _outboundClass = args['outboundClass'] as String?;
    _returnClass = args['returnClass'] as String?;

    _train = (_isRoundTrip ? _outboundTrain : args['train']) as TrainResult;

    // Extract station names and codes from searchParams (which contains RailwayStation objects)
    final searchParams = args['searchParams'] as Map<String, dynamic>?;
    if (searchParams != null) {
      final fromStation = searchParams['fromStation'] as RailwayStation?;
      final toStation = searchParams['toStation'] as RailwayStation?;
      _fromStation = fromStation?.name ?? 'Karachi';
      _toStation = toStation?.name ?? 'Lahore';
      _fromStationCode = fromStation?.code ?? 'KAR';
      _toStationCode = toStation?.code ?? 'LAH';
    } else {
      _fromStation = args['fromStation'] as String? ?? 'Karachi';
      _toStation = args['toStation'] as String? ?? 'Lahore';
      _fromStationCode = args['fromStationCode'] as String? ?? 'KAR';
      _toStationCode = args['toStationCode'] as String? ?? 'LAH';
    }

    _departureDate = args['departureDate'] as DateTime? ?? DateTime.now();
    _returnDate = args['returnDate'] as DateTime?;

    final raw = (args['passengers'] as List<dynamic>?) ?? [];
    _passengers = raw.map((p) => Map<String, dynamic>.from(p as Map)).toList();

    _contactEmail = args['contactEmail'] as String? ?? '';
    _contactPhone = args['contactPhone'] as String? ?? '';

    // Load seat selections
    if (_isRoundTrip) {
      // Round trip - load both outbound and return seats
      final rawOutbound =
          (args['outboundSeatSelections'] as List<dynamic>?) ?? [];
      _outboundSeatSelections =
          rawOutbound.map((s) => Map<String, dynamic>.from(s as Map)).toList();

      final rawReturn = (args['returnSeatSelections'] as List<dynamic>?) ?? [];
      _returnSeatSelections =
          rawReturn.map((s) => Map<String, dynamic>.from(s as Map)).toList();

      // For compatibility, merge both into _seatSelections (used in some displays)
      _seatSelections = [..._outboundSeatSelections];
    } else {
      // One-way trip
      final rawSeats = (args['seatSelections'] as List<dynamic>?) ?? [];
      _seatSelections =
          rawSeats.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    }
    _seatTotal = args['seatTotal'] as double? ?? 0.0;

    // Ground Transfer
    _transferAdded = args['transferAdded'] as bool? ?? false;
    _transferVehicleType = args['transferVehicleType'] as String? ?? 'Sedan';
    _transferFee = _transferAdded
        ? (const {
              'Sedan': 800.0,
              'SUV': 1200.0,
              'Van': 1500.0
            }[_transferVehicleType] ??
            800.0)
        : 0.0;
  }

  String _formatPrice(double amount) {
    final n = amount.toStringAsFixed(0);
    final buf = StringBuffer();
    int start = n.length % 3;
    if (start > 0) buf.write(n.substring(0, start));
    for (int i = start; i < n.length; i += 3) {
      if (buf.isNotEmpty) buf.write(',');
      buf.write(n.substring(i, i + 3));
    }
    return 'PKR ${buf.toString()}';
  }

  String _detailedPriceBreakdown() {
    // Count passenger types from the list
    int adults = 0, children = 0, infants = 0;
    for (var passenger in _passengers) {
      final concessionType = passenger['concessionType'] as String? ?? 'ADULT';
      if (concessionType == 'INFANT') {
        infants++;
      } else if (concessionType == 'CHILD_3_10') {
        children++;
      } else {
        adults++;
      }
    }

    final parts = <String>[];
    if (adults > 0) {
      parts.add('$adults Adult${adults > 1 ? 's' : ''} (full fare)');
    }
    if (children > 0) {
      parts.add('$children Child${children > 1 ? 'ren' : ''} (50% off)');
    }
    if (infants > 0) {
      parts.add('$infants Infant${infants > 1 ? 's' : ''} (free)');
    }

    final breakdown = parts.join(' + ');
    return '${_passengers.length} pax | $breakdown';
  }

  String _formatDateOfBirth(dynamic dob) {
    if (dob == null) return '14 January 1990';
    if (dob is DateTime) {
      return DateFormat('dd MMMM yyyy').format(dob);
    }
    if (dob is String) {
      try {
        final date = DateTime.parse(dob);
        return DateFormat('dd MMMM yyyy').format(date);
      } catch (e) {
        return dob;
      }
    }
    return '14 January 1990';
  }

  double get _ticketPrice {
    // Get base price
    double basePrice = 0.0;
    if (_isRoundTrip && _outboundTrain != null && _returnTrain != null) {
      final outPrice =
          _outboundTrain!.classPrices[_outboundClass ?? _selectedClass] ?? 0.0;
      final retPrice =
          _returnTrain!.classPrices[_returnClass ?? _selectedClass] ?? 0.0;
      basePrice = outPrice + retPrice;
    } else {
      basePrice = _train.classPrices[_selectedClass] ?? 0.0;
    }

    // Apply concessions (children get 50% discount, infants travel free)
    double total = 0.0;
    for (var passenger in _passengers) {
      final concessionType = passenger['concessionType'] as String? ?? 'ADULT';
      if (concessionType == 'INFANT') {
        total += 0.0; // Infants (under 3 years) travel free
      } else if (concessionType == 'CHILD_3_10') {
        total += basePrice * 0.5; // Children (3-11 years) get 50% discount
      } else {
        total += basePrice; // Adults (12+ years) pay full fare
      }
    }
    return total;
  }

  double get _subtotal => _ticketPrice + _seatTotal + _transferFee;
  double get _grandTotal => _subtotal;

  String _getInitials(Map<String, dynamic> passenger) {
    final firstName = (passenger['firstName'] as String? ?? '').trim();
    final lastName = (passenger['lastName'] as String? ?? '').trim();

    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0].toUpperCase();
    if (lastName.isNotEmpty) initials += lastName[0].toUpperCase();

    return initials.isEmpty ? 'P' : initials;
  }

  String _getPassengerTypeLabel(Map<String, dynamic> passenger) {
    final concessionType = passenger['concessionType'] as String? ?? 'ADULT';
    switch (concessionType) {
      case 'INFANT':
        return 'INFANT';
      case 'CHILD_3_10':
        return 'CHILD';
      default:
        return 'ADULT';
    }
  }

  String _toTrainClassCode(String className) {
    final normalized = className.toLowerCase();
    if (normalized.contains('business')) return 'ACB';
    if (normalized.contains('parlour')) return 'PAR';
    if (normalized.contains('sleeper')) return 'SL';
    if (normalized.contains('ac bus')) return 'BUS-AC';
    if (normalized.contains('standard bus')) return 'BUS-STD';
    if (normalized.contains('ac')) return 'AC';
    return 'EC';
  }

  String _toPassengerType(Map<String, dynamic> passenger) {
    final concession =
        (passenger['concessionType'] ?? passenger['type'] ?? 'ADULT')
            .toString()
            .toUpperCase();
    if (concession == 'INFANT') return 'infant';
    if (concession == 'CHILD_3_10' || concession == 'CHILD') return 'child';
    return 'adult';
  }

  Future<void> _proceedToCheckout() async {
    if (!_agreedToTerms) {
      setState(() => _showTermsError = true);
      Get.snackbar(
        'Terms Required',
        'Please accept Terms & Conditions and Privacy Policy to continue',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    // Get passenger counts from searchParams and fallback to entered list.
    final searchParams =
        Get.arguments?['searchParams'] as Map<String, dynamic>?;
    final adults = (searchParams?['adults'] as int?) ?? 1;
    final children = (searchParams?['children'] as int?) ?? 0;
    final infants = (searchParams?['infants'] as int?) ?? 0;
    final passengerCount = _passengers.isNotEmpty
        ? _passengers.length.clamp(1, 9)
        : (adults + children + infants).clamp(1, 9);

    setState(() => _isCreatingBooking = true);
    try {
      final selectedClassForBooking =
          _isRoundTrip ? (_outboundClass ?? _selectedClass) : _selectedClass;
      final booking = await ApiClient.bookTrain(
        trainId: _train.id,
        classCode: _toTrainClassCode(selectedClassForBooking),
        contactEmail: _contactEmail,
        passengers: passengerCount,
        contactPhone: _contactPhone.isNotEmpty ? _contactPhone : null,
      );

      _backendBookingId =
          booking['booking_uuid']?.toString() ?? booking['id']?.toString();
      _backendPnr = booking['pnr']?.toString();

      if (_backendBookingId != null && _passengers.isNotEmpty) {
        await ApiClient.addPassengers(
          bookingId: _backendBookingId!,
          passengers: _passengers
              .map(
                (p) => {
                  'title': p['title'] ?? 'Mr',
                  'first_name': p['firstName'] ?? p['first_name'] ?? '',
                  'last_name': p['lastName'] ?? p['last_name'] ?? '',
                  'date_of_birth': p['dateOfBirth'] ?? p['date_of_birth'] ?? '',
                  'gender': p['gender'] ?? 'male',
                  'cnic': p['cnic'] ?? p['idNumber'] ?? '',
                  'passenger_type': _toPassengerType(p),
                },
              )
              .toList(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e
          .toString()
          .replaceFirst('Exception:', '')
          .trim()
          .replaceFirst('Train booking failed:', '')
          .trim();
      Get.snackbar(
        'Booking Failed',
        message.isNotEmpty
            ? message
            : 'Unable to create train booking. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    } finally {
      if (mounted) setState(() => _isCreatingBooking = false);
    }

    if (_backendBookingId == null || _backendBookingId!.isEmpty) {
      Get.snackbar(
        'Booking Failed',
        'Booking was not created on server. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // Pre-compute per-train prices so payment page never re-derives them
    final outPrice = _isRoundTrip && _outboundTrain != null
        ? (_outboundTrain!.classPrices[_outboundClass ?? _selectedClass] ?? 0.0)
        : 0.0;
    final retPrice = _isRoundTrip && _returnTrain != null
        ? (_returnTrain!.classPrices[_returnClass ?? _selectedClass] ?? 0.0)
        : 0.0;

    Get.toNamed(AppLink.railwayPayment, arguments: {
      'train': _train,
      'passengers': _passengers,
      'totalAmount': _grandTotal,
      'baseFare': _ticketPrice, // already applies concessions correctly
      'seatTotal': _seatTotal,
      'isRoundTrip': _isRoundTrip,
      'outboundTrain': _outboundTrain,
      'returnTrain': _returnTrain,
      'outboundClass': _outboundClass,
      'returnClass': _returnClass,
      'outPrice': outPrice,
      'retPrice': retPrice,
      'returnDate': _returnDate,
      'contactEmail': _contactEmail,
      'contactPhone': _contactPhone,
      'fromStation': _fromStation,
      'toStation': _toStation,
      'fromStationCode': _fromStationCode,
      'toStationCode': _toStationCode,
      'selectedClass': _selectedClass,
      'departureDate': _departureDate,
      'adults': adults,
      'children': children,
      'infants': infants,
      // Seat selections (handle both one-way and round trip)\n      'seatSelections': _seatSelections,
      'outboundSeatSelections': _outboundSeatSelections,
      'returnSeatSelections': _returnSeatSelections,
      'transferAdded': _transferAdded,
      'transferVehicleType': _transferVehicleType,
      'transferFee': _transferFee,
      'backendBookingId': _backendBookingId,
      'backendPnr': _backendPnr,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Light background
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepProgress(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoBanner(),
                  const SizedBox(height: 24),
                  _buildTrainDetails(),
                  const SizedBox(height: 24),
                  if (_isRoundTrip && _returnTrain != null) ...[
                    _buildReturnTrainDetails(),
                    const SizedBox(height: 24),
                  ],
                  _buildPassengerDetails(),
                  const SizedBox(height: 24),
                  _buildContactDetails(),
                  const SizedBox(height: 24),
                  _buildPriceDetail(),
                  const SizedBox(height: 24),
                  _buildRulesAndPolicy(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildCheckoutButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFD4AF37),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: const Text(
        'Checkout',
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
          tooltip: 'Help & FAQs',
        ),
      ],
    );
  }

  Widget _buildStepProgress() {
    const steps = ['PASSENGERS', 'CLASS', 'CHECKOUT', 'PAYMENT', 'DONE'];
    const goldColor = Color(0xFFD4AF37);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(9, (i) {
          if (i.isOdd) {
            final stepBefore = i ~/ 2;
            final isCompleted = stepBefore < 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: isCompleted ? goldColor : const Color(0xFFE0E0E0),
              ),
            );
          }
          final index = i ~/ 2;
          final isActive = index == 2;
          final isCompleted = index < 2;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? goldColor
                      : const Color(0xFFE0E0E0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color:
                                isActive ? Colors.white : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: isCompleted || isActive
                      ? goldColor
                      : Colors.grey.shade500,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D3),
        border:
            const Border(left: BorderSide(color: Color(0xFFD4AF37), width: 4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please ensure you have all necessary travel documents and arrive at the railway station at least 30 minutes before departure.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainDetails() {
    final depDate = DateFormat('dd MMM').format(_departureDate);
    const greenTheme = Color(0xFFD4AF37);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isRoundTrip) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E6D3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6C68E)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.train_rounded, size: 17, color: greenTheme),
                SizedBox(width: 7),
                Text(
                  'Outbound Journey',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: greenTheme),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Departure', style: TravelloTheme.sectionHeading),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0), // Light gray container
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Direct - Duration: ${_train.duration}',
                style: TravelloTheme.durationBadge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFF5F5F5), // Light card
            border: Border.all(
                color: greenTheme.withValues(alpha: 0.18), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: greenTheme.withValues(alpha: 0.10),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$_fromStation($_fromStationCode) - $_toStation($_toStationCode)',
                        style: TravelloTheme.cardHeading,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: Color(0xFF666666)),
                    const SizedBox(width: 5),
                    Text(
                      _train.duration,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB3B3B3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Top section: Times + Station codes ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Column(
                  children: [
                    // Times row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _train.departureTime,
                                style: TextStyle(
                                    fontSize: R.sp(context, 34),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    letterSpacing: -1.8,
                                    height: 1.0),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                depDate,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666), // Gray text
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _train.arrivalTime,
                                style: TextStyle(
                                    fontSize: R.sp(context, 34),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    letterSpacing: -1.8,
                                    height: 1.0),
                                textAlign: TextAlign.end,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                depDate,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666), // Gray text
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Station codes + Timeline
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // From station badge
                        Flexible(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  color: greenTheme.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      color: greenTheme.withValues(alpha: 0.25),
                                      width: 1),
                                ),
                                child: Text(
                                  _fromStationCode,
                                  style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: greenTheme,
                                      letterSpacing: 1.6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _fromStation,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB3B3B3),
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Timeline
                        Expanded(
                          child: Row(
                            children: [
                              // Left dot
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: greenTheme, width: 2.3),
                                  color: Colors.white,
                                ),
                              ),
                              // Left dashed line
                              Expanded(
                                child: CustomPaint(
                                  painter: _DashedLinePainter(
                                      color: Colors.grey.shade300),
                                  child: const SizedBox(height: 2),
                                ),
                              ),
                              // Train icon
                              const Icon(Icons.train_rounded,
                                  size: 30, color: greenTheme),
                              // Right dashed line
                              Expanded(
                                child: CustomPaint(
                                  painter: _DashedLinePainter(
                                      color: Colors.grey.shade300),
                                  child: const SizedBox(height: 2),
                                ),
                              ),
                              // Right dot (filled)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle, color: greenTheme),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // To station badge
                        Flexible(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  color: greenTheme.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      color: greenTheme.withValues(alpha: 0.25),
                                      width: 1),
                                ),
                                child: Text(
                                  _toStationCode,
                                  style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: greenTheme,
                                      letterSpacing: 1.6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _toStation,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB3B3B3),
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: const Color(0xFFE0E0E0), // Light divider
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E6D3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.train, color: greenTheme, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _train.trainName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Train ${_train.trainNumber}',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFB3B3B3)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E6D3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE6C68E)),
                      ),
                      child: Text(
                        _selectedClass,
                        style: const TextStyle(
                          color: greenTheme,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReturnTrainDetails() {
    if (_returnTrain == null || _returnDate == null) {
      return const SizedBox.shrink();
    }

    final depDate = DateFormat('dd MMM').format(_returnDate!);
    const greenTheme = Color(0xFFD4AF37);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF5E6D3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE6C68E)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.train_rounded, size: 17, color: Color(0xFFD4AF37)),
              SizedBox(width: 7),
              Text(
                'Return Journey',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD4AF37)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Return', style: TravelloTheme.sectionHeading),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0), // Light gray container
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Direct - Duration: ${_returnTrain!.duration}',
                style: TravelloTheme.durationBadge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFF5F5F5), // Light card
            border: Border.all(
                color: greenTheme.withValues(alpha: 0.18), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: greenTheme.withValues(alpha: 0.10),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$_toStation($_toStationCode) - $_fromStation($_fromStationCode)',
                        style: TravelloTheme.cardHeading,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: Color(0xFF666666)),
                    const SizedBox(width: 5),
                    Text(
                      _returnTrain!.duration,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB3B3B3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Top section: Times + Station codes ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Column(
                  children: [
                    // Times row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _returnTrain!.departureTime,
                                style: TextStyle(
                                    fontSize: R.sp(context, 34),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    letterSpacing: -1.8,
                                    height: 1.0),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                depDate,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666), // Gray text
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _returnTrain!.arrivalTime,
                                style: TextStyle(
                                    fontSize: R.sp(context, 34),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    letterSpacing: -1.8,
                                    height: 1.0),
                                textAlign: TextAlign.end,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                depDate,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666), // Gray text
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Station codes + Timeline
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // From station badge
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: greenTheme.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: greenTheme.withValues(alpha: 0.25),
                                    width: 1),
                              ),
                              child: Text(
                                _toStationCode,
                                style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: greenTheme,
                                    letterSpacing: 1.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 80,
                              child: Text(
                                _toStation,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB3B3B3),
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),

                        // Timeline
                        Expanded(
                          child: Row(
                            children: [
                              // Left dot
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: greenTheme, width: 2.3),
                                  color: Colors.white,
                                ),
                              ),
                              // Left dashed line
                              Expanded(
                                child: CustomPaint(
                                  painter: _DashedLinePainter(
                                      color: Colors.grey.shade300),
                                  child: const SizedBox(height: 2),
                                ),
                              ),
                              // Train icon
                              const Icon(Icons.train_rounded,
                                  size: 30, color: greenTheme),
                              // Right dashed line
                              Expanded(
                                child: CustomPaint(
                                  painter: _DashedLinePainter(
                                      color: Colors.grey.shade300),
                                  child: const SizedBox(height: 2),
                                ),
                              ),
                              // Right dot (filled)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle, color: greenTheme),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // To station badge
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: greenTheme.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: greenTheme.withValues(alpha: 0.25),
                                    width: 1),
                              ),
                              child: Text(
                                _fromStationCode,
                                style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: greenTheme,
                                    letterSpacing: 1.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 80,
                              child: Text(
                                _fromStation,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB3B3B3),
                                    fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: const Color(0xFFE0E0E0), // Light divider
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E6D3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.train, color: greenTheme, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _returnTrain!.trainName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Train ${_returnTrain!.trainNumber}',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFB3B3B3)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E6D3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE6C68E)),
                      ),
                      child: Text(
                        _returnClass ?? _selectedClass,
                        style: const TextStyle(
                          color: greenTheme,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passenger Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(_passengers.length, (index) {
                final p = _passengers[index];
                final isLast = index == _passengers.length - 1;

                // Get seat information
                String outboundSeatName = '-';
                String outboundCoach = '-';
                String returnSeatName = '-';
                String returnCoach = '-';

                if (_isRoundTrip) {
                  // Round trip - show both outbound and return seats
                  if (index < _outboundSeatSelections.length) {
                    final seatData = _outboundSeatSelections[index];
                    outboundSeatName = (seatData['seatName'] ?? '-').toString();
                    outboundCoach = (seatData['coach'] ?? '-').toString();
                  }
                  if (index < _returnSeatSelections.length) {
                    final seatData = _returnSeatSelections[index];
                    returnSeatName = (seatData['seatName'] ?? '-').toString();
                    returnCoach = (seatData['coach'] ?? '-').toString();
                  }
                } else {
                  // One-way trip
                  if (index < _seatSelections.length) {
                    final seatData = _seatSelections[index];
                    outboundSeatName = (seatData['seatName'] ?? '-').toString();
                    outboundCoach = (seatData['coach'] ?? '-').toString();
                  }
                }

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5E6D3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getInitials(p),
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Passenger ${index + 1}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFFB3B3B3)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p['firstName']} ${p['lastName']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ID Number',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF666666)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          p['idNumber'] ?? '12345-6789012-3',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Date of Birth',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF666666)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _formatDateOfBirth(p['dob']),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Seat and Coach Information
                              if (_isRoundTrip) ...[
                                // Outbound seat
                                if (outboundSeatName != '-' &&
                                    outboundCoach != '-') ...[
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5E6D3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE6C68E)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event_seat,
                                            size: 18, color: Color(0xFFD4AF37)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Outbound: $outboundSeatName • $outboundCoach',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                // Return seat
                                if (returnSeatName != '-' &&
                                    returnCoach != '-') ...[
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5E6D3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE6C68E)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event_seat,
                                            size: 18, color: Color(0xFFD4AF37)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Return: $returnSeatName • $returnCoach',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ] else ...[
                                // One-way seat
                                if (outboundSeatName != '-' &&
                                    outboundCoach != '-') ...[
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5E6D3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE6C68E)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event_seat,
                                            size: 18, color: Color(0xFFD4AF37)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Seat: $outboundSeatName • $outboundCoach',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFD4AF37),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                              // Class Type
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Class Type',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF666666)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$_selectedClass (Seat)',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Details',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF666666)),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _getPassengerTypeLabel(p),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isLast) ...[
                      const SizedBox(height: 16),
                      const Divider(
                          height: 1, color: Color(0xFFE0E0E0)), // Light divider
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactDetails() {
    final contact = _passengers.isNotEmpty ? _passengers[0] : {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 18, color: Color(0xFFB3B3B3)),
                  const SizedBox(width: 8),
                  Text(
                    '${contact['firstName'] ?? ''} ${contact['lastName'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email*',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFFB3B3B3)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined,
                                size: 16, color: Color(0xFFB3B3B3)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _contactEmail.isEmpty
                                    ? 'hubravo29@gmail.com'
                                    : _contactEmail,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number*',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFFB3B3B3)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(
                                    0xFFE0E0E0), // Light gray container
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.network(
                                    'https://flagcdn.com/w20/pk.png',
                                    width: 16,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.flag, size: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '+92',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _contactPhone.isEmpty
                                    ? '304 2757881'
                                    : _contactPhone,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E6D3),
                  border: const Border(
                      left: BorderSide(color: Color(0xFFD4AF37), width: 4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFD4AF37), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade800),
                          children: [
                            const TextSpan(
                                text:
                                    'Note: We will send your booking confirmation to '),
                            TextSpan(
                              text: _contactEmail.isEmpty
                                  ? 'hubravo29@gmail.com'
                                  : _contactEmail,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceDetail() {
    const greenTheme = Color(0xFFD4AF37);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Price Detail',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5), // Light card
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E0E0)), // Light divider
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPriceRow(
                      icon: Icons.confirmation_number_outlined,
                      title: _isRoundTrip
                          ? 'Round Trip Ticket'
                          : 'Ticket $_fromStation → $_toStation',
                      subtitle: _detailedPriceBreakdown(),
                      price: _formatPrice(_ticketPrice),
                    ),
                    if (_isRoundTrip) ...[
                      // Round trip - show both journey seats
                      if (_outboundSeatSelections
                              .where((s) => s['seatName'].toString().isNotEmpty)
                              .isNotEmpty ||
                          _returnSeatSelections
                              .where((s) => s['seatName'].toString().isNotEmpty)
                              .isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildPriceRow(
                          icon: Icons.event_seat,
                          title: 'Seat Selection',
                          subtitle:
                              '${_outboundSeatSelections.where((s) => s['seatName'].toString().isNotEmpty).length} outbound + ${_returnSeatSelections.where((s) => s['seatName'].toString().isNotEmpty).length} return seat(s)',
                          price: _seatTotal > 0
                              ? _formatPrice(_seatTotal)
                              : 'Included',
                          priceColor:
                              _seatTotal == 0 ? const Color(0xFFC6A75E) : null,
                        ),
                      ],
                    ] else ...[
                      // One-way trip
                      if (_seatSelections
                          .where((s) => s['seatName'].toString().isNotEmpty)
                          .isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildPriceRow(
                          icon: Icons.event_seat,
                          title: 'Seat Selection',
                          subtitle:
                              '${_seatSelections.where((s) => s['seatName'].toString().isNotEmpty).length} seat(s) selected',
                          price: _seatTotal > 0
                              ? _formatPrice(_seatTotal)
                              : 'Included',
                          priceColor:
                              _seatTotal == 0 ? const Color(0xFFC6A75E) : null,
                        ),
                      ],
                    ],
                    if (_transferAdded) ...[
                      const SizedBox(height: 14),
                      _buildPriceRow(
                        icon: Icons.directions_car_rounded,
                        title: 'Station Transfer ($_transferVehicleType)',
                        subtitle: 'Pickup/drop-off — AC vehicle guaranteed',
                        price: _formatPrice(_transferFee),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: const Color(0xFFE0E0E0), // Light divider
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: greenTheme.withValues(alpha: 0.04),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666), // Gray text
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All taxes & fees included',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatPrice(_grandTotal),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: greenTheme,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    Color? priceColor,
    String? pricePrefix,
  }) {
    const greenTheme = Color(0xFFD4AF37);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: greenTheme.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: greenTheme),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              pricePrefix ?? price,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: priceColor ?? Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRulesAndPolicy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rules and Policy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildPolicies(),
      ],
    );
  }

  Widget _buildPolicies() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _showTermsError ? Colors.red.shade200 : Colors.grey.shade200,
          width: _showTermsError ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _showTermsError
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF5DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.policy_rounded,
                    color: Color(0xFFD4AF37),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Review Policies',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // Notice section (Pakistan Railways)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Notice',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNoticePoint(
                    'Carry valid CNIC/Passport matching your booking name at boarding'),
                const SizedBox(height: 8),
                _buildNoticePoint(
                    'Arrive at station 30 minutes before departure time'),
                const SizedBox(height: 8),
                _buildNoticePoint(
                    'No cancellation within 2 hours of departure'),
                const SizedBox(height: 8),
                _buildNoticePoint(
                    'Service fees (Rs. 100) and gateway fees are non-refundable'),
                const SizedBox(height: 8),
                _buildNoticePoint(
                    'Refunds processed in 7-14 working days to original payment method'),
                const SizedBox(height: 8),
                _buildNoticePoint(
                    'Check PNR status before traveling - Pakistan Railways may reschedule'),
                const SizedBox(height: 8),
                _buildNoticePoint(
                    'Tickets are non-transferable and valid only for booked train/date/class'),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // Payment section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment_rounded,
                        size: 18, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 8),
                    Text(
                      'Payment',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'All Debit/Credit cards powered by Visa, MasterCard are accepted.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB3B3B3),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // Policy links
          _buildPolicyRow(
            'Refund Policy',
            Icons.account_balance_wallet_rounded,
            () => _showRefundPolicyModal(),
          ),
          Divider(height: 1, color: Colors.grey.shade100, indent: 68),
          _buildPolicyRow(
            'Cancellation Policy',
            Icons.event_busy_rounded,
            () => _showCancellationPolicyModal(),
          ),
          Divider(height: 1, color: Colors.grey.shade100, indent: 68),
          _buildPolicyRow(
            'Fare Rules',
            Icons.receipt_long_rounded,
            () => _showFareRulesModal(),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // T&C checkbox
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _agreedToTerms = !_agreedToTerms;
                      _showTermsError = false;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _agreedToTerms
                                ? const Color(0xFFD4AF37)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _showTermsError
                                  ? Colors.red.shade400
                                  : _agreedToTerms
                                      ? const Color(0xFFD4AF37)
                                      : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: _agreedToTerms
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(text: 'I accept the '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showTermsAndConditionsPage(),
                                      child: const Text(
                                        'Terms & Conditions',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD4AF37),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () => _showPrivacyPolicyModal(),
                                      child: const Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD4AF37),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showTermsError) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 16, color: Colors.red.shade600),
                      const SizedBox(width: 5.6),
                      Text(
                        'Please accept Terms & Conditions to continue',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyRow(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFFB3B3B3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticePoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFB3B3B3),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFB3B3B3),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  void _showRefundPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  8,
                  8,
                  16,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Refund Policy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFB3B3B3)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        'Cancellation Before Departure',
                        'Cancellation must be made at least 2 hours before the scheduled departure time. Cancellations within 2 hours of departure are not permitted.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Refund Amount',
                        'Full ticket fare minus service charges will be refunded:\n• Reservation Fee (Rs. 0): No charge for online bookings\n• Service Fee (Rs. 100): Non-refundable\n• Payment Gateway Fee (Rs. 24-74): Non-refundable',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Processing Time',
                        'Refunds are processed within 7 working days to your original payment method (bank card account). If you do not receive the refund, please contact your payment company.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Refund Method',
                        'Refunds are automatically credited to the original payment method used during booking. No cash refunds are available.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'No-Show Policy',
                        'No refund will be provided if you fail to cancel your booking or do not board the train (no-show).',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancellationPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  8,
                  8,
                  16,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cancellation Policy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFB3B3B3)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        '2-Hour Deadline',
                        'Free cancellation is allowed up to 2 hours before the scheduled departure time. No cancellation is permitted within 2 hours of departure.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Cancellation Charges',
                        'When you cancel before the 2-hour deadline:\n• Ticket Fare: Fully refundable\n• Reservation Fee (Rs. 0): No charge for online bookings\n• Service Fee (Rs. 100): Non-refundable\n• Payment Gateway Fee (Rs. 24-74): Non-refundable',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'How to Cancel',
                        'Log in to your account, navigate to "My Bookings", select your train booking, and click "Cancel Booking". Ensure cancellation is completed at least 2 hours before departure.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Refund Processing',
                        'Approved refunds are processed within 7 working days to your original payment method. Contact your payment company if you do not receive the refund.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'No-Show Policy',
                        'If you do not cancel your booking or fail to board the train, no refund will be provided.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFareRulesModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  8,
                  8,
                  16,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Fare Rules',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFB3B3B3)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        'Fare Structure',
                        'Pakistan Railways ticket pricing includes:\n• Base Fare: Varies by class, route, and distance\n• Reservation Fee: Rs. 0 (included in base fare for online bookings)\n• Service/Convenience Fee: Rs. 100 per booking\n• Payment Gateway Fee: Rs. 24 (JazzCash/Easypaisa) or Rs. 74 (Credit/Debit Card)',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Passenger Concessions',
                        'Age-based discounts apply:\n• Adults (12+ years): 100% of base fare\n• Children (3-11 years): 50% discount on base fare\n• Infants (Under 3 years): Free (no seat allocated)',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Ticket Validity & Changes',
                        'Train tickets are valid only for the specific train, date, and class booked. Date changes and modifications are not permitted. Passengers must cancel and rebook if needed.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Name Policy',
                        'Tickets are issued in the passenger\'s name as provided during booking. Name changes or corrections are not allowed. Tickets are non-transferable.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Baggage Allowance',
                        'Passengers are allowed to carry personal baggage within reasonable limits. Excessive or commercial luggage may incur additional charges at the discretion of railway staff.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  8,
                  8,
                  16,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFB3B3B3)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        'Information We Collect',
                        'For train bookings, we collect:\n• Personal Data: Name, CNIC/Passport number, phone number, email, date of birth\n• Payment Data: Card details (encrypted), transaction history\n• Booking Data: Travel dates, routes, passenger details, seat preferences\n• Device Data: IP address, browser type, device information',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'How We Use Your Data',
                        'Your information is used to:\n• Process ticket bookings and payments\n• Send booking confirmations and travel updates via SMS/Email\n• Verify passenger identity at boarding (CNIC verification)\n• Comply with Pakistan Railways regulations\n• Improve our services and user experience\n• Marketing communications (only with your consent)',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Data Protection & Security',
                        'We protect your data through:\n• SSL/TLS encryption for all data transmission\n• PCI-DSS compliant payment gateways\n• Secure servers located in Pakistan\n• No sharing with third parties except payment processors (JazzCash, Easypaisa, banks)\n• Data retention as per Pakistan Railways and SBP regulations',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Your Rights',
                        'Under Pakistan data protection laws, you have the right to:\n• Access your personal data\n• Request correction or deletion of your data\n• Opt-out of marketing communications\n• File complaints with relevant authorities\n• Withdraw consent for data processing',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Third-Party Services',
                        'We may share your information with:\n• Payment Gateways: JazzCash, Easypaisa, bank processors (for payment processing only)\n• SMS/Email Providers: For sending booking confirmations and notifications\n• Analytics Services: For improving user experience (anonymized data only)\n• Pakistan Railways: For ticket verification and compliance',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsAndConditionsPage() => _showPolicySheet('Terms & Conditions', [
        const _PolicyItem('1. Acceptance of Terms',
            'By booking train tickets through Travello AI, you accept and agree to be bound by these Terms and Conditions and comply with Pakistan Railways regulations. If you do not agree, please do not proceed with booking.'),
        const _PolicyItem('2. Ticket Booking & Validity',
            'All bookings are subject to availability and Pakistan Railways confirmation. Tickets are non-transferable, valid only for the specific train/date/class booked, and require valid CNIC/Passport matching booking details at boarding.'),
        const _PolicyItem('3. Payment Terms',
            'Payment must be made in full at booking time through secure gateways. Payment includes base fare, service fee (Rs. 100, non-refundable), and gateway fee (Rs. 24-74, non-refundable). Booking confirmation sent via email/SMS.'),
        const _PolicyItem('4. Passenger Concessions',
            'Age-based fare concessions apply: Adults (12+ years) 100% of base fare, Children (3-11 years) 50% discount, Infants (under 3 years) free with no seat allocated.'),
        const _PolicyItem('5. Cancellation Policy',
            'Free cancellation allowed up to 2 hours before scheduled departure. No cancellation permitted within 2 hours of departure. Refunds processed in 7-14 working days to original payment method.'),
        const _PolicyItem('6. Passenger Responsibilities',
            'You must provide accurate information, carry valid photo ID matching booking, arrive at station 30 minutes before departure, and follow Pakistan Railways safety rules and regulations.'),
        const _PolicyItem('7. Liability & Force Majeure',
            'Travello AI acts as a booking intermediary. We are not liable for train delays, cancellations, loss of belongings, or Acts of God. Liability is limited to refund of ticket fare as per cancellation policy.'),
        const _PolicyItem('8. Privacy & Data Protection',
            'Your personal information is collected, stored, and processed in accordance with our Privacy Policy and Pakistan data protection laws. Data is used for ticket booking, identity verification, and compliance with Pakistan Railways regulations.'),
      ]);

  void _showPolicySheet(String title, List<_PolicyItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 8, 16),
              child: Row(children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5)),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFFB3B3B3)),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items
                        .map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _buildPolicySection(item.title, item.body),
                            ))
                        .toList()),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFB3B3B3),
            height: 1.6,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Light card
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: DSButton(
          label: _isCreatingBooking ? 'CREATING BOOKING...' : 'CHECKOUT',
          trailingIcon: Icons.arrow_forward_rounded,
          onTap: _proceedToCheckout,
          disabled: _isCreatingBooking,
          height: R.rh(context, 52),
          color: const Color(0xFFD4AF37),
        ),
      ),
    );
  }
}

class _PolicyItem {
  final String title;
  final String body;
  const _PolicyItem(this.title, this.body);
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
