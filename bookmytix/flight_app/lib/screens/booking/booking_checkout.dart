import 'dart:math' as math;
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  PROFESSIONAL CHECKOUT SCREEN - Matches Bookme/Expedia Design
// ═════════════════════════════════════════════════════════════════════════════

class BookingCheckout extends StatefulWidget {
  const BookingCheckout({super.key});

  @override
  State<BookingCheckout> createState() => _BookingCheckoutState();
}

class _BookingCheckoutState extends State<BookingCheckout> {
  late FlightResult _flight;
  late Map<String, dynamic> _searchParams;
  late Airport _fromAirport;
  late Airport _toAirport;
  late DateTime _departureDate;
  late int _adults;
  late int _children;
  late int _infants;
  late List<Map<String, dynamic>> _passengers;
  late List<Map<String, dynamic>> _baggageData;
  late double _baggageExtraTotal;
  late String _contactEmail;
  late String _contactPhone;

  // Emergency Contact
  late String _emergencyName;
  late String _emergencyEmail;
  late String _emergencyPhone;
  late String _emergencyRelation;

  // Seat selection data
  List<Map<String, dynamic>> _seatSelections = [];
  List<Map<String, dynamic>> _outboundSeatSelections = [];
  List<Map<String, dynamic>> _returnSeatSelections = [];
  double _seatTotal = 0.0;

  // Ground Transfer
  bool _transferAdded = false;
  String _transferVehicleType = 'Sedan';
  double _transferFee = 0.0;

  // Round trip support
  bool _isRoundTrip = false;
  FlightResult? _outboundFlight;
  FlightResult? _returnFlight;
  DateTime? _returnDate;

  bool _agreeToTerms = false;
  bool _showTermsError = false;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map<String, dynamic>?) ?? {};

    // Round trip detection
    _isRoundTrip = args['isRoundTrip'] as bool? ?? false;
    _outboundFlight = args['outboundFlight'] as FlightResult?;
    _returnFlight = args['returnFlight'] as FlightResult?;

    _flight = (_isRoundTrip ? _outboundFlight : args['flight']) as FlightResult;
    _searchParams = (args['searchParams'] as Map<String, dynamic>?) ?? {};
    _fromAirport = _searchParams['fromAirport'] as Airport? ??
        Airport(id: '0', code: 'DEP', name: 'Departure', location: '-');
    _toAirport = _searchParams['toAirport'] as Airport? ??
        Airport(id: '0', code: 'ARR', name: 'Arrival', location: '-');
    _departureDate =
        (_searchParams['departureDate'] as DateTime?) ?? DateTime.now();
    _returnDate = _searchParams['returnDate'] as DateTime?;
    _adults = (_searchParams['adults'] as int?) ?? 1;
    _children = (_searchParams['children'] as int?) ?? 0;
    _infants = (_searchParams['infants'] as int?) ?? 0;

    final raw = (args['passengers'] as List<dynamic>?) ?? [];
    _passengers = raw.map((p) => Map<String, dynamic>.from(p as Map)).toList();

    final bagRaw = (args['baggageData'] as List<dynamic>?) ?? [];
    _baggageData =
        bagRaw.map((b) => Map<String, dynamic>.from(b as Map)).toList();
    _baggageExtraTotal = (args['baggageExtraTotal'] as double?) ?? 0.0;

    // Read seat selection data
    if (_isRoundTrip) {
      final outboundSeats =
          (args['outboundSeatSelections'] as List<dynamic>?) ?? [];
      _outboundSeatSelections = outboundSeats
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      final returnSeats =
          (args['returnSeatSelections'] as List<dynamic>?) ?? [];
      _returnSeatSelections =
          returnSeats.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    } else {
      final seats = (args['seatSelections'] as List<dynamic>?) ?? [];
      _seatSelections =
          seats.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    }
    _seatTotal = (args['seatTotal'] as double?) ?? 0.0;

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

    // Read contact details passed directly from BookingPassengers
    _contactEmail = (args['contactEmail'] as String?) ??
        (args['contactInfo'] as Map<String, dynamic>?)?['email'] as String? ??
        '';
    _contactPhone = (args['contactPhone'] as String?) ??
        (args['contactInfo'] as Map<String, dynamic>?)?['phone'] as String? ??
        '';

    // Read emergency contact details
    _emergencyName = (args['emergencyName'] as String?) ?? '';
    _emergencyEmail = (args['emergencyEmail'] as String?) ?? '';
    _emergencyPhone = (args['emergencyPhone'] as String?) ?? '';
    _emergencyRelation = (args['emergencyRelation'] as String?) ?? '';
  }

  String _formatPrice(double amount) {
    final n = amount.toStringAsFixed(0);
    // insert commas: 25000 → 25,000
    final buf = StringBuffer();
    int start = n.length % 3;
    if (start > 0) buf.write(n.substring(0, start));
    for (int i = start; i < n.length; i += 3) {
      if (buf.isNotEmpty) buf.write(',');
      buf.write(n.substring(i, i + 3));
    }
    return 'PKR ${buf.toString()}';
  }

  String _passengerBreakdownText() {
    final parts = <String>[];
    if (_adults > 0) parts.add('$_adults Adult${_adults > 1 ? 's' : ''}');
    if (_children > 0) {
      parts.add('$_children Child${_children > 1 ? 'ren' : ''}');
    }
    if (_infants > 0) parts.add('$_infants Infant${_infants > 1 ? 's' : ''}');
    return parts.isEmpty
        ? '${_passengers.length} Traveler(s)'
        : parts.join(' · ');
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
        return dob; // Return as-is if parsing fails
      }
    }
    return '14 January 1990';
  }

  // Get seat information for a passenger by index
  String _getPassengerSeat(int index, {bool isOutbound = true}) {
    if (_isRoundTrip) {
      final selections =
          isOutbound ? _outboundSeatSelections : _returnSeatSelections;
      if (index < selections.length) {
        final seatName = selections[index]['seatName'] as String? ?? '';
        return seatName.isNotEmpty ? seatName : 'Not selected';
      }
    } else {
      if (index < _seatSelections.length) {
        final seatName = _seatSelections[index]['seatName'] as String? ?? '';
        return seatName.isNotEmpty ? seatName : 'Not selected';
      }
    }
    return 'Not selected';
  }

  bool _hasSeatSelections() {
    if (_isRoundTrip) {
      return _outboundSeatSelections
              .any((s) => (s['seatName'] as String? ?? '').isNotEmpty) ||
          _returnSeatSelections
              .any((s) => (s['seatName'] as String? ?? '').isNotEmpty);
    }
    return _seatSelections
        .any((s) => (s['seatName'] as String? ?? '').isNotEmpty);
  }

  double get _ticketPrice {
    if (_isRoundTrip && _outboundFlight != null && _returnFlight != null) {
      return (_outboundFlight!.price + _returnFlight!.price) *
          _passengers.length;
    }
    return _flight.price * _passengers.length;
  }

  double get _discountPercent {
    if (_flight.badge.contains('%')) {
      final match = RegExp(r'(\d+)%').firstMatch(_flight.badge);
      if (match != null) return double.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  int get _passengerCount => _passengers.length;
  double get _taxFED => _ticketPrice * 0.16;
  double get _taxAirportFee => 200.0 * _passengerCount;
  double get _taxSecurityFee => 150.0 * _passengerCount;
  double get _checkoutServiceFee => 500.0;

  double get _subtotal =>
      _ticketPrice + _baggageExtraTotal + _seatTotal + _transferFee;
  double get _discount => _ticketPrice * (_discountPercent / 100);
  double get _grandTotal =>
      _subtotal +
      _taxFED +
      _taxAirportFee +
      _taxSecurityFee +
      _checkoutServiceFee -
      _discount;

  void _proceedToCheckout() {
    if (!_agreeToTerms) {
      setState(() => _showTermsError = true);
      Get.snackbar(
        'Terms Required',
        'Please accept Terms & Conditions and Privacy Policy to continue',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    Get.toNamed(AppLink.payment, arguments: {
      'flight': _flight,
      'searchParams': _searchParams,
      'passengers': _passengers,
      'baggageData': _baggageData,
      'totalAmount': _grandTotal,
      'discount': _discount,
      'isRoundTrip': _isRoundTrip,
      'outboundFlight': _outboundFlight,
      'returnFlight': _returnFlight,
      'returnDate': _returnDate,
      'contactEmail': _contactEmail,
      'contactPhone': _contactPhone,
      'emergencyName': _emergencyName,
      'emergencyEmail': _emergencyEmail,
      'emergencyPhone': _emergencyPhone,
      'emergencyRelation': _emergencyRelation,
      'seatSelections': _seatSelections,
      'outboundSeatSelections': _outboundSeatSelections,
      'returnSeatSelections': _returnSeatSelections,
      'seatTotal': _seatTotal,
      'transferAdded': _transferAdded,
      'transferVehicleType': _transferVehicleType,
      'transferFee': _transferFee,
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
                  _buildFlightDetails(),
                  const SizedBox(height: 24),

                  // Return flight for round trips
                  if (_isRoundTrip && _returnFlight != null) ...[
                    _buildReturnFlightDetails(),
                    const SizedBox(height: 24),
                  ],

                  _buildPassengerDetails(),
                  const SizedBox(height: 24),
                  _buildAddons(),
                  const SizedBox(height: 24),
                  _buildContactDetails(),
                  const SizedBox(height: 24),
                  _buildEmergencyContactDetails(),
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

  // ═══════════════════════════════════════════════════════════════════════
  //  APP BAR
  // ═══════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: TravelloTheme.primaryMain,
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

  // ═══════════════════════════════════════════════════════════════════════
  //  STEP PROGRESS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildStepProgress() {
    const steps = ['PASSENGERS', 'FACILITIES', 'CHECKOUT', 'PAYMENT', 'DONE'];
    const goldColor = Color(0xFFD4AF37);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(9, (i) {
          if (i.isOdd) {
            // Connecting line
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
          // Circle
          final index = i ~/ 2;
          final isActive = index == 2; // CHECKOUT
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

  // ═══════════════════════════════════════════════════════════════════════
  //  INFO BANNER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: const Border(left: BorderSide(color: Colors.blue, width: 4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please remember that it is your responsibility to have in your possession all the necessary travel documents.',
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

  // ═══════════════════════════════════════════════════════════════════════
  //  FLIGHT DETAILS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFlightDetails() {
    final depDate = DateFormat('dd MMM').format(_departureDate);
    final arrDate = DateFormat('dd MMM')
        .format(_departureDate.add(const Duration(hours: 2)));

    const primary = TravelloTheme.primaryMain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Outbound label for round trips ──
        if (_isRoundTrip) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flight_takeoff_rounded,
                    size: 17, color: Colors.blue.shade700),
                const SizedBox(width: 7),
                Text(
                  'Outbound Flight',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.blue.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Departure Section ──
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
                'Non-Stop - Duration: ${_flight.duration}',
                style: TravelloTheme.durationBadge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Main Flight Card ──
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFF5F5F5), // Light card
            border:
                Border.all(color: primary.withValues(alpha: 0.18), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.10),
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
              // ── Route title ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      '${_fromAirport.location}(${_fromAirport.code}) - ${_toAirport.location}(${_toAirport.code})',
                      style: TravelloTheme.cardHeading,
                    ),
                    const Spacer(),
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: Color(0xFF666666)),
                    const SizedBox(width: 5),
                    Text(
                      _flight.duration,
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

              // ── Top section: Times + Airport codes ──
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
                                _flight.departureTime,
                                style: const TextStyle(
                                    fontSize: 34,
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
                                _flight.arrivalTime,
                                style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    letterSpacing: -1.8,
                                    height: 1.0),
                                textAlign: TextAlign.end,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                arrDate,
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

                    // Airport codes + Timeline
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // KHI badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: Text(
                            _fromAirport.code,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: primary,
                                letterSpacing: 1.6),
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
                                      Border.all(color: primary, width: 2.3),
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
                              // Plane icon (facing destination)
                              Transform.rotate(
                                angle: math.pi / 4,
                                child: const Icon(Icons.flight_rounded,
                                    size: 30, color: primary),
                              ),
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
                                    shape: BoxShape.circle, color: primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // LHE badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: Text(
                            _toAirport.code,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: primary,
                                letterSpacing: 1.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Airport names
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _fromAirport.name,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFB3B3B3),
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _toAirport.name,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFB3B3B3),
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFE0E0E0)),
              const SizedBox(height: 14),

              // ── Airline Footer Section ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  children: [
                    // Airline icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5), // Light card
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: primary.withValues(alpha: 0.20), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child:
                          const Icon(Icons.flight_rounded, color: primary, size: 21),
                    ),
                    const SizedBox(width: 13),
                    // Airline info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _flight.airlineName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_flight.cabinClass} ${_flight.airlineCode}',
                            style: const TextStyle(
                                fontSize: 11.5, color: Color(0xFF666666)),
                          ),
                        ],
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

  // ═══════════════════════════════════════════════════════════════════════
  //  RETURN FLIGHT DETAILS (FOR ROUND TRIPS)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildReturnFlightDetails() {
    if (_returnFlight == null || _returnDate == null) {
      return const SizedBox.shrink();
    }

    final depDate = DateFormat('dd MMM').format(_returnDate!);
    final arrDate =
        DateFormat('dd MMM').format(_returnDate!.add(const Duration(hours: 2)));

    const primary = TravelloTheme.primaryMain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Return Section ──
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
                'Non-Stop - Duration: ${_returnFlight!.duration}',
                style: TravelloTheme.durationBadge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Main Flight Card ──
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFF5F5F5), // Light card
            border:
                Border.all(color: primary.withValues(alpha: 0.18), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.10),
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
              // ── Route title ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      '${_toAirport.location}(${_toAirport.code}) - ${_fromAirport.location}(${_fromAirport.code})',
                      style: TravelloTheme.cardHeading,
                    ),
                    const Spacer(),
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: Color(0xFF666666)),
                    const SizedBox(width: 5),
                    Text(
                      _returnFlight!.duration,
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

              // ── Top section: Times + Airport codes ──
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
                                _returnFlight!.departureTime,
                                style: const TextStyle(
                                    fontSize: 34,
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
                                _returnFlight!.arrivalTime,
                                style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    letterSpacing: -1.8,
                                    height: 1.0),
                                textAlign: TextAlign.end,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                arrDate,
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

                    // Airport codes + Timeline (reversed for return)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // LHE badge (return starts from destination)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: Text(
                            _toAirport.code,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: primary,
                                letterSpacing: 1.6),
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
                                      Border.all(color: primary, width: 2.3),
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
                              // Plane icon (facing destination)
                              Transform.rotate(
                                angle: math.pi / 4,
                                child: const Icon(Icons.flight_rounded,
                                    size: 30, color: primary),
                              ),
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
                                    shape: BoxShape.circle, color: primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // KHI badge (return ends at origin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.25),
                                width: 1),
                          ),
                          child: Text(
                            _fromAirport.code,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: primary,
                                letterSpacing: 1.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Airport names (reversed)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _toAirport.name,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFB3B3B3),
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fromAirport.name,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFB3B3B3),
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFE0E0E0)),
              const SizedBox(height: 14),

              // ── Airline Footer Section ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  children: [
                    // Airline icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5), // Light card
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: primary.withValues(alpha: 0.20), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child:
                          const Icon(Icons.flight_rounded, color: primary, size: 21),
                    ),
                    const SizedBox(width: 13),
                    // Airline info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _returnFlight!.airlineName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_returnFlight!.cabinClass} ${_returnFlight!.airlineCode}',
                            style: const TextStyle(
                                fontSize: 11.5, color: Color(0xFF666666)),
                          ),
                        ],
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

  // ═══════════════════════════════════════════════════════════════════════
  //  PASSENGER DETAILS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPassengerDetails() {
    const primary = TravelloTheme.primaryMain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Passenger Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              '${_passengers.length} Passenger${_passengers.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(_passengers.length, (index) {
          final p = _passengers[index];
          final pType = index < _adults
              ? 'Adult'
              : index < _adults + _children
                  ? 'Child'
                  : 'Infant';
          final initials =
              '${(p['firstName'] as String? ?? 'P').isNotEmpty ? (p['firstName'] as String)[0] : 'P'}'
              '${(p['lastName'] as String? ?? '').isNotEmpty ? (p['lastName'] as String)[0] : ''}';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5), // Light card
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFE0E0E0)), // Light divider
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Passenger header ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.05),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, primary.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initials.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['firstName']} ${p['lastName']}${p['salutation'] != null && p['salutation'].toString().isNotEmpty ? ' (${p['salutation']})' : ''}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Passenger ${index + 1} · $pType',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF666666)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pType == 'Adult'
                              ? primary.withOpacity(0.1)
                              : pType == 'Child'
                                  ? Colors.orange.withOpacity(0.12)
                                  : Colors.purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pType,
                          style: TextStyle(
                              fontSize: 11,
                              color: pType == 'Adult'
                                  ? primary
                                  : pType == 'Child'
                                      ? Colors.orange.shade700
                                      : Colors.purple.shade600,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Passenger details grid ──
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildDetailChip(
                              Icons.person_outline_rounded,
                              'Full Name',
                              '${p['firstName']} ${p['lastName']}${p['salutation'] != null && p['salutation'].toString().isNotEmpty ? ' (${p['salutation']})' : ''}'),
                          const SizedBox(width: 12),
                          _buildDetailChip(Icons.cake_outlined, 'Date of Birth',
                              _formatDateOfBirth(p['dateOfBirth'])),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildDetailChip(Icons.flag_outlined, 'Nationality',
                              p['nationality'] ?? 'Pakistan'),
                          const SizedBox(width: 12),
                          // Show document based on type
                          if (p['documentType'] == 'CNIC' &&
                              p['nationalId'] != null &&
                              p['nationalId'].toString().isNotEmpty)
                            _buildDetailChip(Icons.credit_card_outlined, 'CNIC',
                                p['nationalId'].toString())
                          else if (p['documentType'] == 'B-Form' &&
                              p['bForm'] != null &&
                              p['bForm'].toString().isNotEmpty)
                            _buildDetailChip(Icons.credit_card_outlined,
                                'B-Form', p['bForm'].toString())
                          else if (p['passportNumber'] != null &&
                              p['passportNumber'].toString().isNotEmpty)
                            _buildDetailChip(Icons.article_outlined, 'Passport',
                                p['passportNumber'].toString())
                          else
                            _buildDetailChip(Icons.badge_outlined, 'Document',
                                'Not provided'),
                        ],
                      ),
                      // Show seat information if seats were selected
                      if (_hasSeatSelections()) ...[
                        const SizedBox(height: 10),
                        if (_isRoundTrip) ...[
                          // Round trip - show both outbound and return seats
                          Row(
                            children: [
                              _buildDetailChip(
                                Icons.airline_seat_recline_normal,
                                'Outbound Seat',
                                _getPassengerSeat(index, isOutbound: true),
                              ),
                              const SizedBox(width: 12),
                              _buildDetailChip(
                                Icons.airline_seat_recline_normal,
                                'Return Seat',
                                _getPassengerSeat(index, isOutbound: false),
                              ),
                            ],
                          ),
                        ] else ...[
                          // One-way trip - show single seat
                          Row(
                            children: [
                              _buildDetailChip(
                                Icons.airline_seat_recline_normal,
                                'Seat Number',
                                _getPassengerSeat(index),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Container()), // Spacer
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5), // Light surface
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF666666)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF666666), // Gray text
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ADDONS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAddons() {
    // Only show if there are seat selections
    if (!_hasSeatSelections()) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seat Selections',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Single Trip or Round Trip Outbound
        if (_isRoundTrip) ...[
          // Outbound Flight Seats
          _buildSeatSection(
            '${_fromAirport.code} to ${_toAirport.code}',
            isOutbound: true,
          ),
          const SizedBox(height: 12),
          // Return Flight Seats
          _buildSeatSection(
            '${_toAirport.code} to ${_fromAirport.code}',
            isOutbound: false,
          ),
        ] else
          // Single Trip Seats
          _buildSeatSection(
            '${_fromAirport.code} to ${_toAirport.code}',
            isOutbound: true,
          ),
      ],
    );
  }

  Widget _buildSeatSection(String route, {required bool isOutbound}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.flight_takeoff,
                    size: 16, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Text(
                  route,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Passenger Seats
          ...List.generate(_passengers.length, (index) {
            final p = _passengers[index];
            final seat = _getPassengerSeat(index, isOutbound: isOutbound);

            // Only show if seat is selected
            if (seat == 'Not selected') {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 18, color: Color(0xFFB3B3B3)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${p['firstName']} ${p['lastName']}${p['salutation'] != null && p['salutation'].toString().isNotEmpty ? ' (${p['salutation']})' : ''}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Seat: ',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF666666)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          seat,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CONTACT DETAILS
  // ═══════════════════════════════════════════════════════════════════════

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
                                _contactEmail.isEmpty ? '—' : _contactEmail,
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
                                _contactPhone.isEmpty ? '—' : _contactPhone,
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
                  color: Colors.blue.shade50,
                  border: const Border(
                      left: BorderSide(color: Colors.blue, width: 4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.blue, size: 18),
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
                                  ? 'your email'
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

  // ═══════════════════════════════════════════════════════════════════════
  //  EMERGENCY CONTACT DETAILS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEmergencyContactDetails() {
    // Only show if emergency contact was provided
    if (_emergencyName.isEmpty && _emergencyPhone.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emergency Contact',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(8),
            color: Colors.red.shade50.withValues(alpha: 0.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency_outlined,
                      size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _emergencyName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_emergencyRelation.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _emergencyRelation,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_emergencyEmail.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFB3B3B3)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined,
                                  size: 16, color: Color(0xFFB3B3B3)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _emergencyEmail,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_emergencyEmail.isNotEmpty) const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number',
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
                                _emergencyPhone,
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
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  PRICE DETAIL
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildPriceDetail() {
    const primary = TravelloTheme.primaryMain;

    // Build baggage subtitle from actual baggageData
    String baggageSubtitle = '';
    if (_baggageData.isNotEmpty) {
      final totalKg = _baggageData.fold<double>(
          0, (s, b) => s + ((b['totalKg'] as double?) ?? 0));
      final freeKg = (_baggageData.first['freeKg'] as double?) ?? 0;
      if (_baggageExtraTotal > 0) {
        final extraKg = _baggageData.fold<double>(
            0, (s, b) => s + ((b['overweightKg'] as double?) ?? 0));
        final overweightPax = _baggageData
            .where((b) => ((b['overweightKg'] as double?) ?? 0) > 0)
            .length;
        baggageSubtitle =
            '${extraKg.toStringAsFixed(0)} kg extra · $overweightPax pax';
      } else {
        baggageSubtitle =
            '${totalKg.toStringAsFixed(0)} kg · Free allowance ${freeKg.toStringAsFixed(0)} kg';
      }
    }

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
                color: Colors.black.withOpacity(0.04),
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
                      icon: Icons.airplane_ticket_outlined,
                      title: _isRoundTrip
                          ? 'Round Trip Ticket'
                          : 'Ticket ${_fromAirport.location} → ${_toAirport.location}',
                      subtitle: _isRoundTrip
                          ? '${_fromAirport.location} ⇄ ${_toAirport.location} · ${_passengerBreakdownText()}'
                          : '${_formatPrice(_flight.price)} × ${_passengers.length} pax  (${_passengerBreakdownText()})',
                      price: _formatPrice(_ticketPrice),
                    ),
                    const SizedBox(height: 14),
                    _buildPriceRow(
                      icon: Icons.luggage_outlined,
                      title: 'Additional Baggage',
                      subtitle: baggageSubtitle.isNotEmpty
                          ? baggageSubtitle
                          : 'No extra baggage selected',
                      price: _formatPrice(_baggageExtraTotal),
                      priceColor: _baggageExtraTotal > 0
                          ? null
                          : const Color(0xFFD4AF37),
                      pricePrefix: _baggageExtraTotal == 0 ? 'Free' : null,
                    ),
                    if (_seatTotal > 0) ...[
                      const SizedBox(height: 14),
                      _buildPriceRow(
                        icon: Icons.airline_seat_recline_normal,
                        title: 'Seat Selection',
                        subtitle: _isRoundTrip
                            ? 'Outbound + Return seat reservations'
                            : '${_seatSelections.where((s) => (s['seatName'] as String? ?? '').isNotEmpty).length} seat(s) reserved',
                        price: _formatPrice(_seatTotal),
                      ),
                    ],
                    if (_transferAdded) ...[
                      const SizedBox(height: 14),
                      _buildPriceRow(
                        icon: Icons.directions_car_rounded,
                        title: 'Airport Transfer ($_transferVehicleType)',
                        subtitle: 'Pickup/drop-off — AC vehicle guaranteed',
                        price: _formatPrice(_transferFee),
                      ),
                    ],
                    // ── Tax breakdown ──
                    const SizedBox(height: 14),
                    _buildPriceRow(
                      icon: Icons.account_balance_outlined,
                      title: 'FED (16%)',
                      subtitle: 'Federal Excise Duty on base fare',
                      price: _formatPrice(_taxFED),
                    ),
                    const SizedBox(height: 14),
                    _buildPriceRow(
                      icon: Icons.local_airport_outlined,
                      title: 'Airport Development Fee',
                      subtitle: 'PKR 200 × $_passengerCount pax',
                      price: _formatPrice(_taxAirportFee),
                    ),
                    const SizedBox(height: 14),
                    _buildPriceRow(
                      icon: Icons.security_outlined,
                      title: 'Aviation Security Fee',
                      subtitle: 'PKR 150 × $_passengerCount pax',
                      price: _formatPrice(_taxSecurityFee),
                    ),
                    const SizedBox(height: 14),
                    _buildPriceRow(
                      icon: Icons.miscellaneous_services_outlined,
                      title: 'Service Fee',
                      subtitle: 'Platform service charge',
                      price: _formatPrice(_checkoutServiceFee),
                    ),
                    if (_discount > 0) ...[
                      const SizedBox(height: 14),
                      _buildPriceRow(
                        icon: Icons.local_offer_outlined,
                        title: 'Discount',
                        subtitle:
                            '${_discountPercent.toStringAsFixed(0)}% off on ticket',
                        price: '-${_formatPrice(_discount)}',
                        priceColor: Colors.green.shade600,
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
              // ── Total footer ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.04),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Column(
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
                          'Incl. FED, airport & service fees',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_discount > 0)
                          Text(
                            _formatPrice(_subtotal),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          _formatPrice(_grandTotal),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
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
    const primary = TravelloTheme.primaryMain;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF666666))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          pricePrefix ?? price,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: priceColor ?? Colors.black87),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  RULES AND POLICY
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildRulesAndPolicy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rules and Policy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  _showTermsError ? Colors.red.shade200 : Colors.grey.shade200,
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

              // Policy Links
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

              // Terms & Conditions Checkbox
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
                          _agreeToTerms = !_agreeToTerms;
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
                                color: _agreeToTerms
                                    ? const Color(0xFFD4AF37)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _showTermsError
                                      ? Colors.red.shade400
                                      : _agreeToTerms
                                          ? const Color(0xFFD4AF37)
                                          : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: _agreeToTerms
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    )
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
                                      const TextSpan(
                                        text: 'I accept the ',
                                      ),
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
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' and ',
                                      ),
                                      WidgetSpan(
                                        child: GestureDetector(
                                          onTap: () =>
                                              _showPrivacyPolicyModal(),
                                          child: const Text(
                                            'Privacy Policy',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFD4AF37),
                                              decoration:
                                                  TextDecoration.underline,
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
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: Colors.red.shade600,
                          ),
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
        ),
      ],
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
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFFB3B3B3),
                ),
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
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
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
                        'Refund Eligibility',
                        'Refunds are available for cancellations made according to the airline\'s cancellation policy. Refund processing time varies by airline and payment method.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Processing Time',
                        'Refunds typically take 7-14 business days to process. Credit card refunds may take an additional 5-7 business days to reflect in your account.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Non-Refundable Tickets',
                        'Some promotional or discounted fares are non-refundable. Please check your fare conditions before booking.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Cancellation Fees',
                        'Airlines may charge cancellation fees. These fees vary by airline, route, and fare class and will be deducted from your refund amount.',
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
                        'Free Cancellation',
                        'Cancellations made within 24 hours of booking may be eligible for free cancellation, subject to airline policy and fare rules.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Cancellation Charges',
                        'Cancellation fees vary based on time before departure:\n• More than 15 days: Minimal fees\n• 7-15 days: Moderate fees\n• Less than 7 days: Higher fees\n• No-show: Maximum fees',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'How to Cancel',
                        'Log in to your account, go to "My Bookings", select your booking, and click "Cancel Booking". Follow the prompts to complete cancellation.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Non-Cancellable Bookings',
                        'Certain promotional or special fares may be non-cancellable. Please review your booking details carefully.',
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
                        'Fare Components',
                        'The ticket price includes base fare, taxes, fuel surcharge, and airport fees. Additional charges for baggage and seat selection may apply.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Date Changes',
                        'Changes to travel dates may incur change fees plus fare difference. Economy fares typically have higher change fees than premium fares.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Name Changes',
                        'Most airlines do not permit name changes. Spelling corrections may be allowed with proper documentation and applicable fees.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Baggage Allowance',
                        'Baggage allowance varies by airline and fare class. Check your booking confirmation for specific allowance. Excess baggage fees apply.',
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
                        'Data Collection',
                        'We collect personal information necessary for booking and providing travel services, including name, contact details, and payment information.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Data Usage',
                        'Your information is used to process bookings, send confirmations, provide customer support, and improve our services.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Data Security',
                        'We implement industry-standard security measures to protect your personal information from unauthorized access, disclosure, or destruction.',
                      ),
                      const SizedBox(height: 20),
                      _buildPolicySection(
                        'Third-Party Sharing',
                        'Information may be shared with airlines, payment processors, and service providers necessary to complete your booking.',
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

  void _showTermsAndConditionsPage() {
    Get.to(
      () => Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black87, size: 20),
            onPressed: () => Get.back(),
          ),
          title: const Text(
            'Terms & Conditions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFullPageSection(
                '1. Acceptance of Terms',
                'By accessing and using Travello AI, you accept and agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use our services.',
              ),
              const SizedBox(height: 24),
              _buildFullPageSection(
                '2. Booking & Payment',
                'All bookings are subject to availability and confirmation. Payment must be made in full at the time of booking. We accept major credit cards, debit cards, and mobile wallet payments.',
              ),
              const SizedBox(height: 24),
              _buildFullPageSection(
                '3. Cancellation & Refunds',
                'Cancellations are subject to airline policies and fare rules. Refunds, if applicable, will be processed within 7-14 business days. Cancellation fees may apply.',
              ),
              const SizedBox(height: 24),
              _buildFullPageSection(
                '4. User Responsibilities',
                'You are responsible for providing accurate information, maintaining account security, and ensuring valid travel documents. You must arrive at the airport with sufficient time before departure.',
              ),
              const SizedBox(height: 24),
              _buildFullPageSection(
                '5. Liability',
                'Travello AI acts as an intermediary between customers and airlines. We are not liable for flight delays, cancellations, or changes made by airlines.',
              ),
              const SizedBox(height: 24),
              _buildFullPageSection(
                '6. Privacy',
                'We respect your privacy and handle your personal information in accordance with our Privacy Policy. Your data is used solely for providing and improving our services.',
              ),
              const SizedBox(height: 24),
              _buildFullPageSection(
                '7. Changes to Terms',
                'We reserve the right to modify these terms at any time. Continued use of our services constitutes acceptance of updated terms.',
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Last updated: March 2026',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
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
      ),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 300),
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

  Widget _buildFullPageSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB3B3B3),
              height: 1.7,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CHECKOUT BUTTON
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCheckoutButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Light card
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: DSButton(
          label: 'CHECKOUT',
          trailingIcon: Icons.arrow_forward_rounded,
          onTap: _proceedToCheckout,
          disabled: !_agreeToTerms,
          height: 52,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dashed line painter for flight timeline
// ─────────────────────────────────────────────────────────────────────────────

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
