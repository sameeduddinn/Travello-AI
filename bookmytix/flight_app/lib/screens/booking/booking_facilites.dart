import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flight_app/widgets/booking/flight_seat_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Cabin class baggage policy
//  Economy  → carry-on 7 kg  + 1 checked bag 20 kg  (industry standard)
//  Business → carry-on 10 kg + 2 checked bags 30 kg
//  First    → carry-on 12 kg + 2 checked bags 40 kg
// ─────────────────────────────────────────────────────────────────────────────
final Map<String, Map<String, dynamic>> _cabinPolicy = {
  'Economy': {
    'carryOn': '7 kg',
    'checked': '20 kg',
    'checkedKg': 20,
    'checkedBags': 1,
    'color': Colors.blue,
  },
  'Premium Economy': {
    'carryOn': '8 kg',
    'checked': '25 kg',
    'checkedKg': 25,
    'checkedBags': 1,
    'color': Colors.orange,
  },
  'Business': {
    'carryOn': '10 kg',
    'checked': '30 kg',
    'checkedKg': 30,
    'checkedBags': 2,
    'color': Colors.purple,
  },
  'First': {
    'carryOn': '12 kg',
    'checked': '40 kg',
    'checkedKg': 40,
    'checkedBags': 2,
    'color': Colors.amber,
  },
};

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────
class BookingFacilites extends StatefulWidget {
  const BookingFacilites({super.key});

  @override
  State<BookingFacilites> createState() => _BookingFacilitesState();
}

class _BookingFacilitesState extends State<BookingFacilites> {
  // ── args ──
  late FlightResult _flight;
  late List<Map<String, dynamic>> _passengers;
  Map<String, dynamic> _rawArgs = {};

  // Round trip support
  bool _isRoundTrip = false;
  FlightResult? _outboundFlight;
  FlightResult? _returnFlight;

  // ── per-passenger bag weight controllers ──
  // Each passenger starts with 1 bag. User can add/remove bags.
  late List<List<TextEditingController>> _passengerBags;

  // Return baggage mode (round trip only):
  //  'same'    → same as outbound (default)
  //  'custom'  → user picks a different weight
  //  'later'   → skip for now (decide via Manage Booking)
  String _returnBaggageMode = 'same';
  late List<List<TextEditingController>> _returnPassengerBags;

  // Overweight surcharge rate (PKR per kg above free allowance)
  static const double _overweightRatePerKg = 200;

  // ── seat selections ──
  List<Map<String, dynamic>> _seatSelections = [];
  double _seatTotal = 0.0;

  // Round trip seat selection tracking
  int _currentJourneyIndex = 0; // 0 = outbound, 1 = return
  List<Map<String, dynamic>> _outboundSeatSelections = [];
  List<Map<String, dynamic>> _returnSeatSelections = [];

  // ── Ground Transfer ──
  bool _transferAdded = false;
  String _transferVehicleType = 'Sedan';
  final TextEditingController _transferPickupCtrl = TextEditingController();

  // Issue 2 — Return transfer (round trip only)
  bool _returnTransferAdded = false;
  String _returnTransferVehicleType = 'Sedan';
  final TextEditingController _returnTransferPickupCtrl =
      TextEditingController();

  // Arrival transfer (destination city — both one-way and round trip)
  bool _arrivalTransferAdded = false;
  String _arrivalTransferVehicleType = 'Sedan';
  final TextEditingController _arrivalTransferPickupCtrl =
      TextEditingController();

  // Final arrival transfer (round trip only — destination airport → home)
  bool _finalArrivalTransferAdded = false;
  String _finalArrivalTransferVehicleType = 'Sedan';
  final TextEditingController _finalArrivalTransferPickupCtrl =
      TextEditingController();

  // ── stepper ──
  // step index 1 = FACILITIES
  final List<String> _steps = [
    'PASSENGERS',
    'FACILITIES',
    'CHECKOUT',
    'PAYMENT',
    'DONE',
  ];

  @override
  void initState() {
    super.initState();
    _rawArgs = (Get.arguments as Map<String, dynamic>?) ?? {};

    // Round trip detection
    _isRoundTrip = _rawArgs['isRoundTrip'] as bool? ?? false;
    _outboundFlight = _rawArgs['outboundFlight'] as FlightResult?;
    _returnFlight = _rawArgs['returnFlight'] as FlightResult?;

    // Use outbound flight for round trip, or single flight
    _flight =
        (_isRoundTrip ? _outboundFlight : _rawArgs['flight']) as FlightResult;
    final raw = (_rawArgs['passengers'] as List<dynamic>?) ?? [];
    _passengers = raw.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    if (_passengers.isEmpty) {
      _passengers = [
        {'firstName': 'Passenger', 'lastName': '1', 'idNumber': '', 'phone': ''}
      ];
    }
    _passengerBags = List.generate(
      _passengers.length,
      (_) => [TextEditingController(text: '0')],
    );
    _returnPassengerBags = List.generate(
      _passengers.length,
      (_) => [TextEditingController(text: '0')],
    );
    _loadSavedBaggage();

    // Restore seat selections if user navigated back from checkout
    if (_isRoundTrip) {
      final rawOutbound =
          (_rawArgs['outboundSeatSelections'] as List<dynamic>?) ?? [];
      _outboundSeatSelections =
          rawOutbound.map((s) => Map<String, dynamic>.from(s as Map)).toList();

      final rawReturn =
          (_rawArgs['returnSeatSelections'] as List<dynamic>?) ?? [];
      _returnSeatSelections =
          rawReturn.map((s) => Map<String, dynamic>.from(s as Map)).toList();

      // Restore journey index: if outbound is complete but return isn't, show return journey
      if (_outboundSeatSelections.isNotEmpty && _returnSeatSelections.isEmpty) {
        _currentJourneyIndex = 1; // Show return journey selection
      }
    } else {
      final rawSeats = (_rawArgs['seatSelections'] as List<dynamic>?) ?? [];
      _seatSelections =
          rawSeats.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    }

    // Restore seat total if present
    _seatTotal = (_rawArgs['seatTotal'] as double?) ?? 0.0;
  }

  @override
  void dispose() {
    for (final bags in _passengerBags) {
      for (final c in bags) {
        c.dispose();
      }
    }
    for (final bags in _returnPassengerBags) {
      for (final c in bags) {
        c.dispose();
      }
    }
    _transferPickupCtrl.dispose();
    _returnTransferPickupCtrl.dispose();
    _arrivalTransferPickupCtrl.dispose();
    _finalArrivalTransferPickupCtrl.dispose();
    super.dispose();
  }

  // ── helpers ──
  String _passengerName(int i) {
    final p = _passengers[i];
    final first = (p['firstName'] ?? '').toString().trim();
    final last = (p['lastName'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Passenger ${i + 1}' : full;
  }

  String _resolvedCabin() {
    // Use outbound flight for round trips, otherwise use main flight
    final flight = _isRoundTrip ? _outboundFlight : _flight;
    final c = flight?.cabinClass ?? _flight.cabinClass;
    if (c.contains('Premium')) return 'Premium Economy';
    if (c.contains('Business')) return 'Business';
    if (c.contains('First')) return 'First';
    return 'Economy';
  }

  Map<String, dynamic> _policy() =>
      _cabinPolicy[_resolvedCabin()] ?? _cabinPolicy['Economy']!;

  double _passengerOverweight(int i) {
    final freeKg = (_policy()['checkedKg'] as int).toDouble();
    final totalEntered = _passengerBags[i]
        .fold<double>(0, (s, c) => s + (double.tryParse(c.text) ?? 0));
    return (totalEntered - freeKg).clamp(0, double.infinity);
  }

  double _returnPassengerOverweight(int i) {
    final freeKg = (_policy()['checkedKg'] as int).toDouble();
    final bags = _effectiveReturnBags(i);
    final total =
        bags.fold<double>(0, (s, c) => s + (double.tryParse(c.text) ?? 0));
    return (total - freeKg).clamp(0, double.infinity);
  }

  // Returns the controllers to use for return baggage display/calculation
  List<TextEditingController> _effectiveReturnBags(int i) {
    if (_returnBaggageMode == 'same') return _passengerBags[i];
    // 'later' mode: use the already-initialised _returnPassengerBags[i] which
    // starts at 0 kg — no new controller objects created on each rebuild.
    return _returnPassengerBags[i];
  }

  double _extraBaggageTotal() {
    double total = 0;
    for (int i = 0; i < _passengers.length; i++) {
      total += _passengerOverweight(i) * _overweightRatePerKg;
      if (_isRoundTrip && _returnBaggageMode == 'custom') {
        total += _returnPassengerOverweight(i) * _overweightRatePerKg;
      } else if (_isRoundTrip && _returnBaggageMode == 'same') {
        total += _passengerOverweight(i) * _overweightRatePerKg;
      }
    }
    return total;
  }

  double _flightTotal() {
    if (_isRoundTrip && _outboundFlight != null && _returnFlight != null) {
      return (_outboundFlight!.price + _returnFlight!.price) *
          _passengers.length;
    }
    return _flight.price * _passengers.length;
  }

  // ── Seat selection helpers ──
  void _onSeatsSelected(List<Map<String, dynamic>> selections) {
    setState(() {
      if (_isRoundTrip) {
        // For round trip, store in appropriate journey
        if (_currentJourneyIndex == 0) {
          _outboundSeatSelections = selections;
        } else {
          _returnSeatSelections = selections;
        }

        // Calculate total from BOTH journeys for round trip
        final outboundTotal = _outboundSeatSelections.fold(
            0.0, (sum, s) => sum + (s['price'] as double? ?? 0.0));
        final returnTotal = _returnSeatSelections.fold(
            0.0, (sum, s) => sum + (s['price'] as double? ?? 0.0));
        _seatTotal = outboundTotal + returnTotal;
      } else {
        // For one-way, use legacy behavior
        _seatSelections = selections;
        _seatTotal = selections.fold(
            0.0, (sum, s) => sum + (s['price'] as double? ?? 0.0));
      }
    });
  }

  // Check if all required seats are actually selected (have non-empty seatName)
  bool _areAllSeatsSelected() {
    if (_isRoundTrip) {
      // For round trip, check current journey
      final currentSelections = _currentJourneyIndex == 0
          ? _outboundSeatSelections
          : _returnSeatSelections;

      if (currentSelections.isEmpty) return false;

      final selectedCount = currentSelections.where((s) {
        final seatName = s['seatName'] as String? ?? '';
        return seatName.isNotEmpty;
      }).length;

      return selectedCount == _passengers.length;
    } else {
      // For one-way
      if (_seatSelections.isEmpty) return false;

      final selectedCount = _seatSelections.where((s) {
        final seatName = s['seatName'] as String? ?? '';
        return seatName.isNotEmpty;
      }).length;

      return selectedCount == _passengers.length;
    }
  }

  // Check if all journeys (outbound + return for round trip) are complete
  bool _areAllJourneysComplete() {
    if (!_isRoundTrip) {
      return _areAllSeatsSelected();
    }

    // For round trip, both journeys must be complete
    final outboundComplete = _outboundSeatSelections.where((s) {
          final seatName = s['seatName'] as String? ?? '';
          return seatName.isNotEmpty;
        }).length ==
        _passengers.length;

    final returnComplete = _returnSeatSelections.where((s) {
          final seatName = s['seatName'] as String? ?? '';
          return seatName.isNotEmpty;
        }).length ==
        _passengers.length;

    return outboundComplete && returnComplete;
  }

  // ── Baggage persistence helpers ──
  Future<void> _loadSavedBaggage() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _passengerBags.length; i++) {
      final count = prefs.getInt('bag_p${i}_count') ?? 1;
      // add extra controllers if passenger had more than 1 bag saved
      while (_passengerBags[i].length < count) {
        _passengerBags[i].add(TextEditingController(text: '0'));
      }
      for (int j = 0; j < _passengerBags[i].length; j++) {
        final saved = prefs.getString('bag_p${i}_b$j');
        if (saved != null) {
          _passengerBags[i][j].text = saved;
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveBaggage() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _passengerBags.length; i++) {
      await prefs.setInt('bag_p${i}_count', _passengerBags[i].length);
      for (int j = 0; j < _passengerBags[i].length; j++) {
        await prefs.setString('bag_p${i}_b$j', _passengerBags[i][j].text);
      }
    }
  }

  void _onContinue() {
    // Issue 1 — Departure transfer pickup validation
    if (_transferAdded && _transferPickupCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Pickup Address Required',
        'Please enter pickup address for departure transfer',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    // Issue 2 — Return transfer pickup validation (round trip)
    if (_isRoundTrip &&
        _returnTransferAdded &&
        _returnTransferPickupCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Pickup Address Required',
        'Please enter pickup address for return transfer',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    // Arrival transfer pickup validation
    if (_arrivalTransferAdded &&
        _arrivalTransferPickupCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Pickup Address Required',
        'Please enter pickup address for arrival transfer',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    // Final arrival transfer pickup validation (round trip only)
    if (_isRoundTrip &&
        _finalArrivalTransferAdded &&
        _finalArrivalTransferPickupCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Pickup Address Required',
        'Please enter pickup address for final arrival transfer',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final policy = _policy();
    final freeKg = (policy['checkedKg'] as int).toDouble();
    final baggageData = List.generate(_passengers.length, (i) {
      final bags =
          _passengerBags[i].map((c) => double.tryParse(c.text) ?? 0).toList();
      final totalEntered = bags.fold<double>(0, (s, w) => s + w);
      final overweight = (totalEntered - freeKg).clamp(0, double.infinity);
      return {
        'passengerName': _passengerName(i),
        'freeKg': freeKg,
        'bags': bags,
        'totalKg': totalEntered,
        'overweightKg': overweight,
        'extraPrice': overweight * _overweightRatePerKg,
      };
    });

    // Build return baggage data
    final returnBaggageData = _isRoundTrip
        ? List.generate(_passengers.length, (i) {
            List<double> bags;
            if (_returnBaggageMode == 'same') {
              bags = _passengerBags[i]
                  .map((c) => double.tryParse(c.text) ?? 0)
                  .toList();
            } else if (_returnBaggageMode == 'custom') {
              bags = _returnPassengerBags[i]
                  .map((c) => double.tryParse(c.text) ?? 0)
                  .toList();
            } else {
              bags = [0.0]; // 'later'
            }
            final total = bags.fold<double>(0, (s, w) => s + w);
            final overweight = _returnBaggageMode == 'later'
                ? 0.0
                : (total - freeKg).clamp(0, double.infinity);
            return {
              'passengerName': _passengerName(i),
              'freeKg': freeKg,
              'bags': bags,
              'totalKg': total,
              'overweightKg': overweight,
              'extraPrice': overweight * _overweightRatePerKg,
              'mode': _returnBaggageMode,
            };
          })
        : <Map<String, dynamic>>[];
    _saveBaggage(); // persist bag weights so back-navigation restores them

    // Validate seat selection (optional but recommended),
    // User can proceed without seats but we'll show a warning
    if (_isRoundTrip) {
      if (!_areAllJourneysComplete()) {
        final hasOutbound = _outboundSeatSelections
            .where((s) => (s['seatName'] as String? ?? '').isNotEmpty)
            .isNotEmpty;
        final hasReturn = _returnSeatSelections
            .where((s) => (s['seatName'] as String? ?? '').isNotEmpty)
            .isNotEmpty;

        if (!hasOutbound && !hasReturn) {
          // No seats selected at all - show info message but allow continuation
          Get.snackbar(
            'No Seats Selected',
            'Seats will be assigned at check-in. Select now to choose your preferred seats.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.blue.shade100,
            colorText: Colors.blue.shade900,
            duration: const Duration(seconds: 3),
          );
        } else if (hasOutbound &&
            !_areAllSeatsSelected() &&
            _currentJourneyIndex == 0) {
          // Outbound incomplete - don't allow continuing
          Get.snackbar(
            'Incomplete Selection',
            'Please complete seat selection for all passengers on the outbound flight',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange.shade100,
            colorText: Colors.orange.shade900,
            duration: const Duration(seconds: 3),
          );
          return;
        } else if (!hasReturn && hasOutbound && _currentJourneyIndex == 0) {
          // Outbound complete, need to select return - switch to return journey
          setState(() {
            _currentJourneyIndex = 1;
          });
          Get.snackbar(
            'Select Return Seats',
            'Now select seats for your return flight',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green.shade100,
            colorText: Colors.green.shade900,
            duration: const Duration(seconds: 2),
          );
          return;
        }
      }

      // Proceed with both seat selections (or empty if none selected)
      Get.toNamed(AppLink.bookingStep3, arguments: {
        ..._rawArgs,
        'baggageData': baggageData,
        'baggageExtraTotal': _extraBaggageTotal(),
        'returnBaggageData': returnBaggageData,
        'returnBaggageMode': _returnBaggageMode,
        'outboundSeatSelections': _outboundSeatSelections,
        'returnSeatSelections': _returnSeatSelections,
        'seatTotal': _seatTotal,
        'transferAdded': _transferAdded,
        'transferVehicleType': _transferVehicleType,
        'transferPickupLocation': _transferPickupCtrl.text.trim(),
        'returnTransferAdded': _returnTransferAdded,
        'returnTransferVehicleType': _returnTransferVehicleType,
        'returnTransferPickupLocation': _returnTransferPickupCtrl.text.trim(),
        'arrivalTransferAdded': _arrivalTransferAdded,
        'arrivalTransferVehicleType': _arrivalTransferVehicleType,
        'arrivalTransferPickupLocation': _arrivalTransferPickupCtrl.text.trim(),
        'finalArrivalTransferAdded': _finalArrivalTransferAdded,
        'finalArrivalTransferVehicleType': _finalArrivalTransferVehicleType,
        'finalArrivalTransferPickupLocation':
            _finalArrivalTransferPickupCtrl.text.trim(),
      });
    } else {
      // One-way trip
      if (_seatSelections.isEmpty || !_areAllSeatsSelected()) {
        final hasAnySeats = _seatSelections
            .where((s) => (s['seatName'] as String? ?? '').isNotEmpty)
            .isNotEmpty;

        if (hasAnySeats && !_areAllSeatsSelected()) {
          // Some but not all seats selected
          Get.snackbar(
            'Incomplete Selection',
            'Please select seats for all passengers or clear all selections',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.orange.shade100,
            colorText: Colors.orange.shade900,
            duration: const Duration(seconds: 3),
          );
          return;
        } else if (!hasAnySeats) {
          // No seats selected - show info but allow continuation
          Get.snackbar(
            'No Seats Selected',
            'Seats will be assigned at check-in. Select now to choose your preferred seats.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.blue.shade100,
            colorText: Colors.blue.shade900,
            duration: const Duration(seconds: 2),
          );
        }
      }

      Get.toNamed(AppLink.bookingStep3, arguments: {
        ..._rawArgs,
        'baggageData': baggageData,
        'baggageExtraTotal': _extraBaggageTotal(),
        'returnBaggageData': returnBaggageData,
        'returnBaggageMode': _returnBaggageMode,
        'seatSelections': _seatSelections,
        'seatTotal': _seatTotal,
        'transferAdded': _transferAdded,
        'transferVehicleType': _transferVehicleType,
        'transferPickupLocation': _transferPickupCtrl.text.trim(),
        'arrivalTransferAdded': _arrivalTransferAdded,
        'arrivalTransferVehicleType': _arrivalTransferVehicleType,
        'arrivalTransferPickupLocation': _arrivalTransferPickupCtrl.text.trim(),
      });
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Light background
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildStepper(context),
          Container(height: 1, color: const Color(0xFFE0E0E0)), // Light divider
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Departure Section ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Departure',
                        style: TravelloTheme.sectionHeading),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0), // Light container
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Non-Stop - Duration: ${_isRoundTrip ? _outboundFlight!.duration : _flight.duration}',
                        style: TravelloTheme.durationBadge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9.6),
                _buildFlightCard(context),
                const SizedBox(height: 16),

                // Return flight card for round trips
                if (_isRoundTrip && _returnFlight != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Return', style: TravelloTheme.sectionHeading),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0), // Light container
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
                  const SizedBox(height: 9.6),
                  _buildReturnFlightCard(context),
                  const SizedBox(height: 16),
                ],
                _buildBaggagePolicyBanner(context),
                const SizedBox(height: 16),
                _buildPassengerBaggageSection(context),
                if (_isRoundTrip && _returnFlight != null) ...[
                  const SizedBox(height: 16),
                  _buildReturnBaggageSection(context),
                ],
                const SizedBox(height: 24),

                // ── Seat Selection Section ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.airline_seat_recline_normal,
                            color: TravelloTheme.primaryMain, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Select Your Seats',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: 0.3),
                        ),
                      ],
                    ),
                    if (_isRoundTrip)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _currentJourneyIndex == 0
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _currentJourneyIndex == 0 ? 'OUTBOUND' : 'RETURN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Optional info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Seat selection is optional. If not selected, seats will be assigned during check-in. '
                          'Select now to choose your preferred seats (PKR 2,000 per seat).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                FlightSeatPicker(
                  key: ValueKey('journey_$_currentJourneyIndex'),
                  totalPassengers: _passengers.length,
                  passengers: _passengers,
                  cabinClass: _resolvedCabin(), // Pass cabin class for pricing
                  onSeatsSelected: _onSeatsSelected,
                  initialSelections: _isRoundTrip
                      ? (_currentJourneyIndex == 0
                          ? _outboundSeatSelections
                          : _returnSeatSelections)
                      : _seatSelections,
                  journeyLabel: _isRoundTrip
                      ? (_currentJourneyIndex == 0
                          ? 'OUTBOUND FLIGHT'
                          : 'RETURN FLIGHT')
                      : null,
                ),

                // Next button for round trip (after outbound completion)
                if (_isRoundTrip &&
                    _currentJourneyIndex == 0 &&
                    _areAllSeatsSelected()) ...[
                  const SizedBox(height: 16),
                  DSButton(
                    label: 'NEXT: SELECT RETURN SEATS',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onTap: () {
                      setState(() {
                        _currentJourneyIndex = 1;
                      });
                    },
                    color: Colors.green.shade700,
                  ),
                ],

                // Back to outbound button (when on return journey)
                if (_isRoundTrip && _currentJourneyIndex == 1) ...[
                  const SizedBox(height: 16),
                  DSButton(
                    label: 'BACK TO OUTBOUND SEATS',
                    leadingIcon: Icons.arrow_back_rounded,
                    onTap: () {
                      setState(() {
                        _currentJourneyIndex = 0;
                      });
                    },
                    color: const Color(0xFFB3B3B3),
                  ),
                ],

                const SizedBox(height: 24),
                _buildTransferSection(context),
                const SizedBox(height: 80),
              ],
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  RETURN BAGGAGE SECTION (Round Trip)
  //  Industry standard: 3-option selector per Expedia/Wego/AirBlue
  // ─────────────────────────────────────────────
  Widget _buildReturnBaggageSection(BuildContext context) {
    final policy = _policy();
    final freeKg = (policy['checkedKg'] as int).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Row(
          children: [
            const Icon(Icons.luggage,
                color: TravelloTheme.primaryMain, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Return Flight Baggage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'RETURN',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── AI Smart Tip ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TravelloTheme.primaryMain.withValues(alpha: 0.08),
                TravelloTheme.primaryMain.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: TravelloTheme.primaryMain.withValues(alpha: 0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flight_takeoff,
                  size: 18, color: TravelloTheme.primaryMain),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Travello AI Tip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: TravelloTheme.primaryMain,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Bought something on your trip? You can add or upgrade baggage anytime from My Bookings — even a few hours before your flight.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 3-option selector ──
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
            ],
          ),
          child: Column(
            children: [
              _returnBaggageOption(
                context: context,
                value: 'same',
                icon: Icons.content_copy_outlined,
                title: 'Same as departure',
                subtitle: 'Apply the same baggage for your return flight',
                badge: 'Default',
                badgeColor: Colors.green.shade700,
              ),
              Divider(height: 1, color: Colors.grey.shade100, indent: 60),
              _returnBaggageOption(
                context: context,
                value: 'custom',
                icon: Icons.tune_rounded,
                title: 'Choose differently',
                subtitle: 'Select a different baggage weight for your return',
                badge: null,
                badgeColor: null,
              ),
              Divider(height: 1, color: Colors.grey.shade100, indent: 60),
              _returnBaggageOption(
                context: context,
                value: 'later',
                icon: Icons.schedule_rounded,
                title: 'Decide later',
                subtitle: 'Add via My Bookings · Available until 24 hrs before',
                badge: 'Recommended',
                badgeColor: TravelloTheme.primaryMain,
              ),
            ],
          ),
        ),

        // ── Custom return bags (shown only when mode = custom) ──
        if (_returnBaggageMode == 'custom') ...[
          const SizedBox(height: 16),
          ...List.generate(
            _passengers.length,
            (i) => _buildReturnPassengerBaggageCard(context, i, freeKg),
          ),
        ],

        // ── "later" info banner ──
        if (_returnBaggageMode == 'later') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No extra baggage fee now. Go to My Bookings → Manage Booking to add baggage before your return flight.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.blue.shade900, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _returnBaggageOption({
    required BuildContext context,
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required String? badge,
    required Color? badgeColor,
  }) {
    final selected = _returnBaggageMode == value;
    return InkWell(
      onTap: () => setState(() => _returnBaggageMode = value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? TravelloTheme.primaryMain.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? TravelloTheme.primaryMain
                      : Colors.grey.shade400,
                  width: selected ? 2 : 1.5,
                ),
                color: selected
                    ? TravelloTheme.primaryMain.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: TravelloTheme.primaryMain,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? TravelloTheme.primaryMain.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 18,
                  color: selected
                      ? TravelloTheme.primaryMain
                      : Colors.grey.shade600),
            ),
            const SizedBox(width: 9.6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? TravelloTheme.primaryMain
                              : Colors.black87,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor!.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnPassengerBaggageCard(
      BuildContext context, int i, double freeKg) {
    final overweight = _returnPassengerOverweight(i);
    final hasOverweight = overweight > 0;
    final extraCharge = overweight * _overweightRatePerKg;
    final totalEntered = _returnPassengerBags[i]
        .fold<double>(0, (s, c) => s + (double.tryParse(c.text) ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasOverweight ? Colors.red.shade300 : Colors.grey.shade200,
          width: hasOverweight ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6.4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Color(0xFFB3B3B3), size: 18),
                ),
                const SizedBox(width: 9.6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_passengerName(i),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('Return · Passenger ${i + 1}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFB3B3B3))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasOverweight
                        ? Colors.red.shade50
                        : TravelloTheme.primaryMain.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${totalEntered.toStringAsFixed(0)} kg',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasOverweight
                          ? Colors.red.shade700
                          : TravelloTheme.primaryMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFE0E0E0)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFFD4AF37), size: 16),
                const SizedBox(width: 6.4),
                Text(
                  'Free allowance: ${freeKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Bags',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            ...List.generate(_returnPassengerBags[i].length, (bagIdx) {
              final ctrl = _returnPassengerBags[i][bagIdx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5.6),
                      decoration: BoxDecoration(
                        color:
                            TravelloTheme.primaryMain.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.luggage_outlined,
                          color: TravelloTheme.primaryMain, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text('Bag ${bagIdx + 1}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            suffixText: 'kg',
                            suffixStyle: const TextStyle(
                                fontSize: 12, color: Color(0xFFB3B3B3)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: TravelloTheme.primaryMain,
                                    width: 1.5)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.4),
                    if (_returnPassengerBags[i].length > 1)
                      GestureDetector(
                        onTap: () => setState(() {
                          ctrl.dispose();
                          _returnPassengerBags[i].removeAt(bagIdx);
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4.8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.remove_circle_outline,
                              color: Colors.red.shade400, size: 18),
                        ),
                      )
                    else
                      const SizedBox(width: 24),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() {
                _returnPassengerBags[i].add(TextEditingController(text: '0'));
              }),
              icon: const Icon(Icons.add_circle_outline,
                  size: 16, color: TravelloTheme.primaryMain),
              label: const Text('Add Bag',
                  style: TextStyle(
                      fontSize: 12,
                      color: TravelloTheme.primaryMain,
                      fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            if (hasOverweight) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6.4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 6.4),
                    Expanded(
                      child: Text(
                        'Overweight: ${overweight.toStringAsFixed(0)} kg  ·  '
                        'Extra charge PKR ${extraCharge.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  GROUND TRANSFER SECTION
  // ─────────────────────────────────────────────
  // Shared card builder used by all three transfer sections.
  Widget _buildTransferCard({
    required String title,
    required String subtitle,
    required bool added,
    required String vehicleType,
    required TextEditingController pickupCtrl,
    required VoidCallback onToggle,
    required void Function(String) onVehicleChanged,
  }) {
    const List<Map<String, dynamic>> vehicles = [
      {'type': 'Sedan', 'desc': '1–3 passengers', 'price': 800},
      {'type': 'SUV', 'desc': '1–5 passengers', 'price': 1200},
      {'type': 'Van', 'desc': '6–9 passengers', 'price': 1500},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TravelloTheme.primaryMain,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: TravelloTheme.primaryMain,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                // Add / Remove toggle
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: added
                          ? Colors.red.shade50
                          : TravelloTheme.primaryMain,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: added
                            ? Colors.red.shade300
                            : TravelloTheme.primaryMain,
                      ),
                    ),
                    child: Text(
                      added ? 'Remove' : '+ Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: added ? Colors.red.shade700 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Expanded details (shown when added) ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState:
                added ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9.6),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFF999999)),
                  SizedBox(width: 6),
                  Text(
                    'AC vehicle — driver assigned 2 hrs before departure',
                    style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                  ),
                ],
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Vehicle selector ──
                  const Text(
                    'Select Vehicle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: vehicles.map((v) {
                      final selected = vehicleType == v['type'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onVehicleChanged(v['type'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: EdgeInsets.only(
                              right: v['type'] != 'Van' ? 8 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9.6,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? TravelloTheme.primaryMain
                                      .withValues(alpha: 0.1)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? TravelloTheme.primaryMain
                                    : const Color(0xFFE0E0E0),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  v['type'] == 'Van'
                                      ? Icons.airport_shuttle_rounded
                                      : Icons.directions_car_filled_rounded,
                                  size: 22,
                                  color: selected
                                      ? TravelloTheme.primaryMain
                                      : const Color(0xFF888888),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  v['type'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? TravelloTheme.primaryMain
                                        : const Color(0xFF444444),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  v['desc'] as String,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF888888),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PKR ${v['price']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? TravelloTheme.primaryMain
                                        : const Color(0xFF444444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Pickup location ──
                  const Text(
                    'Pickup Address',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 6.4),
                  TextField(
                    controller: pickupCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. House 12, Block A, Gulshan, Karachi',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFAAAAAA),
                      ),
                      prefixIcon: const Icon(Icons.location_on_outlined,
                          color: TravelloTheme.primaryMain, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: TravelloTheme.primaryMain, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                    ),
                    maxLines: 2,
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF222222)),
                  ),

                  const SizedBox(height: 12),

                  // ── Info banner ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB2DFB2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: Color(0xFF4CAF50)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Driver details sent via E-mail 2 hrs before pickup. AC vehicle guaranteed.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF2E7D32),
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
        ],
      ),
    );
  }

  Widget _buildTransferSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card 1 — always shown
        _buildTransferCard(
          title: 'Departure Transfer',
          subtitle:
              _isRoundTrip ? 'Home → Departure airport' : 'Home → Airport',
          added: _transferAdded,
          vehicleType: _transferVehicleType,
          pickupCtrl: _transferPickupCtrl,
          onToggle: () => setState(() {
            _transferAdded = !_transferAdded;
            if (!_transferAdded) _transferPickupCtrl.clear();
          }),
          onVehicleChanged: (t) => setState(() => _transferVehicleType = t),
        ),

        // Card 2 — always shown
        const SizedBox(height: 16),
        _buildTransferCard(
          title: 'Arrival Transfer',
          subtitle: _isRoundTrip
              ? 'Arrival airport → Destination'
              : 'Airport → Destination',
          added: _arrivalTransferAdded,
          vehicleType: _arrivalTransferVehicleType,
          pickupCtrl: _arrivalTransferPickupCtrl,
          onToggle: () => setState(() {
            _arrivalTransferAdded = !_arrivalTransferAdded;
            if (!_arrivalTransferAdded) _arrivalTransferPickupCtrl.clear();
          }),
          onVehicleChanged: (t) =>
              setState(() => _arrivalTransferVehicleType = t),
        ),

        // Cards 3 & 4 — round trip only
        if (_isRoundTrip) ...[
          const SizedBox(height: 16),
          _buildTransferCard(
            title: 'Return Transfer',
            subtitle: 'Destination → Return airport',
            added: _returnTransferAdded,
            vehicleType: _returnTransferVehicleType,
            pickupCtrl: _returnTransferPickupCtrl,
            onToggle: () => setState(() {
              _returnTransferAdded = !_returnTransferAdded;
              if (!_returnTransferAdded) _returnTransferPickupCtrl.clear();
            }),
            onVehicleChanged: (t) =>
                setState(() => _returnTransferVehicleType = t),
          ),
          const SizedBox(height: 16),
          _buildTransferCard(
            title: 'Final Arrival Transfer',
            subtitle: 'Return airport → Home',
            added: _finalArrivalTransferAdded,
            vehicleType: _finalArrivalTransferVehicleType,
            pickupCtrl: _finalArrivalTransferPickupCtrl,
            onToggle: () => setState(() {
              _finalArrivalTransferAdded = !_finalArrivalTransferAdded;
              if (!_finalArrivalTransferAdded) {
                _finalArrivalTransferPickupCtrl.clear();
              }
            }),
            onVehicleChanged: (t) =>
                setState(() => _finalArrivalTransferVehicleType = t),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  APP BAR - Matches Bookme/Expedia Style
  // ─────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: TravelloTheme.primaryMain,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: const Text(
        'Facilities',
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

  // ─────────────────────────────────────────────
  //  5-STEP STEPPER - Matches Bookme/Expedia Style
  // ─────────────────────────────────────────────
  Widget _buildStepper(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    const goldColor = Color(0xFFD4AF37);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 8 : 12,
        horizontal: isMobile ? 8 : 16,
      ),
      child: Row(
        children: List.generate(9, (i) {
          if (i.isOdd) {
            // Connecting line
            final stepBefore = i ~/ 2;
            final isCompleted = stepBefore < 1;
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
          final isActive = index == 1; // FACILITIES
          final isCompleted = index < 1;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 24 : 28,
                height: isMobile ? 24 : 28,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? goldColor
                      : const Color(0xFFE0E0E0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check,
                          color: Colors.white, size: isMobile ? 12 : 14)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color:
                                isActive ? Colors.white : Colors.grey.shade500,
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                _steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 7 : 9,
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

  // ─────────────────────────────────────────────
  //  FLIGHT INFO CARD
  // ─────────────────────────────────────────────
  Widget _buildFlightCard(BuildContext context) {
    final cabinColor = _policy()['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)), // Light divider
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9.6),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flight,
                color: TravelloTheme.primaryMain, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _flight.airlineName,
                  style: TravelloTheme.subtitle
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_flight.airlineCode}  ·  ${_flight.departureTime} → ${_flight.arrivalTime}',
                  style: TravelloTheme.caption
                      .copyWith(color: const Color(0xFFB3B3B3)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cabinColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cabinColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              _resolvedCabin(),
              style: TextStyle(
                color: cabinColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnFlightCard(BuildContext context) {
    if (_returnFlight == null) return const SizedBox.shrink();

    final cabinColor = (_cabinPolicy[_returnFlight!.cabinClass] ??
        _cabinPolicy['Economy'])!['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)), // Light divider
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9.6),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flight,
                color: TravelloTheme.primaryMain, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _returnFlight!.airlineName,
                  style: TravelloTheme.subtitle
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_returnFlight!.airlineCode}  ·  ${_returnFlight!.departureTime} → ${_returnFlight!.arrivalTime}',
                  style: TravelloTheme.caption
                      .copyWith(color: const Color(0xFFB3B3B3)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cabinColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cabinColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              _returnFlight!.cabinClass,
              style: TextStyle(
                color: cabinColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BAGGAGE POLICY BANNER
  // ─────────────────────────────────────────────
  Widget _buildBaggagePolicyBanner(BuildContext context) {
    final policy = _policy();
    final cabinColor = policy['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cabinColor.withValues(alpha: 0.09),
            cabinColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cabinColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: cabinColor, size: 17),
              const SizedBox(width: 8),
              Text(
                'Free Baggage Allowance  ·  ${_resolvedCabin()}',
                style: TextStyle(
                  color: cabinColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _policyChip(
                icon: Icons.backpack_outlined,
                label: 'Carry-on',
                value: policy['carryOn'].toString(),
                color: cabinColor,
              ),
              const SizedBox(width: 12),
              _policyChip(
                icon: Icons.luggage_outlined,
                label: 'Checked',
                value: '${policy['checkedBags']}×${policy['checked']}',
                color: cabinColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(9.6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_outlined,
                    color: Colors.amber, size: 15),
                const SizedBox(width: 6.4),
                Expanded(
                  child: Text(
                    'Airport overweight charges can be very high. '
                    'Pre-purchasing extra baggage below saves up to 60% '
                    'compared to paying at the airport.',
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(9.6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5), // Light card
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6.4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFB3B3B3))),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  PER-PASSENGER BAGGAGE SECTION
  // ─────────────────────────────────────────────
  Widget _buildPassengerBaggageSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.luggage,
                color: TravelloTheme.primaryMain, size: 22),
            const SizedBox(width: 8),
            Text(
              'Baggage Detail',
              style:
                  TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(
            _passengers.length, (i) => _buildPassengerBaggageCard(context, i)),
      ],
    );
  }

  Widget _buildPassengerBaggageCard(BuildContext context, int i) {
    final policy = _policy();
    final freeKg = (policy['checkedKg'] as int).toDouble();
    final overweight = _passengerOverweight(i);
    final hasOverweight = overweight > 0;
    final extraCharge = overweight * _overweightRatePerKg;
    final totalEntered = _passengerBags[i]
        .fold<double>(0, (s, c) => s + (double.tryParse(c.text) ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasOverweight ? Colors.red.shade300 : Colors.grey.shade200,
          width: hasOverweight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── passenger name row ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6.4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0), // Light container
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Color(0xFFB3B3B3), size: 18),
                ),
                const SizedBox(width: 9.6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _passengerName(i),
                        style: TravelloTheme.subtitle.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text('Passenger ${i + 1}',
                          style: TravelloTheme.caption
                              .copyWith(color: const Color(0xFFB3B3B3))),
                    ],
                  ),
                ),
                // total kg badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasOverweight
                        ? Colors.red.shade50
                        : TravelloTheme.primaryMain.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${totalEntered.toStringAsFixed(0)} kg total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasOverweight
                          ? Colors.red.shade700
                          : TravelloTheme.primaryMain,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFE0E0E0)),
            const SizedBox(height: 12),

            // ── free allowance row ──
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFFD4AF37), size: 16),
                const SizedBox(width: 6.4),
                Text(
                  'Free allowance: ${freeKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── bag rows ──
            const Text(
              'Bags',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_passengerBags[i].length, (bagIdx) {
              final ctrl = _passengerBags[i][bagIdx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5.6),
                      decoration: BoxDecoration(
                        color:
                            TravelloTheme.primaryMain.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.luggage_outlined,
                          color: TravelloTheme.primaryMain, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bag ${bagIdx + 1}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            suffixText: 'kg',
                            suffixStyle: const TextStyle(
                                fontSize: 12, color: Color(0xFFB3B3B3)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: TravelloTheme.primaryMain, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.4),
                    if (_passengerBags[i].length > 1)
                      GestureDetector(
                        onTap: () => setState(() {
                          ctrl.dispose();
                          _passengerBags[i].removeAt(bagIdx);
                          _saveBaggage();
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4.8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.remove_circle_outline,
                              color: Colors.red.shade400, size: 18),
                        ),
                      )
                    else
                      const SizedBox(width: 24),
                  ],
                ),
              );
            }),

            // ── add bag button ──
            TextButton.icon(
              onPressed: () => setState(() {
                _passengerBags[i].add(TextEditingController(text: '0'));
                _saveBaggage();
              }),
              icon: const Icon(Icons.add_circle_outline,
                  size: 16, color: TravelloTheme.primaryMain),
              label: const Text(
                'Add Bag',
                style: TextStyle(
                    fontSize: 12,
                    color: TravelloTheme.primaryMain,
                    fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),

            // ── overweight warning ──
            if (hasOverweight) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6.4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 6.4),
                    Expanded(
                      child: Text(
                        'Overweight: ${overweight.toStringAsFixed(0)} kg  ·  '
                        'Extra charge PKR ${extraCharge.toStringAsFixed(0)} '
                        '(PKR ${_overweightRatePerKg.toStringAsFixed(0)}/kg)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BOTTOM BAR
  // ─────────────────────────────────────────────
  String _formatPKR(double amount) {
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

  Widget _buildBottomBar(BuildContext context) {
    final extraTotal = _extraBaggageTotal();
    final flightTotal = _flightTotal();
    final seatTotal = _seatTotal;
    final grandTotal = flightTotal + extraTotal + seatTotal;

    return Container(
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── price breakdown ──
              Container(
                padding: const EdgeInsets.all(14.4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5), // Light surface
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE0E0E0)), // Light divider
                ),
                child: Column(
                  children: [
                    _priceRow(
                      context,
                      icon: Icons.flight,
                      label: _isRoundTrip
                          ? 'Round Trip Ticket'
                          : 'Flight subtotal',
                      sublabel: _isRoundTrip
                          ? '${_passengers.length} pax × ${_formatPKR(_outboundFlight!.price + _returnFlight!.price)}'
                          : '${_passengers.length} pax × ${_formatPKR(_flight.price)}',
                      value: _formatPKR(flightTotal),
                      valueColor: Colors.black87,
                    ),
                    if (extraTotal > 0) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                            height: 1,
                            color: Color(0xFFE0E0E0)), // Light divider
                      ),
                      _priceRow(
                        context,
                        icon: Icons.luggage_outlined,
                        label: 'Extra baggage',
                        sublabel: 'Overweight surcharge',
                        value: '+ ${_formatPKR(extraTotal)}',
                        valueColor: Colors.orange.shade700,
                      ),
                    ],
                    if (seatTotal > 0) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                            height: 1,
                            color: Color(0xFFE0E0E0)), // Light divider
                      ),
                      _priceRow(
                        context,
                        icon: Icons.airline_seat_recline_normal,
                        label: 'Seat selection',
                        sublabel: _isRoundTrip
                            ? 'Outbound + Return seats'
                            : '${_seatSelections.where((s) => (s['seatName'] as String? ?? '').isNotEmpty).length} seat(s)',
                        value: '+ ${_formatPKR(seatTotal)}',
                        valueColor: Colors.green.shade700,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14.4),

              // ── grand total + continue button ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Payable',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF666666), // Light gray text
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatPKR(grandTotal),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: TravelloTheme.primaryMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Incl. all taxes & fees',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  DSButton(
                    label: 'CONTINUE',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onTap: _onContinue,
                    width: 158,
                    height: 56,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6.4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFFB3B3B3)),
        ),
        const SizedBox(width: 9.6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                sublabel,
                style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
