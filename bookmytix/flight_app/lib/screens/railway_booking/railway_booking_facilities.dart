import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flight_app/screens/railway/train_results_screen.dart';
import 'package:flight_app/widgets/railway/train_seat_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────
class RailwayBookingFacilities extends StatefulWidget {
  const RailwayBookingFacilities({super.key});

  @override
  State<RailwayBookingFacilities> createState() =>
      _RailwayBookingFacilitiesState();
}

class _RailwayBookingFacilitiesState extends State<RailwayBookingFacilities> {
  // ── args ──
  late TrainResult _train;
  late List<Map<String, dynamic>> _passengers;
  Map<String, dynamic> _rawArgs = {};

  // Round trip support
  bool _isRoundTrip = false;
  TrainResult? _outboundTrain;
  TrainResult? _returnTrain;
  late String _selectedClass;
  String? _outboundClass;
  String? _returnClass;

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

  // Helper to get required seat count (excluding infants who don't need seats)
  int get _requiredSeats {
    return _passengers.where((p) {
      final concessionType = p['concessionType'] as String? ?? 'ADULT';
      return concessionType != 'INFANT';
    }).length;
  }

  // Get list of passengers who need seats (adults and children only, no infants)
  List<Map<String, dynamic>> get _passengersNeedingSeats {
    return _passengers.where((p) {
      final concessionType = p['concessionType'] as String? ?? 'ADULT';
      return concessionType != 'INFANT';
    }).toList();
  }

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
    _outboundTrain = _rawArgs['outboundTrain'] as TrainResult?;
    _returnTrain = _rawArgs['returnTrain'] as TrainResult?;
    _selectedClass = _rawArgs['selectedClass'] as String? ?? 'Economy';
    _outboundClass = _rawArgs['outboundClass'] as String?;
    _returnClass = _rawArgs['returnClass'] as String?;

    // Use outbound train for round trip, or single train
    _train = (_isRoundTrip ? _outboundTrain : _rawArgs['train']) as TrainResult;
    final raw = (_rawArgs['passengers'] as List<dynamic>?) ?? [];
    _passengers = raw.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    if (_passengers.isEmpty) {
      _passengers = [
        {'firstName': 'Passenger', 'lastName': '1', 'idNumber': '', 'phone': ''}
      ];
    }

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
    _transferPickupCtrl.dispose();
    super.dispose();
  }

  // ── helpers ──
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

      return selectedCount == _requiredSeats;
    } else {
      // For one-way
      if (_seatSelections.isEmpty) return false;

      final selectedCount = _seatSelections.where((s) {
        final seatName = s['seatName'] as String? ?? '';
        return seatName.isNotEmpty;
      }).length;

      return selectedCount == _requiredSeats;
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
        _requiredSeats;

    final returnComplete = _returnSeatSelections.where((s) {
          final seatName = s['seatName'] as String? ?? '';
          return seatName.isNotEmpty;
        }).length ==
        _requiredSeats;

    return outboundComplete && returnComplete;
  }

  String _passengerBreakdownText() {
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
    if (adults > 0) parts.add('$adults Adult${adults > 1 ? 's' : ''}');
    if (children > 0) parts.add('$children Child${children > 1 ? 'ren' : ''}');
    if (infants > 0) parts.add('$infants Infant${infants > 1 ? 's' : ''}');
    return parts.join(' · ');
  }

  void _onContinue() {
    if (_isRoundTrip) {
      // For round trip, validate both journeys
      if (!_areAllJourneysComplete()) {
        Get.snackbar(
          'Incomplete Selection',
          'Please complete seat selection for both outbound and return journeys',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade900,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Proceed with both seat selections
      Get.toNamed(AppLink.railwayBookingStep3, arguments: {
        ..._rawArgs,
        'outboundSeatSelections': _outboundSeatSelections,
        'returnSeatSelections': _returnSeatSelections,
        'seatTotal': _seatTotal,
        'transferAdded': _transferAdded,
        'transferVehicleType': _transferVehicleType,
        'transferPickupLocation': _transferPickupCtrl.text.trim(),
      });
    } else {
      // Original one-way logic
      if (_seatSelections.isEmpty) {
        Get.snackbar(
          'Seat Selection Required',
          'Please select seats for all passengers before continuing',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
          colorText: Colors.red.shade900,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (_seatSelections.length != _requiredSeats) {
        Get.snackbar(
          'Incomplete Selection',
          'Please select $_requiredSeats seat(s) (infants do not require seats)',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade100,
          colorText: Colors.orange.shade900,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      Get.toNamed(AppLink.railwayBookingStep3, arguments: {
        ..._rawArgs,
        'seatSelections': _seatSelections,
        'seatTotal': _seatTotal,
        'transferAdded': _transferAdded,
        'transferVehicleType': _transferVehicleType,
        'transferPickupLocation': _transferPickupCtrl.text.trim(),
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
                    Text('Departure', style: TravelloTheme.sectionHeading),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0), // Light gray container
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Direct - Duration: ${_isRoundTrip ? _outboundTrain!.duration : _train.duration}',
                        style: TravelloTheme.durationBadge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9.6),
                _buildTrainCard(context),
                const SizedBox(height: 16),

                // Return train card for round trips
                if (_isRoundTrip && _returnTrain != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Return', style: TravelloTheme.sectionHeading),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFE0E0E0), // Light gray container
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
                  const SizedBox(height: 9.6),
                  _buildReturnTrainCard(context),
                  const SizedBox(height: 16),
                ],

                // ── Seat Selection Section ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Your Seats',
                        style: TravelloTheme.selectSeatHeading),
                    if (_isRoundTrip)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _currentJourneyIndex == 0
                              ? const Color(0xFFD4AF37)
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
                const SizedBox(height: 9.6),
                TrainSeatPicker(
                  key: ValueKey('journey_$_currentJourneyIndex'),
                  trainClass: _isRoundTrip
                      ? (_currentJourneyIndex == 0
                          ? (_outboundClass ?? _selectedClass)
                          : (_returnClass ?? _selectedClass))
                      : _selectedClass,
                  totalPassengers: _requiredSeats,
                  passengers: _passengersNeedingSeats,
                  onSeatsSelected: _onSeatsSelected,
                ),
                if (_isRoundTrip &&
                    _currentJourneyIndex == 0 &&
                    _areAllSeatsSelected())
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DSButton(
                      label: 'NEXT: SELECT RETURN SEATS',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onTap: () {
                        setState(() {
                          _currentJourneyIndex = 1;
                        });
                      },
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                if (_isRoundTrip && _currentJourneyIndex == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DSButton(
                      label: 'BACK TO OUTBOUND SEATS',
                      leadingIcon: Icons.arrow_back_rounded,
                      onTap: () {
                        setState(() {
                          _currentJourneyIndex = 0;
                        });
                      },
                      color: const Color(0xFFB3B3B3),
                    ),
                  ),
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
  //  GROUND TRANSFER SECTION
  // ─────────────────────────────────────────────
  Widget _buildTransferSection(BuildContext context) {
    const Color primaryColor = Color(0xFFD4AF37);

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
            decoration: const BoxDecoration(
              color: Color(0x14D4AF37), // gold at 8% opacity
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Station Transfer',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      Text(
                        'Pickup or drop-off at your doorstep',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                // Add / Remove toggle
                GestureDetector(
                  onTap: () => setState(() {
                    _transferAdded = !_transferAdded;
                    if (!_transferAdded) _transferPickupCtrl.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _transferAdded ? Colors.red.shade50 : primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            _transferAdded ? Colors.red.shade300 : primaryColor,
                      ),
                    ),
                    child: Text(
                      _transferAdded ? 'Remove' : '+ Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            _transferAdded ? Colors.red.shade700 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Expanded details ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _transferAdded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 9.6,
              ),
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
                      final selected = _transferVehicleType == v['type'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _transferVehicleType = v['type'] as String),
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
                                  ? const Color(0x1FD4AF37)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? primaryColor
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
                                      ? primaryColor
                                      : const Color(0xFF888888),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  v['type'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? primaryColor
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
                                        ? primaryColor
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
                    controller: _transferPickupCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. House 12, Block A, Gulshan, Karachi',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFAAAAAA),
                      ),
                      prefixIcon: const Icon(Icons.location_on_outlined,
                          color: Color(0xFFD4AF37), size: 20),
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
                            color: Color(0xFFD4AF37), width: 1.5),
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
                            'Driver details sent via SMS 2 hrs before pickup. AC vehicle guaranteed.',
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

  // ─────────────────────────────────────────────
  //  APP BAR - Matches Train Theme (Green)
  // ─────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFD4AF37),
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
  //  5-STEP STEPPER - Green Theme for Trains
  // ─────────────────────────────────────────────
  Widget _buildStepper(BuildContext context) {
    const goldColor = Color(0xFFD4AF37);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                _steps[index],
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

  // ─────────────────────────────────────────────
  //  TRAIN INFO CARD
  // ─────────────────────────────────────────────
  Widget _buildTrainCard(BuildContext context) {
    final classColor = _selectedClass.contains('First')
        ? Colors.purple
        : _selectedClass.contains('AC')
            ? Colors.orange
            : Colors.blue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Light card
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
              color: const Color(0xFFF5E6D3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.train, color: Color(0xFFD4AF37), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _train.trainName,
                  style:
                      TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_train.trainNumber}  ·  ${_train.departureTime} → ${_train.arrivalTime}',
                  style: TravelloTheme.caption
                      .copyWith(color: const Color(0xFFB3B3B3)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: classColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: classColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              _selectedClass,
              style: TextStyle(
                color: classColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnTrainCard(BuildContext context) {
    if (_returnTrain == null) return const SizedBox.shrink();

    final returnClass = _returnClass ?? _selectedClass;
    final classColor = returnClass.contains('First')
        ? Colors.purple
        : returnClass.contains('AC')
            ? Colors.orange
            : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Light card
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
              color: const Color(0xFFF5E6D3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.train, color: Color(0xFFD4AF37), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _returnTrain!.trainName,
                  style:
                      TravelloTheme.subtitle.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_returnTrain!.trainNumber}  ·  ${_returnTrain!.departureTime} → ${_returnTrain!.arrivalTime}',
                  style: TravelloTheme.caption
                      .copyWith(color: const Color(0xFFB3B3B3)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: classColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: classColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              returnClass,
              style: TextStyle(
                color: classColor,
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
    // Calculate ticket total with concessions
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

    double ticketTotal = 0.0;
    for (var passenger in _passengers) {
      final concessionType = passenger['concessionType'] as String? ?? 'ADULT';
      if (concessionType == 'INFANT') {
        ticketTotal += 0.0; // Infants travel free
      } else if (concessionType == 'CHILD_3_10') {
        ticketTotal += basePrice * 0.5; // Children get 50% discount
      } else {
        ticketTotal += basePrice; // Adults pay full fare
      }
    }

    final grandTotal = ticketTotal + _seatTotal;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Light card
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
          padding: const EdgeInsets.fromLTRB(20, 16,
              20, 16),
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
                      icon: Icons.train,
                      label:
                          _isRoundTrip ? 'Round Trip Ticket' : 'Train subtotal',
                      sublabel: _passengerBreakdownText(),
                      value: _formatPKR(ticketTotal),
                      valueColor: Colors.black87,
                    ),
                    // Seat selection info (no extra charge)
                    if (_isRoundTrip) ...[
                      // Round trip - show both journeys
                      if (_outboundSeatSelections
                          .where((s) => s['seatName'].toString().isNotEmpty)
                          .isNotEmpty) ...[
                        const SizedBox(height: 9.6),
                        _priceRow(
                          context,
                          icon: Icons.event_seat,
                          label: 'Outbound Seats',
                          sublabel:
                              '${_outboundSeatSelections.where((s) => s['seatName'].toString().isNotEmpty).length} of $_requiredSeats selected',
                          value: 'Included',
                          valueColor: const Color(0xFFD4AF37),
                        ),
                      ],
                      if (_returnSeatSelections
                          .where((s) => s['seatName'].toString().isNotEmpty)
                          .isNotEmpty) ...[
                        const SizedBox(height: 9.6),
                        _priceRow(
                          context,
                          icon: Icons.event_seat,
                          label: 'Return Seats',
                          sublabel:
                              '${_returnSeatSelections.where((s) => s['seatName'].toString().isNotEmpty).length} of $_requiredSeats selected',
                          value: 'Included',
                          valueColor: const Color(0xFFD4AF37),
                        ),
                      ],
                    ] else ...[
                      // One-way trip
                      if (_seatSelections
                          .where((s) => s['seatName'].toString().isNotEmpty)
                          .isNotEmpty) ...[
                        const SizedBox(height: 9.6),
                        _priceRow(
                          context,
                          icon: Icons.event_seat,
                          label: 'Seat Selection',
                          sublabel:
                              '${_seatSelections.where((s) => s['seatName'].toString().isNotEmpty).length} of $_requiredSeats seat(s) selected',
                          value: 'Included',
                          valueColor: const Color(0xFFD4AF37),
                        ),
                      ],
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
                            color: Color(0xFF666666), // Gray text
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
                            color: Color(0xFFD4AF37),
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
                    disabled: !_areAllJourneysComplete(),
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
