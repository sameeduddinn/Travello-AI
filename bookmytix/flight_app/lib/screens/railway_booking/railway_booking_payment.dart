import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/screens/railway/train_results_screen.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/design_system_validators.dart';
import 'dart:math' as math;

class RailwayBookingPayment extends StatefulWidget {
  const RailwayBookingPayment({super.key});

  @override
  State<RailwayBookingPayment> createState() => _RailwayBookingPaymentState();
}

class _RailwayBookingPaymentState extends State<RailwayBookingPayment>
    with TickerProviderStateMixin {
  // Train specific variables
  TrainResult? _train;
  TrainResult? _outboundTrain;
  TrainResult? _returnTrain;
  String _selectedClass = 'Economy';
  String? _outboundClass;
  String? _returnClass;
  late List<Map<String, dynamic>> _luggageData;
  String _fromStation = '';
  String _toStation = '';
  String _fromStationCode = '';
  String _toStationCode = '';
  bool _isRoundTrip = false;
  DateTime? _departureDate;
  DateTime? _returnDate;

  // Passengers
  int _adults = 1;
  int _children = 0;
  int _infants = 0;
  late List<Map<String, dynamic>> _passengers;

  // Seat selections
  List<Map<String, dynamic>> _seatSelections = [];
  List<Map<String, dynamic>> _outboundSeatSelections = [];
  List<Map<String, dynamic>> _returnSeatSelections = [];

  // Contact information
  String _contactEmail = '';
  String _contactPhone = '';

  // Payment state
  String _selectedPaymentMethod = '';
  bool _isPriceBreakdownExpanded = false;
  bool _agreedToTerms = true;
  bool _showTermsError = false;
  bool _saveCard = false;
  bool _isProcessing = false;
  String _selectedCountryCode = '+92';
  bool _showEasypaisaOTP = false;
  bool _showJazzcashOTP = false;

  // OTP Timer
  Timer? _otpTimer;
  int _otpRemainingSeconds = 27;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _easypaisaPhoneController = TextEditingController();
  final _jazzcashPhoneController = TextEditingController();

  // Price calculations (Train)
  double _baseFare = 0;
  double _reservationCharges = 50; // Pakistan Railways reservation fee
  double _serviceFee = 100; // Pakistan Railways service/convenience fee
  double _paymentMethodFee = 0; // gateway fee: card=74, jazz/easy=24
  double _transferFee = 0; // Station transfer add-on
  final double _discount = 0;
  double get _grandTotal =>
      _baseFare +
      _reservationCharges +
      _serviceFee +
      _paymentMethodFee +
      _transferFee -
      _discount;

  bool get _isPaymentDetailsValid {
    if (_selectedPaymentMethod.isEmpty) return false;

    if (_selectedPaymentMethod == 'card') {
      final cardNumberDigits = _cardNumberController.text.replaceAll(' ', '');
      final cardOk = DSValidators.cardNumber(cardNumberDigits) == null;
      final expiryOk =
          DSValidators.cardExpiry(_expiryController.text.trim()) == null;
      final cvvOk = DSValidators.cvv(_cvvController.text.trim()) == null;
      final nameOk =
          DSValidators.cardholderName(_cardNameController.text.trim()) == null;
      return cardOk && expiryOk && cvvOk && nameOk;
    } else if (_selectedPaymentMethod == 'easypaisa') {
      return _easypaisaPhoneController.text.trim().length >= 10;
    } else if (_selectedPaymentMethod == 'jazzcash') {
      return _jazzcashPhoneController.text.trim().length >= 10;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadArguments();
    _cardNumberController.addListener(() => setState(() {}));
    _expiryController.addListener(() => setState(() {}));
    _cvvController.addListener(() => setState(() {}));
    _cardNameController.addListener(() => setState(() {}));
    _easypaisaPhoneController.addListener(() => setState(() {}));
    _jazzcashPhoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _easypaisaPhoneController.dispose();
    _jazzcashPhoneController.dispose();
    super.dispose();
  }

  void _loadArguments() {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args == null) return;

    final passList = args['passengers'] as List<dynamic>?;
    _passengers =
        passList?.map((p) => Map<String, dynamic>.from(p as Map)).toList() ??
            [];

    final luggageList = args['luggageData'] as List<dynamic>?;
    _luggageData =
        luggageList?.map((l) => Map<String, dynamic>.from(l as Map)).toList() ??
            [];

    _contactEmail = args['contactEmail'] as String? ?? '';
    _contactPhone = args['contactPhone'] as String? ?? '';
    _fromStation = args['fromStation'] as String? ?? '';
    _toStation = args['toStation'] as String? ?? '';
    _fromStationCode = args['fromStationCode'] as String? ?? '';
    _toStationCode = args['toStationCode'] as String? ?? '';
    _selectedClass = args['selectedClass'] as String? ?? 'Economy';
    _isRoundTrip = args['isRoundTrip'] as bool? ?? false;
    _departureDate = args['departureDate'] as DateTime?;
    _returnDate = args['returnDate'] as DateTime?;

    // Count passengers by concessionType (set by checkout)
    // concessionType values: 'ADULT', 'CHILD_3_10', 'INFANT'
    _adults = _passengers.where((p) => p['concessionType'] == 'ADULT').length;
    _children =
        _passengers.where((p) => p['concessionType'] == 'CHILD_3_10').length;
    _infants = _passengers.where((p) => p['concessionType'] == 'INFANT').length;

    // Fallback: if concessionType not present, use top-level counts from args
    if (_adults == 0 && _children == 0 && _infants == 0) {
      _adults = args['adults'] as int? ?? _passengers.length.clamp(1, 9);
      _children = args['children'] as int? ?? 0;
      _infants = args['infants'] as int? ?? 0;
    }

    // Load train data
    if (_isRoundTrip) {
      _outboundTrain = args['outboundTrain'] as TrainResult?;
      _returnTrain = args['returnTrain'] as TrainResult?;
      _outboundClass = args['outboundClass'] as String?;
      _returnClass = args['returnClass'] as String?;
      _train = _outboundTrain;

      // Load round trip seat selections
      final rawOutbound =
          (args['outboundSeatSelections'] as List<dynamic>?) ?? [];
      _outboundSeatSelections =
          rawOutbound.map((s) => Map<String, dynamic>.from(s as Map)).toList();

      final rawReturn = (args['returnSeatSelections'] as List<dynamic>?) ?? [];
      _returnSeatSelections =
          rawReturn.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    } else {
      _train = args['train'] as TrainResult?;

      // Load one-way seat selections
      final rawSeats = (args['seatSelections'] as List<dynamic>?) ?? [];
      _seatSelections =
          rawSeats.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    }

    // Use the pre-calculated baseFare from checkout (already applies
    // concessions: ADULT=100%, CHILD_3_10=50%, INFANT=free).
    // Fall back to local calculation only if baseFare was not passed.
    final preCalcBaseFare = args['baseFare'] as double?;
    if (preCalcBaseFare != null) {
      _baseFare = preCalcBaseFare;
    } else if (_train != null) {
      // Fallback recalculation
      double baseTicketPrice;
      if (_isRoundTrip) {
        final outPrice = args['outPrice'] as double? ?? 0.0;
        final retPrice = args['retPrice'] as double? ?? 0.0;
        baseTicketPrice = outPrice + retPrice;
      } else {
        baseTicketPrice = _train!.classPrices[_selectedClass] ?? 0.0;
      }
      _baseFare =
          (baseTicketPrice * _adults) + (baseTicketPrice * 0.5 * _children);
    }

    // Reservation fee: Rs. 0 for online bookings (included in base fare)
    final ticketCount = _adults + _children;
    _reservationCharges = 0.0 * ticketCount;

    // Service fee: flat Rs. 100 per booking
    _serviceFee = 100.0;
    _transferFee = (args['transferFee'] as num?)?.toDouble() ?? 0;
  }

  void _updatePaymentMethodFees(String method) {
    setState(() {
      switch (method) {
        case 'card':
          _paymentMethodFee = 74.0;
          break;
        case 'jazzcash':
        case 'easypaisa':
          _paymentMethodFee = 24.0;
          break;
        default:
          _paymentMethodFee = 0.0;
      }
    });
  }

  String _formatPKR(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return 'PKR ${formatter.format(amount)}';
  }

  void _startOTPTimer() {
    _otpRemainingSeconds = 27;
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_otpRemainingSeconds > 0) {
          _otpRemainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _processPayment() {
    if (!_agreedToTerms) {
      setState(() {
        _showTermsError = true;
      });
      return;
    }

    if (_selectedPaymentMethod == 'card') {
      if (_formKey.currentState?.validate() == false) return;
    }

    setState(() {
      _isProcessing = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      final paymentData = {
        'bookingType': 'train',
        'fromStation': _fromStation,
        'toStation': _toStation,
        'fromStationCode': _fromStationCode,
        'toStationCode': _toStationCode,
        'selectedClass': _selectedClass,
        'isRoundTrip': _isRoundTrip,
        'passengers': _passengers,
        'luggageData': _luggageData,
        'contactEmail': _contactEmail,
        'contactPhone': _contactPhone,
        'paymentMethod': _selectedPaymentMethod,
        // Keys payment_status.dart expects:
        'grandTotal': _grandTotal,
        'totalAmount': _grandTotal, // kept for any other readers
        'baseFare': _baseFare,
        'taxes': _reservationCharges, // reservation fee = tax equivalent
        'serviceFee': _serviceFee,
        'baggageFee': 0.0,
        'insuranceFee': 0.0,
        'discount': _discount,
        'departureDate': _departureDate,
        'returnDate': _returnDate,
        'train': _train,
      };

      if (_isRoundTrip) {
        paymentData['outboundTrain'] = _outboundTrain;
        paymentData['returnTrain'] = _returnTrain;
      }

      // ── Generate Pakistan Railways booking references ──────────────────
      // Seed by train number + departure date so same train/date always
      // produces consistent-but-unique references across different sessions.
      final activeTrain = _isRoundTrip ? _outboundTrain : _train;
      final trainNumStr = activeTrain?.trainNumber ?? '';
      final numericPart =
          int.tryParse(trainNumStr.replaceAll(RegExp(r'\D'), '')) ?? 1;
      final dateSeed = (_departureDate?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch) ~/
          1000;
      final rng = math.Random(numericPart * 31 + dateSeed);

      // 10-digit PNR (Pakistan Railways standard)
      final pnr = (1000000000 + rng.nextInt(900000000)).toString();

      // Transaction ID: TXN-YYYY-8digits
      final year = DateTime.now().year;
      final txnId =
          'TXN-$year-${rng.nextInt(99999999).toString().padLeft(8, '0')}';

      // Extract actual seat selections
      List<String> seatNumbers = [];
      String coach = 'B-1'; // Default coach

      if (_isRoundTrip && _outboundSeatSelections.isNotEmpty) {
        // Use outbound seats for primary display (return seats stored separately)
        coach = (_outboundSeatSelections[0]['coach'] ?? 'B-1').toString();
        seatNumbers = _outboundSeatSelections
            .map((s) => (s['seatName'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toList();
      } else if (_seatSelections.isNotEmpty) {
        // One-way trip
        coach = (_seatSelections[0]['coach'] ?? 'B-1').toString();
        seatNumbers = _seatSelections
            .map((s) => (s['seatName'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toList();
      }

      // Fallback to generated seats if no selections
      if (seatNumbers.isEmpty) {
        final firstSeat = rng.nextInt(52) + 1;
        seatNumbers = List<String>.generate(
            _passengers.length, (i) => '${firstSeat + i}');
        coach = 'B-${rng.nextInt(8) + 1}';
      }

      // Ticket numbers: STATIONCODE-YEAR-6digits (unique per passenger)
      final stationCode =
          _fromStationCode.isNotEmpty ? _fromStationCode : 'PKR';
      final ticketNumbers = List<String>.generate(_passengers.length, (i) {
        final seq = (rng.nextInt(899999) + 100000);
        return '$stationCode-$year-$seq';
      });

      paymentData['pnr'] = pnr;
      paymentData['transactionId'] = txnId;
      paymentData['coach'] = coach;
      paymentData['seatNumbers'] = seatNumbers;
      paymentData['ticketNumbers'] = ticketNumbers;

      // Pass seat selections to payment status for round trip PDF generation
      if (_isRoundTrip) {
        paymentData['outboundSeatSelections'] = _outboundSeatSelections;
        paymentData['returnSeatSelections'] = _returnSeatSelections;
      } else {
        paymentData['seatSelections'] = _seatSelections;
      }
      // ──────────────────────────────────────────────────────────────────

      Get.toNamed(AppLink.paymentStatus, arguments: paymentData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderSummary(),
                  const SizedBox(height: 16),
                  _buildPaymentMethods(),
                  const SizedBox(height: 16),
                  if (_selectedPaymentMethod == 'card') ...[
                    _buildCardForm(),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedPaymentMethod == 'easypaisa') ...[
                    _buildEasypaisaForm(),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedPaymentMethod == 'jazzcash') ...[
                    _buildJazzcashForm(),
                    const SizedBox(height: 16),
                  ],
                  _buildPriceBreakdown(),
                  const SizedBox(height: 16),
                  _buildSecurityBadges(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // APP BAR
  // ────────────────────────────────────────────────────────────
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
        'Payment',
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

  // ────────────────────────────────────────────────────────────
  // STEPPER
  // ────────────────────────────────────────────────────────────
  Widget _buildStepper() {
    const steps = ['PASSENGERS', 'FACILITIES', 'CHECKOUT', 'PAYMENT', 'DONE'];
    const goldColor = Color(0xFFD4AF37);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(9, (i) {
          if (i.isOdd) {
            final stepBefore = i ~/ 2;
            final isCompleted = stepBefore < 3;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: isCompleted ? goldColor : const Color(0xFFE0E0E0),
              ),
            );
          }
          final index = i ~/ 2;
          final isActive = index == 3; // PAYMENT
          final isCompleted = index < 3;

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

  // ────────────────────────────────────────────────────────────
  // ORDER SUMMARY
  // ────────────────────────────────────────────────────────────
  Widget _buildOrderSummary() {
    const summaryColor = Color(0xFFD4AF37);
    const summaryIcon = Icons.train_rounded;
    const summaryTitle = 'Train Summary';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [summaryColor, Color(0xFFB8935C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(summaryIcon, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  summaryTitle,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildTrainSummaryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainSummaryContent() {
    final departureTrain = _isRoundTrip ? (_outboundTrain ?? _train) : _train;
    if (departureTrain == null) {
      return const Center(
        child: Text(
          'Train details unavailable',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
      );
    }
    return Column(
      children: [
        // Departure
        _buildProfessionalTrainCard(
          train: departureTrain,
          label: 'Departure',
          date: _departureDate,
          fromStation: _fromStation,
          toStation: _toStation,
          fromCode: _fromStationCode,
          toCode: _toStationCode,
          seatClass: _isRoundTrip
              ? (_outboundClass ?? _selectedClass)
              : _selectedClass,
        ),
        // Return (round trip)
        if (_isRoundTrip && _returnTrain != null) ...[
          const SizedBox(height: 20),
          _buildProfessionalTrainCard(
            train: _returnTrain!,
            label: 'Return',
            date: _returnDate,
            fromStation: _toStation,
            toStation: _fromStation,
            fromCode: _toStationCode,
            toCode: _fromStationCode,
            seatClass: _returnClass ?? _selectedClass,
          ),
        ],
      ],
    );
  }

  Widget _buildProfessionalTrainCard({
    required TrainResult train,
    required String label,
    required DateTime? date,
    required String fromStation,
    required String toStation,
    required String fromCode,
    required String toCode,
    required String seatClass,
  }) {
    final formattedDate =
        date != null ? DateFormat('dd MMM yyyy').format(date) : '—';
    const trainGold = Color(0xFFD4AF37);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF5DC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8D5A3)),
          ),
          child: Text(
            '$label - $formattedDate',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD4AF37),
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Route Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Departure side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    train.departureTime,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fromCode.isNotEmpty ? fromCode : fromStation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Duration + Route line
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: trainGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [trainGold, Color(0xFFB8935C)],
                            ),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.train_rounded,
                        size: 20,
                        color: trainGold,
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFB8935C), trainGold],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: trainGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    train.duration,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3),
                    ),
                  ),
                ],
              ),
            ),
            // Arrival side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    train.arrivalTime,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    toCode.isNotEmpty ? toCode : toStation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Train Info Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(
                  Icons.train_rounded,
                  size: 16,
                  color: trainGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      train.trainName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${train.duration} · Train #${train.trainNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFB3B3B3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Info rows
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 14),
        _buildSummaryInfoRow('Passengers', _passengerBreakdownText()),
        const SizedBox(height: 10),
        _buildSummaryInfoRow('From', fromStation),
        const SizedBox(height: 10),
        _buildSummaryInfoRow('To', toStation),
        const SizedBox(height: 10),
        _buildSummaryInfoRow('Seat Class', seatClass),
      ],
    );
  }

  Widget _buildSummaryInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFFB3B3B3),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _passengerBreakdownText() {
    final parts = <String>[];
    if (_adults > 0) parts.add('$_adults Adult${_adults > 1 ? 's' : ''}');
    if (_children > 0) {
      parts.add('$_children Child${_children > 1 ? 'ren' : ''}');
    }
    if (_infants > 0) {
      parts.add('$_infants Infant${_infants > 1 ? 's' : ''}');
    }
    return parts.join(', ');
  }

  // ────────────────────────────────────────────────────────────
  // PAYMENT METHODS (Train: card, jazzcash, easypaisa — no bank transfer)
  // ────────────────────────────────────────────────────────────
  Widget _buildPaymentMethods() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacingUnit(2.5),
              spacingUnit(2.5),
              spacingUnit(2.5),
              spacingUnit(2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF5DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payment_rounded,
                    color: Color(0xFFD4AF37),
                    size: 22,
                  ),
                ),
                SizedBox(width: spacingUnit(1.5)),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Choose how you\'d like to pay',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildPaymentOption(
            'card',
            'Credit / Debit Card',
            'Visa, MasterCard — Rs. 74 gateway fee',
            Icons.credit_card_rounded,
            color: const Color(0xFFD4AF37),
          ),
          Divider(height: 1, color: Colors.grey.shade100, indent: 68),
          _buildPaymentOption(
            'jazzcash',
            'JazzCash',
            'Mobile wallet — Rs. 24 gateway fee',
            Icons.account_balance_wallet_rounded,
            color: const Color(0xFFD4AF37),
          ),
          Divider(height: 1, color: Colors.grey.shade100, indent: 68),
          _buildPaymentOption(
            'easypaisa',
            'EasyPaisa',
            'Mobile wallet — Rs. 24 gateway fee',
            Icons.account_balance_wallet_rounded,
            color: const Color(0xFFD4AF37),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(
    String method,
    String title,
    String subtitle,
    IconData icon, {
    Color? color,
  }) {
    final isSelected = _selectedPaymentMethod == method;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
          _updatePaymentMethodFees(method);
        });
      },
      child: Container(
        padding: EdgeInsets.all(spacingUnit(2)),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4AF37).withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    (color ?? const Color(0xFFD4AF37)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color ?? const Color(0xFFD4AF37),
                size: 24,
              ),
            ),
            SizedBox(width: spacingUnit(1.5)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB3B3B3),
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: method,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                  _updatePaymentMethodFees(value);
                });
              },
              activeColor: const Color(0xFFD4AF37),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // CARD FORM
  // ────────────────────────────────────────────────────────────
  // ── Detected card network for dynamic logo highlighting ──────────────────
  String? _cardNetwork;

  void _onCardNumberChanged(String v) {
    final digits = v.replaceAll(' ', '');
    String? network;
    if (digits.isEmpty) {
      network = null;
    } else if (digits.startsWith('4')) {
      network = 'visa';
    } else if (digits.startsWith('5') || digits.startsWith('2')) {
      network = 'mastercard';
    } else if (digits.startsWith('3')) {
      network = 'amex';
    } else {
      network = 'other';
    }
    if (network != _cardNetwork) setState(() => _cardNetwork = network);
    // also trigger _isPaymentDetailsValid refresh
    setState(() {});
  }

  Widget _buildCardForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Enter Card Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E6D3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE6C68E)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 12, color: Color(0xFFD4AF37)),
                        SizedBox(width: 4),
                        Text(
                          'Secure',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Dynamic card network logos ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedOpacity(
                        opacity:
                            (_cardNetwork == null || _cardNetwork == 'visa')
                                ? 1.0
                                : 0.25,
                        duration: const Duration(milliseconds: 200),
                        child: _buildVisaLogo(),
                      ),
                      const SizedBox(width: 6),
                      AnimatedOpacity(
                        opacity: (_cardNetwork == null ||
                                _cardNetwork == 'mastercard')
                            ? 1.0
                            : 0.25,
                        duration: const Duration(milliseconds: 200),
                        child: _buildMastercardLogo(),
                      ),
                      const SizedBox(width: 6),
                      AnimatedOpacity(
                        opacity:
                            (_cardNetwork == null || _cardNetwork == 'amex')
                                ? 1.0
                                : 0.25,
                        duration: const Duration(milliseconds: 200),
                        child: _buildCardLogo('AMEX', const Color(0xFF006FCF)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Credit Card Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.black),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    autofillHints: const [AutofillHints.creditCardNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                      _CardNumberInputFormatter(),
                    ],
                    onChanged: _onCardNumberChanged,
                    validator: (value) =>
                        DSValidators.cardNumber(value?.replaceAll(' ', '')),
                    decoration: InputDecoration(
                      hintText: '1234 1234 1234 1234',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: colorScheme(context).primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.red, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expiry Date',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB3B3B3),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _expiryController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.black),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              autofillHints: const [
                                AutofillHints.creditCardExpirationDate
                              ],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                                _ExpiryDateInputFormatter(),
                              ],
                              onChanged: (_) => setState(() {}),
                              validator: DSValidators.cardExpiry,
                              decoration: InputDecoration(
                                hintText: 'MM/YY',
                                hintStyle: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 15),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: colorScheme(context).primary,
                                      width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.red),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
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
                              'CVC',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB3B3B3),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _cvvController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              style: const TextStyle(color: Colors.black),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              // AMEX uses 4 digits; all others use 3
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              onChanged: (_) => setState(() {}),
                              validator: DSValidators.cvv,
                              decoration: InputDecoration(
                                hintText: '•••',
                                hintStyle: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 15),
                                suffixIcon: Tooltip(
                                  message: '3–4 digits on back of card',
                                  child: Icon(Icons.help_outline,
                                      size: 18, color: Colors.grey.shade500),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: colorScheme(context).primary,
                                      width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.red),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── Cardholder name ──────────────────────────────────────
                  const Text(
                    'CARDHOLDER NAME',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _cardNameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.black),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    autofillHints: const [AutofillHints.creditCardName],
                    onChanged: (_) => setState(() {}),
                    validator: DSValidators.cardholderName,
                    decoration: InputDecoration(
                      hintText: 'Name as printed on card',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 15),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: colorScheme(context).primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.red, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _saveCard = !_saveCard;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _saveCard
                                  ? colorScheme(context).primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _saveCard
                                    ? colorScheme(context).primary
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: _saveCard
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Save card for future payments',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF5DC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE8D5A3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: ThemePalette.primaryMain),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your payment is secured with 256-bit SSL encryption',
                            style: TextStyle(
                              fontSize: 12,
                              color: ThemePalette.primaryMain,
                              height: 1.4,
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
        ),
      ),
    );
  }

  Widget _buildVisaLogo() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Image.asset(
        'assets/images/visa.png',
        height: 18,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildMastercardLogo() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Image.asset(
        'assets/images/master_card.png',
        height: 18,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildCardLogo(String fallbackText, Color brandColor) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: brandColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          fallbackText,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // EASYPAISA FORM
  // ────────────────────────────────────────────────────────────
  Widget _buildEasypaisaForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Add New Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = '';
                      _showEasypaisaOTP = false;
                    });
                  },
                  child: const Icon(Icons.close,
                      size: 24, color: Color(0xFFB3B3B3)),
                ),
              ],
            ),
          ),
          if (!_showEasypaisaOTP)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phone Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _easypaisaPhoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.black),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      _NoLeadingZeroFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: '3001234567',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                      ),
                      prefixIcon: PopupMenuButton<String>(
                        offset: const Offset(0, 50),
                        onSelected: (value) {
                          setState(() {
                            _selectedCountryCode = value;
                          });
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: '+92',
                            child: Row(
                              children: [
                                const Text('🇵🇰',
                                    style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Text(
                                  'Pakistan (پاکستان) $_selectedCountryCode',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🇵🇰', style: TextStyle(fontSize: 24)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_drop_down,
                                  size: 20, color: Color(0xFFB3B3B3)),
                            ],
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFC6A75E), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DSButton(
                    label: 'Get Code',
                    onTap: () {
                      if (_easypaisaPhoneController.text.isNotEmpty) {
                        setState(() {
                          _showEasypaisaOTP = true;
                        });
                        _startOTPTimer();
                      }
                    },
                    height: 50,
                  ),
                ],
              ),
            )
          else
            _buildOTPVerification('Easypaisa', _easypaisaPhoneController.text),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // JAZZCASH FORM
  // ────────────────────────────────────────────────────────────
  Widget _buildJazzcashForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Add New Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = '';
                      _showJazzcashOTP = false;
                    });
                  },
                  child: const Icon(Icons.close,
                      size: 24, color: Color(0xFFB3B3B3)),
                ),
              ],
            ),
          ),
          if (!_showJazzcashOTP)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phone Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _jazzcashPhoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.black),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      _NoLeadingZeroFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: '3001234567',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                      ),
                      prefixIcon: PopupMenuButton<String>(
                        offset: const Offset(0, 50),
                        onSelected: (value) {
                          setState(() {
                            _selectedCountryCode = value;
                          });
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: '+92',
                            child: Row(
                              children: [
                                const Text('🇵🇰',
                                    style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Text(
                                  'Pakistan (پاکستان) $_selectedCountryCode',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🇵🇰', style: TextStyle(fontSize: 24)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_drop_down,
                                  size: 20, color: Color(0xFFB3B3B3)),
                            ],
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.red.shade600, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DSButton(
                    label: 'Get Code',
                    onTap: () {
                      if (_jazzcashPhoneController.text.isNotEmpty) {
                        setState(() {
                          _showJazzcashOTP = true;
                        });
                        _startOTPTimer();
                      }
                    },
                    height: 50,
                  ),
                ],
              ),
            )
          else
            _buildOTPVerification('JazzCash', _jazzcashPhoneController.text),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // OTP VERIFICATION
  // ────────────────────────────────────────────────────────────
  Widget _buildOTPVerification(String paymentMethod, String phoneNumber) {
    final formattedPhone =
        '$_selectedCountryCode ${phoneNumber.substring(0, math.min(3, phoneNumber.length))} ${phoneNumber.length > 3 ? phoneNumber.substring(3) : ''}';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.5),
              children: [
                const TextSpan(text: 'We have sent an OTP on your '),
                TextSpan(
                  text: formattedPhone,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' mobile number.'),
                const TextSpan(
                  text: 'Change Number',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E6D3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE6C68E)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Color(0xFFD4AF37)),
                SizedBox(width: 12),
                Text(
                  'An OTP has been sent.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (index) => Container(
                width: 45,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                ),
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  onChanged: (value) {
                    if (value.length == 1 && index < 5) {
                      FocusScope.of(context).nextFocus();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const DSButton(
            label: 'Verify & Pay',
            onTap: null,
            disabled: true,
            height: 50,
          ),
          const SizedBox(height: 16),
          Center(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  const TextSpan(text: 'Unable to receive an OTP? '),
                  TextSpan(
                    text: _otpRemainingSeconds > 0
                        ? 'Select Method in ${_otpRemainingSeconds}s'
                        : 'Resend OTP',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.w600,
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

  // ────────────────────────────────────────────────────────────
  // PRICE BREAKDOWN (Train)
  // ────────────────────────────────────────────────────────────
  Widget _buildPriceBreakdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isPriceBreakdownExpanded = !_isPriceBreakdownExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(spacingUnit(2)),
              child: Row(
                children: [
                  const Icon(Icons.receipt_outlined,
                      color: Color(0xFFD4AF37), size: 22),
                  SizedBox(width: spacingUnit(1.5)),
                  const Expanded(
                    child: Text(
                      'Price Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    _formatPKR(_grandTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  SizedBox(width: spacingUnit(1)),
                  Icon(
                    _isPriceBreakdownExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFB3B3B3),
                  ),
                ],
              ),
            ),
          ),
          if (_isPriceBreakdownExpanded) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: EdgeInsets.all(spacingUnit(2)),
              child: Column(
                children: [
                  ..._buildTrainTicketBreakdown(),
                  _buildPriceRow('Reservation Fee', _reservationCharges),
                  _buildPriceRow('Service Fee', _serviceFee),
                  if (_transferFee > 0)
                    _buildPriceRow('Station Transfer', _transferFee),
                  if (_paymentMethodFee > 0)
                    _buildPriceRow('Payment Gateway Fee', _paymentMethodFee),
                  if (_discount > 0)
                    _buildPriceRow('Discount', -_discount, isDiscount: true),
                  Divider(height: spacingUnit(2), color: Colors.grey.shade300),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _formatPKR(_grandTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount,
      {bool isDiscount = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacingUnit(0.7)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFFB3B3B3)),
          ),
          Text(
            _formatPKR(amount.abs()),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount ? const Color(0xFFD4AF37) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTrainTicketBreakdown() {
    final List<Widget> breakdown = [];
    if (_train == null) return breakdown;

    double basePrice;
    if (_isRoundTrip) {
      final args = Get.arguments as Map<String, dynamic>? ?? {};
      final outPrice = args['outPrice'] as double? ?? 0.0;
      final retPrice = args['retPrice'] as double? ?? 0.0;
      basePrice = outPrice + retPrice;
    } else {
      basePrice = _train!.classPrices[_selectedClass] ?? 0.0;
    }

    if (_adults > 0) {
      final adultTotal = basePrice * _adults;
      breakdown.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacingUnit(0.7)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$_adults ${_adults == 1 ? 'Adult' : 'Adults'} × ${_formatPKR(basePrice)}',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFFB3B3B3)),
                ),
              ),
              Text(
                _formatPKR(adultTotal),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      );
    }

    if (_children > 0) {
      final childPrice = basePrice * 0.5;
      final childTotal = childPrice * _children;
      breakdown.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacingUnit(0.7)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFFB3B3B3)),
                    children: [
                      TextSpan(
                        text:
                            '$_children ${_children == 1 ? 'Child' : 'Children'} × ${_formatPKR(childPrice)} ',
                      ),
                      const TextSpan(
                        text: '(50% off)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _formatPKR(childTotal),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      );
    }

    if (_infants > 0) {
      breakdown.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacingUnit(0.7)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFFB3B3B3)),
                    children: [
                      TextSpan(
                          text:
                              '$_infants ${_infants == 1 ? 'Infant' : 'Infants'} '),
                      const TextSpan(
                        text: '(Free)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(_formatPKR(0.0),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
        ),
      );
    }

    if (breakdown.isNotEmpty) {
      breakdown.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacingUnit(0.5)),
          child: Divider(height: 1, color: Colors.grey.shade300),
        ),
      );
      breakdown.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacingUnit(0.7)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ticket Total',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3))),
              Text(_formatPKR(_baseFare),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
            ],
          ),
        ),
      );
    }

    return breakdown;
  }

  // ────────────────────────────────────────────────────────────
  // POLICIES (Train-specific)
  // ────────────────────────────────────────────────────────────
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
            padding: EdgeInsets.all(spacingUnit(2.5)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF5DC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.policy_rounded,
                    color: ThemePalette.primaryMain,
                    size: 22,
                  ),
                ),
                SizedBox(width: spacingUnit(1.5)),
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
            padding: EdgeInsets.fromLTRB(
              spacingUnit(2.5),
              spacingUnit(2),
              spacingUnit(2.5),
              spacingUnit(1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.orange.shade700),
                    SizedBox(width: spacingUnit(1)),
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
                SizedBox(height: spacingUnit(1.5)),
                _buildNoticePoint(
                    'Carry valid CNIC/Passport matching your booking name at boarding'),
                SizedBox(height: spacingUnit(1)),
                _buildNoticePoint(
                    'Arrive at station 30 minutes before departure time'),
                SizedBox(height: spacingUnit(1)),
                _buildNoticePoint(
                    'No cancellation within 2 hours of departure'),
                SizedBox(height: spacingUnit(1)),
                _buildNoticePoint(
                    'Service fees (Rs. 100) and gateway fees are non-refundable'),
                SizedBox(height: spacingUnit(1)),
                _buildNoticePoint(
                    'Refunds processed in 7-14 working days to original payment method'),
                SizedBox(height: spacingUnit(1)),
                _buildNoticePoint(
                    'Check PNR status before traveling - Pakistan Railways may reschedule'),
                SizedBox(height: spacingUnit(1)),
                _buildNoticePoint(
                    'Tickets are non-transferable and valid only for booked train/date/class'),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          // Payment section
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacingUnit(2.5),
              spacingUnit(2),
              spacingUnit(2.5),
              spacingUnit(2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment_rounded,
                        size: 18, color: ThemePalette.primaryMain),
                    SizedBox(width: spacingUnit(1)),
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
                SizedBox(height: spacingUnit(1.5)),
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
            padding: EdgeInsets.fromLTRB(
              spacingUnit(2.5),
              spacingUnit(2),
              spacingUnit(2.5),
              spacingUnit(2.5),
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
                                ? ThemePalette.primaryMain
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _showTermsError
                                  ? Colors.red.shade400
                                  : _agreedToTerms
                                      ? ThemePalette.primaryMain
                                      : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: _agreedToTerms
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                        SizedBox(width: spacingUnit(1.5)),
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
                                      child: Text(
                                        'Terms & Conditions',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: ThemePalette.primaryMain,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () => _showPrivacyPolicyModal(),
                                      child: Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: ThemePalette.primaryMain,
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
                  SizedBox(height: spacingUnit(1)),
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 16, color: Colors.red.shade600),
                      SizedBox(width: spacingUnit(0.7)),
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
          padding: EdgeInsets.symmetric(
            horizontal: spacingUnit(2.5),
            vertical: spacingUnit(2),
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
              SizedBox(width: spacingUnit(1.5)),
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
        SizedBox(width: spacingUnit(1.5)),
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

  // ────────────────────────────────────────────────────────────
  // POLICY MODALS (Train-specific)
  // ────────────────────────────────────────────────────────────
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
                padding: EdgeInsets.fromLTRB(
                  spacingUnit(3),
                  spacingUnit(1),
                  spacingUnit(1),
                  spacingUnit(2),
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
                  padding: EdgeInsets.all(spacingUnit(3)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        'Cancellation Before Departure',
                        'Cancellation must be made at least 2 hours before the scheduled departure time. Cancellations within 2 hours of departure are not permitted.',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Refund Amount',
                        'Full ticket fare minus service charges will be refunded:\n• Reservation Fee (Rs. 0): No charge for online bookings\n• Service Fee (Rs. 100): Non-refundable\n• Payment Gateway Fee (Rs. 24-74): Non-refundable',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Processing Time',
                        'Refunds are processed within 7 working days to your original payment method (bank card account). If you do not receive the refund, please contact your payment company.',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Refund Method',
                        'Refunds are automatically credited to the original payment method used during booking. No cash refunds are available.',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
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
                padding: EdgeInsets.fromLTRB(
                  spacingUnit(3),
                  spacingUnit(1),
                  spacingUnit(1),
                  spacingUnit(2),
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
                  padding: EdgeInsets.all(spacingUnit(3)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        '2-Hour Deadline',
                        'Free cancellation is allowed up to 2 hours before the scheduled departure time. No cancellation is permitted within 2 hours of departure.',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Cancellation Charges',
                        'When you cancel before the 2-hour deadline:\n• Ticket Fare: Fully refundable\n• Reservation Fee (Rs. 0): No charge for online bookings\n• Service Fee (Rs. 100): Non-refundable\n• Payment Gateway Fee (Rs. 24-74): Non-refundable',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'How to Cancel',
                        'Log in to your account, navigate to "My Bookings", select your train booking, and click "Cancel Booking". Ensure cancellation is completed at least 2 hours before departure.',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Refund Processing',
                        'Approved refunds are processed within 7 working days to your original payment method. Contact your payment company if you do not receive the refund.',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
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
                padding: EdgeInsets.fromLTRB(
                  spacingUnit(3),
                  spacingUnit(1),
                  spacingUnit(1),
                  spacingUnit(2),
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
                  padding: EdgeInsets.all(spacingUnit(3)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        'Fare Structure',
                        'Pakistan Railways ticket pricing includes:\n• Base Fare: Varies by class, route, and distance\n• Reservation Fee: Rs. 0 (included in base fare for online bookings)\n• Service/Convenience Fee: Rs. 100 per booking\n• Payment Gateway Fee: Rs. 24 (JazzCash/Easypaisa) or Rs. 74 (Credit/Debit Card)',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Passenger Concessions',
                        'Age-based discounts apply:\n• Adults (12+ years): 100% of base fare\n• Children (3-11 years): 50% discount on base fare\n• Infants (Under 3 years): Free (no seat allocated)',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Ticket Validity & Changes',
                        'Train tickets are valid only for the specific train, date, and class booked. Date changes and modifications are not permitted. Passengers must cancel and rebook if needed.',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Name Policy',
                        'Tickets are issued in the passenger\'s name as provided during booking. Name changes or corrections are not allowed. Tickets are non-transferable.',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
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
                padding: EdgeInsets.fromLTRB(
                  spacingUnit(3),
                  spacingUnit(1),
                  spacingUnit(1),
                  spacingUnit(2),
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
                  padding: EdgeInsets.all(spacingUnit(3)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        'Information We Collect',
                        'For train bookings, we collect:\n• Personal Data: Name, CNIC/Passport number, phone number, email, date of birth\n• Payment Data: Card details (encrypted), transaction history\n• Booking Data: Travel dates, routes, passenger details, seat preferences\n• Device Data: IP address, browser type, device information',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'How We Use Your Data',
                        'Your information is used to:\n• Process ticket bookings and payments\n• Send booking confirmations and travel updates via SMS/Email\n• Verify passenger identity at boarding (CNIC verification)\n• Comply with Pakistan Railways regulations\n• Improve our services and user experience\n• Marketing communications (only with your consent)',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Data Protection & Security',
                        'We protect your data through:\n• SSL/TLS encryption for all data transmission\n• PCI-DSS compliant payment gateways\n• Secure servers located in Pakistan\n• No sharing with third parties except payment processors (JazzCash, Easypaisa, banks)\n• Data retention as per Pakistan Railways and SBP regulations',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
                      _buildPolicySection(
                        'Your Rights',
                        'Under Pakistan data protection laws, you have the right to:\n• Access your personal data\n• Request correction or deletion of your data\n• Opt-out of marketing communications\n• File complaints with relevant authorities\n• Withdraw consent for data processing',
                      ),
                      SizedBox(height: spacingUnit(2.5)),
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
              padding: EdgeInsets.fromLTRB(spacingUnit(3), spacingUnit(1),
                  spacingUnit(1), spacingUnit(2)),
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
                padding: EdgeInsets.all(spacingUnit(3)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items
                        .map((item) => Padding(
                              padding:
                                  EdgeInsets.only(bottom: spacingUnit(2.5)),
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
        SizedBox(height: spacingUnit(1)),
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
      padding: EdgeInsets.all(spacingUnit(2.5)),
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
          SizedBox(height: spacingUnit(1.5)),
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

  // ────────────────────────────────────────────────────────────
  // SECURITY BADGES
  // ────────────────────────────────────────────────────────────
  Widget _buildSecurityBadges() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(spacingUnit(2)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSecurityBadge(
                  Icons.verified_user, 'SSL Secured', const Color(0xFFD4AF37)),
              _buildSecurityBadge(
                  Icons.support_agent, '24/7 Support', const Color(0xFFD4AF37)),
              _buildSecurityBadge(
                  Icons.account_balance_wallet, 'Money Back', Colors.orange),
            ],
          ),
          SizedBox(height: spacingUnit(1.5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 14, color: Color(0xFFB3B3B3)),
              SizedBox(width: spacingUnit(0.7)),
              const Text(
                'Your payment information is encrypted and secure',
                style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3)),
              ),
            ],
          ),
          SizedBox(height: spacingUnit(1)),
          const Text(
            '24/7 Customer Support: +92-300-1234567',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB3B3B3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: spacingUnit(0.7)),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB3B3B3),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // BOTTOM BAR
  // ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(spacingUnit(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB3B3B3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPKR(_grandTotal),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                DSButton(
                  label: 'Pay Now',
                  trailingIcon: Icons.arrow_forward_rounded,
                  loading: _isProcessing,
                  disabled: !_isPaymentDetailsValid,
                  onTap: _processPayment,
                  width: 152,
                  height: 52,
                  color: const Color(0xFFD4AF37),
                ),
              ],
            ),
          ],
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

// ────────────────────────────────────────────────────────────
// INPUT FORMATTERS
// ────────────────────────────────────────────────────────────
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── Prevent leading zero in phone number (international format) ────────────

class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // If user tries to type 0 as first character, reject it
    if (newValue.text.startsWith('0')) {
      return oldValue;
    }
    return newValue;
  }
}
