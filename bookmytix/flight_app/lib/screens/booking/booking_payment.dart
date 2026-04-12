import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/widgets/app_button/design_system_button.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/screens/flight/flight_results_screen.dart';
import 'package:flight_app/models/airport.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/design_system_validators.dart';
import 'dart:math' as math;
import 'package:flight_app/ui/themes/theme_system.dart';

class BookingPayment extends StatefulWidget {
  const BookingPayment({super.key});

  @override
  State<BookingPayment> createState() => _BookingPaymentState();
}

class _BookingPaymentState extends State<BookingPayment>
    with TickerProviderStateMixin {
  // Arguments from previous screen (Flights)
  FlightResult? _flight;
  late Map<String, dynamic> _searchParams;
  late List<Map<String, dynamic>> _passengers;
  late List<Map<String, dynamic>> _baggageData;
  Airport? _fromAirport;
  Airport? _toAirport;
  late DateTime _departureDate;
  int _adults = 1;
  int _children = 0;
  int _infants = 0;

  // Round trip support (Flights)
  bool _isRoundTrip = false;
  FlightResult? _outboundFlight;
  FlightResult? _returnFlight;
  DateTime? _returnDate;

  // Contact information
  String _contactEmail = '';
  String _contactPhone = '';

  // Seat selections (from booking_checkout)
  List<Map<String, dynamic>> _seatSelections = [];
  List<Map<String, dynamic>> _outboundSeatSelections = [];
  List<Map<String, dynamic>> _returnSeatSelections = [];
  double _seatTotal = 0;

  // Payment state
  String _selectedPaymentMethod = '';
  bool _isPriceBreakdownExpanded = false;
  bool _saveCard = false;
  bool _addTravelInsurance = false;
  bool _isProcessing = false;
  String _selectedCountryCode = '+92';
  bool _showEasypaisaOTP = false;
  bool _showJazzcashOTP = false;

  // OTP Timer
  Timer? _otpTimer;
  int _otpRemainingSeconds = 27;

  // OTP state tracking (Easypaisa / JazzCash)
  String _otpValue = '';
  bool _isOtpVerified = false;

  // Scroll controllers — one per modal sheet to prevent shared-controller crash
  final ScrollController _refundScrollController = ScrollController();
  final ScrollController _cancellationScrollController = ScrollController();
  final ScrollController _fareRulesScrollController = ScrollController();
  final ScrollController _privacyScrollController = ScrollController();
  final ScrollController _termsScrollController = ScrollController();

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _easypaisaPhoneController = TextEditingController();
  final _jazzcashPhoneController = TextEditingController();

  // Price calculations
  double _baseFare = 0;
  double _taxes = 0; // total of all 3 components below
  double _taxFED = 0; // Federal Excise Duty  — 16 % of base fare
  double _taxAirportFee = 0; // Airport Development Fee — PKR 200 / pax
  double _taxSecurityFee = 0; // Aviation Security Fee   — PKR 150 / pax
  double _serviceFee = 500; // Dynamic based on payment method
  double _paymentMethodFee = 0; // Additional fee based on payment method
  double _baggageFee = 0;
  double _transferFee = 0; // Airport transfer add-on
  double _discount = 0;
  double _insuranceFee = 1500;
  List<Map<String, dynamic>> _returnBaggageData = [];
  double get _grandTotal =>
      _baseFare +
      _taxes +
      _serviceFee +
      _paymentMethodFee +
      _baggageFee +
      _seatTotal +
      _transferFee +
      (_addTravelInsurance ? _insuranceFee : 0) -
      _discount;

  // Detected card network for dynamic logo highlighting
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
    setState(() {});
  }

  bool get _isPaymentDetailsValid {
    // Terms are validated on tap (not here), so button enables once
    // payment details are filled — _processPayment handles terms check.
    if (_selectedPaymentMethod.isEmpty) return false;

    if (_selectedPaymentMethod == 'card') {
      final cardDigits = _cardNumberController.text.replaceAll(' ', '');
      return DSValidators.cardNumber(cardDigits) == null &&
          DSValidators.cardExpiry(_expiryController.text) == null &&
          DSValidators.cvv(_cvvController.text.trim()) == null &&
          DSValidators.cardholderName(_cardNameController.text.trim()) == null;
    } else if (_selectedPaymentMethod == 'easypaisa') {
      // Phone was proven valid when OTP was sent — only gate on verification
      return _isOtpVerified;
    } else if (_selectedPaymentMethod == 'jazzcash') {
      // Phone was proven valid when OTP was sent — only gate on verification
      return _isOtpVerified;
    }

    // For other payment methods (bank transfer, etc.) that don't require form validation
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadArguments();
    // _startTimer(); // Timer disabled

    // Add listeners to update button state when payment details change
    _cardNumberController.addListener(() => setState(() {}));
    _expiryController.addListener(() => setState(() {}));
    _cvvController.addListener(() => setState(() {}));
    _cardNameController.addListener(() => setState(() {}));
    _easypaisaPhoneController.addListener(() => setState(() {}));
    _jazzcashPhoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // _timer.cancel(); // Timer disabled
    _otpTimer?.cancel();
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _easypaisaPhoneController.dispose();
    _jazzcashPhoneController.dispose();
    _refundScrollController.dispose();
    _cancellationScrollController.dispose();
    _fareRulesScrollController.dispose();
    _privacyScrollController.dispose();
    _termsScrollController.dispose();
    super.dispose();
  }

  void _loadArguments() {
    final args = Get.arguments as Map<String, dynamic>?;

    // Handle null arguments (e.g., during hot restart)
    if (args == null) {
      return;
    }

    // Common data
    final passList = args['passengers'] as List<dynamic>?;
    _passengers =
        passList?.map((p) => Map<String, dynamic>.from(p as Map)).toList() ??
            [];
    _isRoundTrip = args['isRoundTrip'] ?? false;
    _returnDate = args['returnDate'] as DateTime?;
    _contactEmail = args['contactEmail'] as String? ?? '';
    _contactPhone = args['contactPhone'] as String? ?? '';

    // Load seat selections
    final seatsList = args['seatSelections'] as List<dynamic>?;
    _seatSelections =
        seatsList?.map((s) => Map<String, dynamic>.from(s as Map)).toList() ??
            [];
    final outboundSeatsList = args['outboundSeatSelections'] as List<dynamic>?;
    _outboundSeatSelections = outboundSeatsList
            ?.map((s) => Map<String, dynamic>.from(s as Map))
            .toList() ??
        [];
    final returnSeatsList = args['returnSeatSelections'] as List<dynamic>?;
    _returnSeatSelections = returnSeatsList
            ?.map((s) => Map<String, dynamic>.from(s as Map))
            .toList() ??
        [];
    _seatTotal = (args['seatTotal'] as num?)?.toDouble() ?? 0;
    _discount = (args['discount'] as num?)?.toDouble() ?? 0;

    // Load return baggage data
    final rawReturnBaggage =
        (args['returnBaggageData'] as List<dynamic>?) ?? [];
    _returnBaggageData = rawReturnBaggage
        .map((b) => Map<String, dynamic>.from(b as Map))
        .toList();

    // Load flight data
    _flight = args['flight'] as FlightResult;
    _searchParams = args['searchParams'] as Map<String, dynamic>;
    final bagRaw = (args['baggageData'] as List<dynamic>?) ?? [];
    _baggageData =
        bagRaw.map((b) => Map<String, dynamic>.from(b as Map)).toList();

    // Load airports from search params
    _fromAirport = _searchParams['fromAirport'] as Airport? ??
        Airport(id: '0', code: 'DEP', name: 'Departure', location: 'Departure');
    _toAirport = _searchParams['toAirport'] as Airport? ??
        Airport(id: '0', code: 'ARR', name: 'Arrival', location: 'Arrival');
    _departureDate =
        _searchParams['departureDate'] as DateTime? ?? DateTime.now();

    _adults = (_searchParams['adults'] as int?) ?? 1;
    _children = (_searchParams['children'] as int?) ?? 0;
    _infants = (_searchParams['infants'] as int?) ?? 0;

    // Round trip support
    _outboundFlight = args['outboundFlight'] as FlightResult?;
    _returnFlight = args['returnFlight'] as FlightResult?;

    // Calculate price breakdown for flights
    final passengerCount = _passengers.length;
    if (_isRoundTrip && _outboundFlight != null && _returnFlight != null) {
      _baseFare =
          (_outboundFlight!.price + _returnFlight!.price) * passengerCount;
    } else if (_flight != null) {
      _baseFare = _flight!.price * passengerCount;
    }
    // ── Pakistan domestic aviation taxes (Finance Act / CAA) ─────────────
    _taxFED = _baseFare * 0.16; // FED 16 % on base fare
    _taxAirportFee = 200.0 * passengerCount; // Airport Development Fee
    _taxSecurityFee = 150.0 * passengerCount; // Aviation Security Fee
    _taxes = _taxFED + _taxAirportFee + _taxSecurityFee;

    _serviceFee = 500.0;
    _paymentMethodFee = 0.0;
    _insuranceFee = 1500.0 * passengerCount; // Per-person insurance fee
    // Calculate baggage fee
    _baggageFee = _baggageData.fold<double>(
      0,
      (sum, passenger) =>
          sum + ((passenger['extraPrice'] as num?) ?? 0).toDouble(),
    );
    _transferFee = (args['transferFee'] as num?)?.toDouble() ?? 0;
  }

  void _startOTPTimer() {
    _otpTimer?.cancel();
    setState(() {
      _otpRemainingSeconds = 27;
    });
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpRemainingSeconds > 0) {
        setState(() {
          _otpRemainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _updatePaymentMethodFees(String method) {
    // Flight bookings: no gateway fee applied
    _paymentMethodFee = 0.0;
  }

  String _formatPKR(double amount) {
    final formatter = NumberFormat('#,##,###', 'en_PK');
    return 'PKR ${formatter.format(amount.round())}';
  }

  void _processPayment() async {
    if (_selectedPaymentMethod.isEmpty) {
      Get.snackbar(
        'Payment Method Required',
        'Please select a payment method',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade900,
      );
      return;
    }

    if (_selectedPaymentMethod == 'card' &&
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _isProcessing = false;
    });

    // Generate PNR and Transaction ID
    final random = math.Random();
    final pnr = 'TVL${random.nextInt(900000) + 100000}'; // TVL123456
    final transactionId =
        'TXN${DateTime.now().millisecondsSinceEpoch}${random.nextInt(1000)}';

    // Navigate to payment success page (Done page) with all booking data
    final Map<String, dynamic> paymentData = {
      'pnr': pnr,
      'transactionId': transactionId,
      'paymentMethod': _selectedPaymentMethod,
      'passengers': _passengers,
      'grandTotal': _grandTotal,
      'baseFare': _baseFare,
      'taxes': _taxes,
      'serviceFee': _serviceFee,
      'baggageFee': _baggageFee,
      'insuranceFee': _addTravelInsurance ? _insuranceFee : 0.0,
      'discount': _discount,
      'contactEmail': _contactEmail.isNotEmpty ? _contactEmail : 'N/A',
      'contactPhone': _contactPhone.isNotEmpty ? _contactPhone : 'N/A',
      'isRoundTrip': _isRoundTrip,
      'departureDate': _departureDate,
      'returnDate': _returnDate,
    };

    paymentData.addAll({
      'bookingType': 'flight',
      'flight': _flight,
      'outboundFlight': _outboundFlight,
      'returnFlight': _returnFlight,
      'fromAirport': _fromAirport,
      'toAirport': _toAirport,
      'baggageData': _baggageData,
      'returnBaggageData': _returnBaggageData,
      'returnBaggageMode': _returnBaggageData.isNotEmpty
          ? (_returnBaggageData.first['mode'] as String? ?? 'same')
          : 'same',
      'seatSelections': _seatSelections,
      'outboundSeatSelections': _outboundSeatSelections,
      'returnSeatSelections': _returnSeatSelections,
      'seatTotal': _seatTotal,
    });

    Get.toNamed(AppLink.paymentStatus, arguments: paymentData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepper(),
          // _buildTimerBanner(), // Timer disabled
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
                  if (_selectedPaymentMethod == 'bank') ...[
                    _buildBankTransferDetails(),
                    const SizedBox(height: 16),
                  ],
                  _buildTravelInsurance(),
                  const SizedBox(height: 16),
                  _buildPriceBreakdown(),
                  const SizedBox(height: 16),
                  _buildSecurityBadges(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

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

  Widget _buildStepper() {
    const steps = ['PASSENGERS', 'FACILITIES', 'CHECKOUT', 'PAYMENT', 'DONE'];
    const goldColor = Color(0xFFD4AF37);
    final isMobile = MediaQuery.of(context).size.width < 600;

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
            final isCompleted = stepBefore < 3;
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
          final isActive = index == 3; // PAYMENT
          final isCompleted = index < 3;

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
                steps[index],
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

  Widget _buildOrderSummary() {
    const summaryColor = TravelloTheme.primaryMain;
    const summaryIcon = Icons.flight_takeoff_rounded;
    const summaryTitle = 'Flight Summary';

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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  summaryColor,
                  summaryColor.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
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
            child: _buildFlightSummaryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightSummaryContent() {
    return Column(
      children: [
        // Departure Flight
        _buildProfessionalFlightCard(
          flight: _isRoundTrip ? _outboundFlight! : _flight!,
          label: 'Departure',
          date: _departureDate,
          fromAirport: _fromAirport!,
          toAirport: _toAirport!,
        ),
        // Return Flight (if round trip)
        if (_isRoundTrip && _returnFlight != null && _returnDate != null) ...[
          const SizedBox(height: 20),
          _buildProfessionalFlightCard(
            flight: _returnFlight!,
            label: 'Return',
            date: _returnDate!,
            fromAirport: _toAirport!,
            toAirport: _fromAirport!,
          ),
        ],
      ],
    );
  }

  Widget _buildProfessionalFlightCard({
    required FlightResult flight,
    required String label,
    required DateTime date,
    required Airport fromAirport,
    required Airport toAirport,
  }) {
    final formattedDate = DateFormat('dd MMM yyyy').format(date);

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
        // Flight Route
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Departure
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flight.departureTime,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fromAirport.code,
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
            // Flight Duration Line
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
                          color: Color(0xFFD4AF37),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFD4AF37),
                                Color(0xFFB8935C),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: math.pi / 2,
                        child: const Icon(
                          Icons.flight,
                          size: 20,
                          color: TravelloTheme.primaryMain,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFB8935C),
                                Color(0xFFD4AF37),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4AF37),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    flight.duration,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB3B3B3),
                    ),
                  ),
                ],
              ),
            ),
            // Arrival
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    flight.arrivalTime,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    toAirport.code,
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
          ],
        ),
        const SizedBox(height: 14),
        // Airline Info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Airline Logo Placeholder
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(
                  Icons.flight,
                  size: 16,
                  color: TravelloTheme.primaryMain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flight.airlineName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${flight.duration} - Non-Stop',
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
        // Passenger Details Section
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 14),
        _buildInfoRow('Passengers', _passengerBreakdownText()),
        const SizedBox(height: 10),
        _buildInfoRow('Cabin Class', flight.cabinClass),
        const SizedBox(height: 10),
        _buildInfoRow('Baggage', _baggageSummaryText()),
      ],
    );
  }

  String _passengerBreakdownText() {
    // Show detailed breakdown for both trains and flights
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

  String _baggageSummaryText() {
    if (_baggageData.isEmpty) return '—';
    final totals =
        _baggageData.map((b) => (b['totalKg'] as double?) ?? 0).toList();
    final allSame = totals.every((kg) => kg == totals.first);
    if (allSame && totals.first > 0) {
      return '${totals.length} × ${totals.first.toStringAsFixed(0)} kg';
    }
    final totalAll = totals.fold<double>(0, (s, kg) => s + kg);
    return '${totalAll.toStringAsFixed(0)} kg total';
  }

  Widget _buildInfoRow(String label, String value) {
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

  Widget _buildPaymentMethods() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.payment_outlined,
                    color: Color(0xFFD4AF37), size: 22),
                SizedBox(width: 12),
                Text(
                  'Choose Payment Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _buildPaymentOption(
            'card',
            'Credit / Debit Card',
            '(Master and VISA Cards)',
            Icons.credit_card,
            color: const Color(0xFFD4AF37),
          ),
          _buildPaymentOption(
            'jazzcash',
            'JazzCash',
            'Pay with JazzCash wallet',
            Icons.account_balance_wallet,
            color: TravelloTheme.primaryMain,
          ),
          _buildPaymentOption(
            'easypaisa',
            'Easypaisa',
            'Pay with Easypaisa wallet',
            Icons.account_balance_wallet,
            color: const Color(0xFFD4AF37),
          ),
          _buildPaymentOption(
            'bank',
            'Bank Transfer',
            'Direct bank transfer',
            Icons.account_balance,
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
        padding: const EdgeInsets.all(16),
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
                    (color ?? const Color(0xFF1E88E5)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color ?? const Color(0xFF1E88E5),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
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
            RadioGroup<String>(
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                  _updatePaymentMethodFees(value);
                });
              },
              child: Radio<String>(
                value: method,
                activeColor: const Color(0xFF1E88E5),
              ),
            ),
          ],
        ),
      ),
    );
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
            // Header
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
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock,
                            size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Secure',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Form Fields
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic card network logos
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
                  // Card Number
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
                        borderSide: const BorderSide(
                            color: TravelloTheme.primaryMain, width: 2),
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
                  // Expiry and CVC Row
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                                _ExpiryDateInputFormatter(),
                              ],
                              autofillHints: const [
                                AutofillHints.creditCardExpirationDate
                              ],
                              onChanged: (_) => setState(() {}),
                              validator: DSValidators.cardExpiry,
                              decoration: InputDecoration(
                                hintText: 'MM/YY',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 15,
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
                                  borderSide: const BorderSide(
                                      color: TravelloTheme.primaryMain,
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              onChanged: (_) => setState(() {}),
                              validator: DSValidators.cvv,
                              decoration: InputDecoration(
                                hintText: '•••',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 15,
                                ),
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
                                  borderSide: const BorderSide(
                                      color: TravelloTheme.primaryMain,
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
                  // Cardholder Name
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
                        borderSide: const BorderSide(
                            color: TravelloTheme.primaryMain, width: 2),
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
                  // Save Card Checkbox
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
                                  ? TravelloTheme.primaryMain
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _saveCard
                                    ? TravelloTheme.primaryMain
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
                  // Security Notice
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your payment is secured with 256-bit SSL encryption',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
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
          // Header
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
          // Form
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
                                const Icon(Icons.flag, size: 20),
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
                              Icon(
                                Icons.flag,
                                size: 22,
                                color: Color(0xFFB3B3B3),
                              ),
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
                            BorderSide(color: Colors.green.shade600, width: 2),
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
                          _otpValue = '';
                          _isOtpVerified = false;
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
            _buildOTPVerification(
              'Easypaisa',
              _easypaisaPhoneController.text,
              onChangeNumber: () => setState(() {
                _showEasypaisaOTP = false;
                _isOtpVerified = false;
                _otpValue = '';
              }),
            ),
        ],
      ),
    );
  }

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
          // Header
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
          // Form
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
                                const Icon(Icons.flag, size: 20),
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
                              Icon(
                                Icons.flag,
                                size: 22,
                                color: Color(0xFFB3B3B3),
                              ),
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
                          _otpValue = '';
                          _isOtpVerified = false;
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
            _buildOTPVerification(
              'Jazzcash',
              _jazzcashPhoneController.text,
              onChangeNumber: () => setState(() {
                _showJazzcashOTP = false;
                _isOtpVerified = false;
                _otpValue = '';
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildOTPVerification(String paymentMethod, String phoneNumber,
      {required VoidCallback onChangeNumber}) {
    final formattedPhone =
        '$_selectedCountryCode ${phoneNumber.substring(0, 3)} ${phoneNumber.substring(3)}';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // OTP sent message + change number link
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.5),
              children: [
                const TextSpan(text: 'We have sent an OTP on your '),
                TextSpan(
                  text: formattedPhone,
                  style: const TextStyle(
                    color: Color(0xFF1E88E5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' mobile number. '),
                TextSpan(
                  text: 'Change Number',
                  style: const TextStyle(
                    color: Color(0xFF1E88E5),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onChangeNumber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Success message
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 20, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Text(
                  'An OTP has been sent.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // OTP Input Boxes
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
                    setState(() {
                      if (value.length == 1) {
                        if (_otpValue.length < 6) _otpValue += value;
                        if (index < 5) FocusScope.of(context).nextFocus();
                      } else {
                        // digit cleared — rebuild from remaining chars
                        _otpValue = _otpValue.length > index
                            ? _otpValue.substring(0, index)
                            : _otpValue;
                      }
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Step 1: Verify OTP
          if (!_isOtpVerified)
            DSButton(
              label: 'Verify OTP',
              onTap: _otpValue.length == 6
                  ? () => setState(() => _isOtpVerified = true)
                  : null,
              disabled: _otpValue.length < 6,
              height: 50,
            ),
          // Step 2: Pay Now (only after OTP is verified)
          if (_isOtpVerified) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'OTP Verified Successfully',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DSButton(
              label: 'Pay Now',
              onTap: () => _processPayment(),
              height: 50,
            ),
          ],
          const SizedBox(height: 16),
          // Resend OTP
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
                      color: Color(0xFF1E88E5),
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

  Widget _buildBankTransferDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Bank Transfer Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Bank Name', 'Meezan Bank'),
          const SizedBox(height: 12),
          _buildInfoRow('Account Title', 'Travello AI'),
          const SizedBox(height: 12),
          _buildInfoRow('Account Number', '0123456789012'),
          const SizedBox(height: 12),
          _buildInfoRow('IBAN', 'PK12MEZN0000120123456789'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFE65100),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Transfer the amount and share receipt via email',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelInsurance() {
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
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade50,
                  Colors.green.shade50.withValues(alpha: 0.3)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: Colors.green.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Travel Insurance',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Comprehensive trip protection',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB3B3B3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [TravelloTheme.primaryMain, Color(0xFFB8860B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: TravelloTheme.primaryMain.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Protect your trip against unexpected events like flight delays, cancellations, and medical emergencies.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB3B3B3),
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),

                // Benefits Grid
                Column(
                  children: [
                    _buildInsuranceBenefit(
                      Icons.flight_takeoff_rounded,
                      'Flight delay coverage',
                      'Up to PKR 50,000',
                      TravelloTheme.primaryMain,
                    ),
                    const SizedBox(height: 12),
                    _buildInsuranceBenefit(
                      Icons.local_hospital_rounded,
                      'Medical emergency',
                      'Up to PKR 200,000',
                      const Color(0xFFB8860B),
                    ),
                    const SizedBox(height: 12),
                    _buildInsuranceBenefit(
                      Icons.luggage_rounded,
                      'Lost baggage compensation',
                      'Up to PKR 30,000',
                      TravelloTheme.primaryLight,
                    ),
                    const SizedBox(height: 12),
                    _buildInsuranceBenefit(
                      Icons.support_agent_rounded,
                      '24/7 emergency assistance',
                      'Worldwide support',
                      const Color(0xFFC6A75E),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Divider
                Divider(height: 1, color: Colors.grey.shade200),

                const SizedBox(height: 12),

                // Checkbox with Price
                InkWell(
                  onTap: () {
                    setState(() {
                      _addTravelInsurance = !_addTravelInsurance;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _addTravelInsurance
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _addTravelInsurance
                            ? Colors.green.shade300
                            : Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _addTravelInsurance
                                ? Colors.green.shade600
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _addTravelInsurance
                                  ? Colors.green.shade600
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: _addTravelInsurance
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add travel insurance',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'One-time payment per trip',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB3B3B3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatPKR(_insuranceFee),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _addTravelInsurance
                                    ? Colors.green.shade700
                                    : Colors.black87,
                              ),
                            ),
                            const Text(
                              'per booking',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB3B3B3),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildInsuranceBenefit(
      IconData icon, String title, String subtitle, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
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
        Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: Colors.green.shade600,
        ),
      ],
    );
  }

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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.receipt_outlined,
                      color: Color(0xFF1E88E5), size: 22),
                  const SizedBox(width: 12),
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
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(width: 8),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPriceRow('Base Fare', _baseFare),
                  _buildPriceRow('FED (16%)', _taxFED),
                  _buildPriceRow('Airport Development Fee', _taxAirportFee),
                  _buildPriceRow('Aviation Security Fee', _taxSecurityFee),
                  _buildPriceRow('Service Fee', _serviceFee),
                  if (_baggageFee > 0)
                    _buildPriceRow('Baggage Fee', _baggageFee),
                  if (_transferFee > 0)
                    _buildPriceRow('Airport Transfer', _transferFee),
                  if (_addTravelInsurance)
                    _buildPriceRow('Travel Insurance', _insuranceFee),
                  if (_discount > 0)
                    _buildPriceRow('Discount', -_discount, isDiscount: true),
                  Divider(height: 16, color: Colors.grey.shade300),
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
                          color: TravelloTheme.primaryMain,
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
      padding: const EdgeInsets.symmetric(vertical: 5.6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFB3B3B3),
            ),
          ),
          Text(
            _formatPKR(amount.abs()),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount ? Colors.green.shade700 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSecurityBadge(
                  Icons.verified_user, 'SSL Secured', Colors.green),
              _buildSecurityBadge(
                  Icons.support_agent, '24/7 Support', Colors.blue),
              _buildSecurityBadge(
                  Icons.account_balance_wallet, 'Money Back', Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 14, color: Color(0xFFB3B3B3)),
              SizedBox(width: 5.6),
              Text(
                'Your payment information is encrypted and secure',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB3B3B3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
        const SizedBox(height: 5.6),
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

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Card number input formatter
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Expiry date input formatter
class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
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
