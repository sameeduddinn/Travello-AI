import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flight_app/screens/orders/hotel_booking_confirmation.dart';
import 'package:flight_app/utils/design_system_validators.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PaymentScreenProfessional extends StatefulWidget {
  const PaymentScreenProfessional({super.key});

  @override
  State<PaymentScreenProfessional> createState() =>
      _PaymentScreenProfessionalState();
}

class _PaymentScreenProfessionalState extends State<PaymentScreenProfessional> {
  late Map<String, dynamic> bookingData;
  late String bookingType; // 'flight', 'train', 'hotel', or 'transport'
  late double totalPrice;

  final _formKey = GlobalKey<FormState>();
  final _mobileFormKey = GlobalKey<FormState>();

  String _selectedPaymentMethod = 'Card';

  // Card details
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  // Mobile wallet
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  bool _saveCard = false;
  bool _isProcessing = false;

  // Mobile wallet OTP state
  bool _showWalletOTP = false;
  String _otpValue = '';
  bool _isOtpVerified = false;
  // Detected network prefix for dynamic logo highlighting
  String? _cardNetwork;
  bool _showOutboundDetails = false;
  bool _showReturnDetails = false;
  bool _showTrainDetails = false;

  @override
  void initState() {
    super.initState();
    bookingData = Get.arguments ?? {};
    bookingType = bookingData['bookingType'] ?? 'flight';
    totalPrice = bookingData['totalPrice'] ?? 0.0;

    // For hotel bookings, taxes (5% + 3% + 16% = 24%) are added on top of
    // the base room price. Recompute so Total Amount reflects the real charge.
    if (bookingType == 'hotel') {
      final base = (bookingData['basePrice'] as num?)?.toDouble() ?? totalPrice;
      final extras = (bookingData['extrasTotal'] as num?)?.toDouble() ?? 0.0;
      final protection = bookingData['protectionPlan'] == true
          ? ((bookingData['protectionPlanCost'] as num?)?.toDouble() ?? 0.0)
          : 0.0;
      totalPrice = base * 1.24 + extras + protection;
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _mobileNumberController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool get _canPay {
    if (_selectedPaymentMethod == 'JazzCash' ||
        _selectedPaymentMethod == 'Easypaisa') {
      return _isOtpVerified &&
          _isValidPkWalletPhone(_mobileNumberController.text);
    }
    return true;
  }

  bool _isValidPkWalletPhone(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    return clean.length == 10 && clean.startsWith('3');
  }

  void _processPayment() {
    // Validate the active form based on payment method
    final isCardMethod = _selectedPaymentMethod == 'Card';
    final activeKey = isCardMethod ? _formKey : _mobileFormKey;
    if (!(activeKey.currentState?.validate() ?? true)) {
      // If form is not valid, show error message
      Get.snackbar(
        'Validation Error',
        'Please fill in all required fields correctly',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final nav = Navigator.of(context);

    // Simulate payment processing
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isProcessing = false);

      final ref =
          'HTL${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // For hotel bookings navigate directly — no popup dialog
      if (bookingType == 'hotel') {
        Get.to(
          () => const HotelBookingConfirmation(),
          arguments: {
            'bookingReference': ref,
            'hotel': bookingData['hotel'],
            'roomType': bookingData['roomType'],
            'checkInDate': bookingData['checkInDate'],
            'checkOutDate': bookingData['checkOutDate'],
            'nights': bookingData['nights'],
            'rooms': bookingData['rooms'],
            'guests': bookingData['guests'],
            'guestsData': bookingData['guestsData'],
            'protectionPlan': bookingData['protectionPlan'],
            'protectionPlanCost': bookingData['protectionPlan'] == true
                ? ((bookingData['basePrice'] ??
                            bookingData['totalPrice'] ??
                            0.0) as num)
                        .toDouble() *
                    0.05
                : 0.0,
            'basePrice': bookingData['basePrice'] ?? bookingData['totalPrice'],
            'extrasTotal': bookingData['extrasTotal'],
            'extrasIncluded': bookingData['extrasIncluded'],
            'totalPrice': totalPrice,
          },
        );
        return;
      }

      // Show success dialog for non-hotel bookings
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: TravelloTheme.primaryMainContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.check_mark_circled,
                  color: TravelloTheme.primaryMain,
                  size: 60,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ${bookingType == 'flight' ? 'flight' : bookingType == 'train' ? 'train' : 'transport'} has been booked successfully',
                textAlign: TextAlign.center,
                style: TravelloTheme.caption,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TravelloTheme.paperLightContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Booking Reference',
                      style: TravelloTheme.caption,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TRA${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  nav.pop();
                  Get.until((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TravelloTheme.primaryMain,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = TravelloTheme.primaryMain;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => Get.toNamed('/faq'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Progress Stepper
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: bookingType == 'hotel'
                  ? Row(
                      children: [
                        _buildStepIndicatorWithNumber(
                            1, 'Hotel', true, false, const Color(0xFFD4AF37)),
                        Expanded(
                            child:
                                _buildStepLine(true, const Color(0xFFD4AF37))),
                        _buildStepIndicatorWithNumber(
                            2, 'Rooms', true, false, const Color(0xFFD4AF37)),
                        Expanded(
                            child:
                                _buildStepLine(true, const Color(0xFFD4AF37))),
                        _buildStepIndicatorWithNumber(
                            3, 'Guests', true, false, const Color(0xFFD4AF37)),
                        Expanded(
                            child:
                                _buildStepLine(true, const Color(0xFFD4AF37))),
                        _buildStepIndicatorWithNumber(4, 'Checkout', true,
                            false, const Color(0xFFD4AF37)),
                        Expanded(
                            child:
                                _buildStepLine(true, const Color(0xFFD4AF37))),
                        _buildStepIndicatorWithNumber(
                            5, 'Payment', false, true, const Color(0xFFD4AF37)),
                        Expanded(
                            child:
                                _buildStepLine(false, const Color(0xFFD4AF37))),
                        _buildStepIndicatorWithNumber(
                            6, 'Done', false, false, const Color(0xFFD4AF37)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepIndicatorWithNumber(
                            1,
                            'Passengers',
                            true,
                            false,
                            bookingType == 'flight'
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF059669)),
                        Expanded(
                            child: _buildStepLine(
                                true,
                                bookingType == 'flight'
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF059669))),
                        _buildStepIndicatorWithNumber(
                            2,
                            bookingType == 'flight' ? 'Facilities' : 'Class',
                            true,
                            false,
                            bookingType == 'flight'
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF059669)),
                        Expanded(
                            child: _buildStepLine(
                                true,
                                bookingType == 'flight'
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF059669))),
                        _buildStepIndicatorWithNumber(
                            3,
                            'Checkout',
                            true,
                            false,
                            bookingType == 'flight'
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF059669)),
                        Expanded(
                            child: _buildStepLine(
                                true,
                                bookingType == 'flight'
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF059669))),
                        _buildStepIndicatorWithNumber(
                            4,
                            'Payment',
                            false,
                            true,
                            bookingType == 'flight'
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF059669)),
                        Expanded(
                            child: _buildStepLine(
                                false,
                                bookingType == 'flight'
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF059669))),
                        _buildStepIndicatorWithNumber(
                            5,
                            'Done',
                            false,
                            false,
                            bookingType == 'flight'
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF059669)),
                      ],
                    ),
            ),

            // Booking Summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: TravelloTheme.paperLight,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: bookingType == 'flight'
                  ? _buildFlightSummary()
                  : bookingType == 'train'
                      ? _buildTrainSummary()
                      : bookingType == 'hotel'
                          ? _buildHotelSummary()
                          : _buildTransportSummary(),
            ),

            // Fare breakdown
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        bookingType == 'flight'
                            ? CupertinoIcons.airplane
                            : bookingType == 'train'
                                ? CupertinoIcons.train_style_one
                                : bookingType == 'hotel'
                                    ? CupertinoIcons.building_2_fill
                                    : CupertinoIcons.car_detailed,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fare Breakdown',
                        style: TravelloTheme.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (bookingType == 'flight') ...[
                    _buildFareRow(
                        'Base Fare', (totalPrice * 0.85).toStringAsFixed(0)),
                    if (bookingData['addons']?['extraBaggage'] > 0)
                      _buildFareRow(
                        'Extra Baggage (${bookingData['addons']['extraBaggage']} kg)',
                        '${bookingData['addons']['extraBaggage'] * 1000}',
                      ),
                    if (bookingData['addons']?['selectedSeat'] != null)
                      _buildFareRow('Seat Selection', '2000'),
                    if (bookingData['addons']?['travelInsurance'] == true)
                      _buildFareRow('Travel Insurance', '1500'),
                    _buildFareRow(
                        'Taxes & Fees', (totalPrice * 0.15).toStringAsFixed(0)),
                  ] else if (bookingType == 'train') ...[
                    () {
                      final passengers =
                          bookingData['passengers'] as List? ?? [];
                      final pricePerPerson = totalPrice /
                          (passengers.isEmpty ? 1 : passengers.length);
                      return _buildFareRow(
                        '${passengers.length} passenger${passengers.length > 1 ? 's' : ''} × PKR ${pricePerPerson.toStringAsFixed(0)}',
                        totalPrice.toStringAsFixed(0),
                      );
                    }(),
                  ] else if (bookingType == 'hotel') ...[
                    () {
                      final nights = bookingData['nights'] ?? 1;
                      final rooms = bookingData['rooms'] ?? 1;
                      final basePrice = bookingData['basePrice'];
                      final roomTypePrice =
                          bookingData['roomType']?.pricePerNight;
                      final pricePerNight = roomTypePrice ??
                          bookingData['hotel']?.pricePerNight ??
                          0.0;
                      final baseAmount =
                          basePrice ?? (pricePerNight * nights * rooms);
                      final serviceCharge = baseAmount * 0.05; // 5%
                      final tourismTax = baseAmount * 0.03; // 3%
                      final gst = baseAmount * 0.16; // 16%
                      final protectionPlan =
                          bookingData['protectionPlan'] == true;
                      final protectionCost =
                          bookingData['protectionPlanCost'] ?? 0.0;

                      return Column(
                        children: [
                          _buildFareRow(
                            'PKR ${pricePerNight.toStringAsFixed(0)} × $nights night${nights > 1 ? 's' : ''} × $rooms room${rooms > 1 ? 's' : ''}',
                            baseAmount.toStringAsFixed(0),
                          ),
                          const SizedBox(height: 8),
                          _buildFareRow(
                            'Service Charge (5%)',
                            serviceCharge.toStringAsFixed(0),
                          ),
                          _buildFareRow(
                            'Tourism Tax (3%)',
                            tourismTax.toStringAsFixed(0),
                          ),
                          _buildFareRow(
                            'GST (16%)',
                            gst.toStringAsFixed(0),
                          ),
                          if (protectionPlan && protectionCost > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    size: 16,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Travel Protection Plan',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'PKR ${protectionCost.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    }(),
                  ] else if (bookingType == 'transport') ...[
                    () {
                      final transport = bookingData['transport'];
                      final basePrice = transport?.basePrice ?? 0.0;
                      final pricePerKm = transport?.pricePerKm ?? 0.0;
                      final distance = bookingData['estimatedDistance'] ?? 0.0;
                      return Column(
                        children: [
                          _buildFareRow(
                              'Base Fare', basePrice.toStringAsFixed(0)),
                          if (distance > 0)
                            _buildFareRow(
                              'Distance (${distance.toStringAsFixed(0)} km × PKR ${pricePerKm.toStringAsFixed(0)})',
                              (pricePerKm * distance).toStringAsFixed(0),
                            ),
                        ],
                      );
                    }(),
                  ],
                  const Divider(height: 24, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'PKR ${totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Payment method selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Method rows inside card with header ──────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Section header inside card ────────────────────
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(children: [
                            Icon(Icons.credit_card,
                                color: Color(0xFFD4AF37), size: 22),
                            SizedBox(width: 8),
                            Text('Choose Payment Method',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                          ]),
                        ),
                        _dividerLine(),
                        _buildMethodRow('Card', 'Credit / Debit Card',
                            '(Master and VISA Cards)',
                            bgColor: const Color(0xFFFBF5DC),
                            iconColor: const Color(0xFFD4AF37),
                            icon: Icons.credit_card),
                        _dividerLine(),
                        _buildMethodRow(
                            'JazzCash', 'JazzCash', 'Pay with JazzCash wallet',
                            bgColor: const Color(0xFFFBF5DC),
                            iconColor: const Color(0xFFD4AF37),
                            icon: Icons.account_balance_wallet_rounded),
                        _dividerLine(),
                        _buildMethodRow('Easypaisa', 'Easypaisa',
                            'Pay with Easypaisa wallet',
                            bgColor: const Color(0xFFFBF5DC),
                            iconColor: const Color(0xFFD4AF37),
                            icon: Icons.account_balance_wallet_rounded),
                        if (bookingType == 'transport') ...[
                          _dividerLine(),
                          _buildMethodRow('Bank Transfer', 'Bank Transfer',
                              'Direct bank transfer',
                              bgColor: const Color(0xFFFBF5DC),
                              iconColor: const Color(0xFFD4AF37),
                              icon: Icons.account_balance),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment details form
                  if (_selectedPaymentMethod == 'Card')
                    _buildCardForm()
                  else if (_selectedPaymentMethod == 'JazzCash' ||
                      _selectedPaymentMethod == 'Easypaisa')
                    _buildMobileWalletForm()
                  else if (bookingType == 'transport' &&
                      _selectedPaymentMethod == 'Bank Transfer')
                    _buildBankTransferInfo(),

                  const SizedBox(height: 16),

                  // ── Security Badges ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSecurityBadge(
                                icon: Icons.verified_user,
                                iconColor: Colors.green.shade600,
                                bgColor: Colors.green.shade50,
                                label: 'SSL Secured'),
                            _buildSecurityBadge(
                                icon: Icons.support_agent,
                                iconColor: Colors.blue.shade600,
                                bgColor: Colors.blue.shade50,
                                label: '24/7 Support'),
                            _buildSecurityBadge(
                                icon: Icons.replay,
                                iconColor: Colors.orange.shade600,
                                bgColor: Colors.orange.shade50,
                                label: 'Money Back'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                                'Your payment information is encrypted and secure',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '24/7 Customer Support: +92-300-1234567',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      // Confirm button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TravelloTheme.paperLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: (_isProcessing || !_canPay) ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Confirm Payment • PKR ${totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityBadge({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildFareRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF666666))),
          Text('PKR $amount',
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333))),
        ],
      ),
    );
  }

  // ── helper: single method row ─────────────────────────────────────────────
  Widget _buildMethodRow(String value, String title, String subtitle,
      {required Color bgColor,
      required Color iconColor,
      required IconData icon}) {
    final isSelected = _selectedPaymentMethod == value;
    return Material(
      color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() {
          _selectedPaymentMethod = value;
          _showWalletOTP = false;
          _otpValue = '';
          _isOtpVerified = false;
        }),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 16, vertical: spacingUnit(1.75)),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            SizedBox(width: spacingUnit(1.75)),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ]),
            ),
            isSelected
                ? const Icon(Icons.radio_button_checked,
                    color: Color(0xFF1E88E5), size: 22)
                : Icon(Icons.radio_button_unchecked,
                    color: Colors.grey.shade400, size: 22),
          ]),
        ),
      ),
    );
  }

  Widget _dividerLine() =>
      Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 72);

  Widget _buildCardForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Enter Card Details',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock, size: 12, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text('Secure',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),

            // Dynamic card network logos
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  opacity: (_cardNetwork == null || _cardNetwork == 'visa')
                      ? 1.0
                      : 0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Image.asset('assets/images/visa.png',
                      height: 20,
                      errorBuilder: (_, __, ___) => const Text('VISA',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1F71)))),
                ),
                const SizedBox(width: 4),
                AnimatedOpacity(
                  opacity:
                      (_cardNetwork == null || _cardNetwork == 'mastercard')
                          ? 1.0
                          : 0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Image.asset('assets/images/master_card.png',
                      height: 20,
                      errorBuilder: (_, __, ___) => Container(
                            width: 24,
                            height: 16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: const LinearGradient(colors: [
                                Color(0xFFEB001B),
                                Color(0xFFF79E1B)
                              ]),
                            ),
                          )),
                ),
                const SizedBox(width: 4),
                AnimatedOpacity(
                  opacity: (_cardNetwork == null || _cardNetwork == 'amex')
                      ? 1.0
                      : 0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF2557D6),
                        borderRadius: BorderRadius.circular(3)),
                    child: const Text('AMEX',
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Card number
            const Text('Credit Card Number',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cardNumberController,
              decoration: InputDecoration(
                hintText: '1234 1234 1234 1234',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF1E88E5), width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red)),
              ),
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.creditCardNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
              validator: (value) =>
                  DSValidators.cardNumber(value?.replaceAll(' ', '')),
              onChanged: (value) {
                String clean = value.replaceAll(' ', '');
                // Detect network
                String? network;
                if (clean.isEmpty) {
                  network = null;
                } else if (clean.startsWith('4')) {
                  network = 'visa';
                } else if (clean.startsWith('5') || clean.startsWith('2')) {
                  network = 'mastercard';
                } else if (clean.startsWith('3')) {
                  network = 'amex';
                } else {
                  network = 'other';
                }
                if (network != _cardNetwork) {
                  setState(() => _cardNetwork = network);
                }
                // Auto-format with spaces
                if (clean.length <= 16) {
                  String formatted = '';
                  for (int i = 0; i < clean.length; i++) {
                    if (i > 0 && i % 4 == 0) formatted += ' ';
                    formatted += clean[i];
                  }
                  if (formatted != value) {
                    _cardNumberController.value = TextEditingValue(
                        text: formatted,
                        selection:
                            TextSelection.collapsed(offset: formatted.length));
                  }
                }
              },
            ),
            const SizedBox(height: 12),

            // Expiry + CVC row
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expiry Date',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _expiryController,
                        decoration: InputDecoration(
                          hintText: 'MM/YY',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFF1E88E5), width: 1.5)),
                          errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.red)),
                        ),
                        keyboardType: TextInputType.number,
                        autofillHints: const [
                          AutofillHints.creditCardExpirationDate
                        ],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: DSValidators.cardExpiry,
                        onChanged: (value) {
                          String clean = value.replaceAll('/', '');
                          if (clean.length >= 2 && !value.contains('/')) {
                            String formatted =
                                '${clean.substring(0, 2)}/${clean.substring(2)}';
                            if (formatted.length <= 5) {
                              _expiryController.value = TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(
                                      offset: formatted.length));
                            }
                          }
                        },
                      ),
                    ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('CVC',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: '3–4 digits on back of card',
                          child: Icon(Icons.help_outline,
                              size: 14, color: Colors.grey.shade400),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cvvController,
                        decoration: InputDecoration(
                          hintText: '•••',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFF1E88E5), width: 1.5)),
                          errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.red)),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: DSValidators.cvv,
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: 16),

            // Cardholder Name
            const Text('CARDHOLDER NAME',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cardHolderController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.characters,
              autofillHints: const [AutofillHints.creditCardName],
              decoration: InputDecoration(
                hintText: 'Name as printed on card',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF1E88E5), width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red)),
              ),
              validator: DSValidators.cardholderName,
            ),
            const SizedBox(height: 16),

            // Save card checkbox
            InkWell(
              onTap: () => setState(() => _saveCard = !_saveCard),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        color:
                            _saveCard ? const Color(0xFF1E88E5) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _saveCard
                                ? const Color(0xFF1E88E5)
                                : Colors.grey.shade400,
                            width: 1.5)),
                    child: _saveCard
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text('Save card for future payments',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // SSL notice
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: spacingUnit(1.25)),
              decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFF1E88E5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Your payment is secured with 256-bit SSL encryption',
                      style:
                          TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileWalletForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Add New Account',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            InkWell(
              onTap: () => setState(() {
                _selectedPaymentMethod = '';
                _showWalletOTP = false;
                _otpValue = '';
                _isOtpVerified = false;
              }),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
              ),
            ),
          ]),
          Divider(height: 24, color: Colors.grey.shade200),

          // ── Step 1: Phone entry (hidden once OTP is sent) ──
          if (!_showWalletOTP) ...[
            Text('Phone Number',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            SizedBox(height: spacingUnit(0.75)),
            Form(
              key: _mobileFormKey,
              child: TextFormField(
                controller: _mobileNumberController,
                decoration: InputDecoration(
                  hintText: 'Enter a phone number',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('\uD83C\uDDF5\uD83C\uDDF0',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down,
                          size: 16, color: Colors.grey.shade600),
                    ]),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF1E88E5), width: 1.5)),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                  _NoLeadingZeroFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (!_isValidPkWalletPhone(value)) {
                    return 'Enter valid PK mobile number (3XXXXXXXXX)';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_mobileFormKey.currentState!.validate()) {
                    setState(() {
                      _showWalletOTP = true;
                      _otpValue = '';
                    });
                    Get.snackbar(
                      'Code Sent',
                      'Verification code sent to ${_mobileNumberController.text}',
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: Colors.green.shade600,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 3),
                      margin: const EdgeInsets.all(12),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC49A22),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Get Code',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],

          // ── Step 2: OTP entry + verification ──
          if (_showWalletOTP) ...[
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
                        color: Colors.black),
                    onChanged: (value) {
                      setState(() {
                        if (value.length == 1) {
                          if (_otpValue.length < 6) _otpValue += value;
                          if (index < 5) FocusScope.of(context).nextFocus();
                        } else {
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
            // Verify OTP button (shown until verified)
            if (!_isOtpVerified)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _otpValue.length == 6
                      ? () => setState(() => _isOtpVerified = true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC49A22),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Verify OTP',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            // Success banner (shown after verified)
            if (_isOtpVerified)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade700, size: 18),
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
          ],
        ],
      ),
    );
  }

  Widget _buildBankTransferInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TravelloTheme.paperLight,
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
          const Text('Bank Transfer Details', style: TravelloTheme.subtitle),
          const SizedBox(height: 16),
          _buildInfoRow('Bank Name', 'Meezan Bank'),
          _buildInfoRow('Account Title', 'Travello AI'),
          _buildInfoRow('Account Number', '0123456789012'),
          _buildInfoRow('IBAN', 'PK12MEZN0000120123456789'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.info_circle,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transfer the amount and share receipt via email',
                    style: TravelloTheme.caption.copyWith(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TravelloTheme.caption),
          Text(value, style: TravelloTheme.subtitle),
        ],
      ),
    );
  }

  Widget _buildFlightSummary() {
    final flight = bookingData['flight'];
    if (flight == null) return const SizedBox();
    const primary = TravelloTheme.primaryMain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Gold header bar ──────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(
            top: -16,
            left: -16,
            right: -16,
            bottom: 16,
          ),
          padding:
              EdgeInsets.symmetric(horizontal: 16, vertical: spacingUnit(1.75)),
          color: primary,
          child: const Row(children: [
            Icon(CupertinoIcons.airplane, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Flight Summary',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
        ),
        // ── Airline row ──────────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.airplane,
                color: primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flight.airlineName ?? 'Flight',
                    style: TravelloTheme.subtitle
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${flight.airlineCode ?? ''} • ${flight.cabinClass ?? 'Economy'}',
                    style: TravelloTheme.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flight.departureTime ?? '',
                  style: TravelloTheme.title2,
                ),
                Text(
                  bookingData['searchParams']?['fromAirport']?.code ?? 'DEP',
                  style: TravelloTheme.caption,
                ),
              ],
            ),
            Column(
              children: [
                const Icon(
                  CupertinoIcons.arrow_right,
                  color: TravelloTheme.primaryMain,
                ),
                Text(
                  flight.duration ?? '',
                  style: TravelloTheme.caption,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  flight.arrivalTime ?? '',
                  style: TravelloTheme.title2,
                ),
                Text(
                  bookingData['searchParams']?['toAirport']?.code ?? 'ARR',
                  style: TravelloTheme.caption,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrainSummary() {
    final isRoundTrip = bookingData['isRoundTrip'] ?? false;

    if (isRoundTrip) {
      final outboundTrain = bookingData['outboundTrain'];
      final returnTrain = bookingData['returnTrain'];
      final outboundClass = bookingData['outboundClass'] ?? 'Economy';
      final returnClass = bookingData['returnClass'] ?? 'Economy';

      if (outboundTrain == null || returnTrain == null) return const SizedBox();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Outbound Train Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMainContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'OUTBOUND JOURNEY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: TravelloTheme.primaryMain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSingleTrainSummary(
            outboundTrain,
            outboundClass,
            bookingData['searchParams']?['fromStation']?.code ?? 'DEP',
            bookingData['searchParams']?['toStation']?.code ?? 'ARR',
            bookingData['searchParams']?['fromStation']?.name ??
                'Departure Station',
            bookingData['searchParams']?['toStation']?.name ??
                'Arrival Station',
            bookingData['searchParams']?['departureDate'],
            true, // isOutbound
          ),

          const SizedBox(height: 16),
          Divider(thickness: 1, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),

          // Return Train Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMainContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'RETURN JOURNEY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: TravelloTheme.primaryMain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSingleTrainSummary(
            returnTrain,
            returnClass,
            bookingData['searchParams']?['toStation']?.code ?? 'ARR',
            bookingData['searchParams']?['fromStation']?.code ?? 'DEP',
            bookingData['searchParams']?['toStation']?.name ??
                'Departure Station',
            bookingData['searchParams']?['fromStation']?.name ??
                'Arrival Station',
            bookingData['searchParams']?['returnDate'],
            false, // isReturn
          ),
        ],
      );
    } else {
      // One-way journey
      final train = bookingData['train'];
      final selectedClass = bookingData['selectedClass'] ?? 'Economy';
      if (train == null) return const SizedBox();

      return _buildSingleTrainSummary(
        train,
        selectedClass,
        bookingData['searchParams']?['fromStation']?.code ?? 'DEP',
        bookingData['searchParams']?['toStation']?.code ?? 'ARR',
        bookingData['searchParams']?['fromStation']?.name ??
            'Departure Station',
        bookingData['searchParams']?['toStation']?.name ?? 'Arrival Station',
        bookingData['searchParams']?['departureDate'],
        null, // single trip
      );
    }
  }

  Widget _buildSingleTrainSummary(
    dynamic train,
    String selectedClass,
    String fromCode,
    String toCode,
    String fromName,
    String toName,
    DateTime? travelDate,
    bool? isOutbound, // true = outbound, false = return, null = one-way
  ) {
    // Determine which details state to use
    bool showDetails = isOutbound == true
        ? _showOutboundDetails
        : isOutbound == false
            ? _showReturnDetails
            : _showTrainDetails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TravelloTheme.primaryMainContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.train_style_one,
                color: TravelloTheme.primaryMain,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    train.trainName ?? 'Train',
                    style: TravelloTheme.subtitle
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${train.trainNumber ?? ''} • $selectedClass',
                    style: TravelloTheme.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  train.departureTime ?? '',
                  style: TravelloTheme.title2,
                ),
                Text(
                  fromCode,
                  style: TravelloTheme.caption,
                ),
              ],
            ),
            Column(
              children: [
                const Icon(
                  CupertinoIcons.arrow_right,
                  color: TravelloTheme.primaryMain,
                ),
                Text(
                  train.duration ?? '',
                  style: TravelloTheme.caption,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  train.arrivalTime ?? '',
                  style: TravelloTheme.title2,
                ),
                Text(
                  toCode,
                  style: TravelloTheme.caption,
                ),
              ],
            ),
          ],
        ),

        // Show/Hide Details Button
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            setState(() {
              if (isOutbound == true) {
                _showOutboundDetails = !_showOutboundDetails;
              } else if (isOutbound == false) {
                _showReturnDetails = !_showReturnDetails;
              } else {
                _showTrainDetails = !_showTrainDetails;
              }
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                showDetails ? 'Hide details' : 'Show details',
                style: const TextStyle(
                  color: TravelloTheme.primaryMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                showDetails
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                color: TravelloTheme.primaryMain,
                size: 16,
              ),
            ],
          ),
        ),

        // Expandable Details Section
        if (showDetails) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMainContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: TravelloTheme.primaryMain.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                if (travelDate != null) ...[
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(travelDate),
                        style: TravelloTheme.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Departure Station
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: TravelloTheme.primaryMain,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 60,
                          color: colorScheme(context)
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            train.departureTime ?? '',
                            style: TravelloTheme.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '($fromCode) $fromName',
                            style: TravelloTheme.caption,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: TravelloTheme.primaryMainContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.train_style_one,
                                  size: 14,
                                  color: TravelloTheme.primaryMain,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${train.trainNumber ?? ''} • ${train.trainName ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: TravelloTheme.primaryMain,
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

                // Duration indicator
                Row(
                  children: [
                    const SizedBox(width: 5),
                    Container(
                      width: 2,
                      height: 30,
                      color: TravelloTheme.primaryMain.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      CupertinoIcons.time,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      train.duration ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                // Arrival Station
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 2,
                          height: 20,
                          color: colorScheme(context)
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: TravelloTheme.primaryMain,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            train.arrivalTime ?? '',
                            style: TravelloTheme.subtitle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '($toCode) $toName',
                            style: TravelloTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 16),

                // Class details
                Text(
                  selectedClass,
                  style: TravelloTheme.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (selectedClass.contains('AC')) ...[
                      Icon(
                        CupertinoIcons.snow,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Air Conditioned',
                        style: TravelloTheme.caption,
                      ),
                      const SizedBox(width: 16),
                    ],
                    Icon(
                      CupertinoIcons.person_2,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedClass.contains('Sleeper')
                          ? 'Sleeping Berths'
                          : 'Comfortable Seating',
                      style: TravelloTheme.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHotelSummary() {
    final hotel = bookingData['hotel'];
    if (hotel == null) return const SizedBox();

    final checkInDate = bookingData['checkInDate'] as DateTime?;
    final checkOutDate = bookingData['checkOutDate'] as DateTime?;
    final nights = bookingData['nights'] ?? 1;
    final rooms = bookingData['rooms'] ?? 1;
    final guests = bookingData['guests'] ?? 1;

    const primary = TravelloTheme.primaryMain;
    final hasImage = hotel.images != null && (hotel.images as List).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hotel Summary header bar ─────────────────────────────────────
        Container(
          width: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: 16, vertical: spacingUnit(1.25)),
          decoration: const BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: const Row(children: [
            Icon(Icons.hotel, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Hotel Summary',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        // ── Hero image + hotel info ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Stack(
              children: [
                // Image
                if (hasImage)
                  Image.network(
                    (hotel.images as List)[0],
                    width: double.infinity,
                    height: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _hotelImageFallback(primary),
                  )
                else
                  _hotelImageFallback(primary),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // Hotel name + category over image
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.all(spacingUnit(1.75)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotel.name ?? 'Hotel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hotel.category ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.location_on,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 2),
                            Text(
                              hotel.city ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              '${hotel.rating ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
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
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check-in',
                    style: TravelloTheme.caption.copyWith(
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    checkInDate != null ? _formatDate(checkInDate) : '-',
                    style: TravelloTheme.subtitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                const Icon(
                  Icons.nights_stay,
                  color: TravelloTheme.primaryMain,
                  size: 20,
                ),
                Text(
                  '$nights night${nights > 1 ? 's' : ''}',
                  style: TravelloTheme.caption,
                ),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Check-out',
                    style: TravelloTheme.caption.copyWith(
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    checkOutDate != null ? _formatDate(checkOutDate) : '-',
                    style: TravelloTheme.subtitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              CupertinoIcons.person_2,
              size: 18,
              color: Colors.grey[600],
            ),
            SizedBox(width: spacingUnit(0.75)),
            Text(
              '$guests Guest${guests > 1 ? 's' : ''}',
              style: TravelloTheme.paragraph,
            ),
            const SizedBox(width: 20),
            Icon(
              CupertinoIcons.bed_double,
              size: 18,
              color: Colors.grey[600],
            ),
            SizedBox(width: spacingUnit(0.75)),
            Text(
              '$rooms Room${rooms > 1 ? 's' : ''}',
              style: TravelloTheme.paragraph,
            ),
          ],
        ),

        // Room Type Details (if available)
        if (bookingData['roomType'] != null) ...[
          const SizedBox(height: 16),
          Divider(thickness: 1, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(
                CupertinoIcons.bed_double_fill,
                color: TravelloTheme.primaryMain,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Room Type',
                style: TravelloTheme.subtitle2,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryMainContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookingData['roomType'].name ?? 'Room',
                  style: TravelloTheme.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bookingData['roomType'].description ?? '',
                  style: TravelloTheme.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${bookingData['roomType'].maxOccupancy ?? ''} guests',
                      style: TravelloTheme.caption,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.aspect_ratio,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${bookingData['roomType'].sizeInSqFt ?? ''} sq ft',
                      style: TravelloTheme.caption,
                    ),
                  ],
                ),
                if (bookingData['roomType'].bedType != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(CupertinoIcons.bed_double,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        bookingData['roomType'].bedType ?? '',
                        style: TravelloTheme.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (bookingData['roomType'].breakfastIncluded == true) ...[
                  SizedBox(height: spacingUnit(0.75)),
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Breakfast included',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],

        // Cancellation Policy
        const SizedBox(height: 16),
        Divider(thickness: 1, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hotel.isRefundable == true
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hotel.isRefundable == true
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hotel.isRefundable == true
                    ? CupertinoIcons.checkmark_shield_fill
                    : CupertinoIcons.info_circle_fill,
                color:
                    hotel.isRefundable == true ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.isRefundable == true
                          ? 'Refundable'
                          : 'Non-Refundable',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: hotel.isRefundable == true
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hotel.isRefundable == true
                          ? 'Free cancellation up to 24 hours before check-in'
                          : 'This rate is non-refundable',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Hotel Amenities Summary
        if (hotel.amenities != null && hotel.amenities!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: hotel.amenities!.take(4).map<Widget>((amenity) {
              IconData icon;
              switch (amenity.toLowerCase()) {
                case 'free wifi':
                case 'wifi':
                  icon = CupertinoIcons.wifi;
                  break;
                case 'parking':
                case 'free parking':
                  icon = CupertinoIcons.car_fill;
                  break;
                case 'breakfast':
                case 'free breakfast':
                  icon = CupertinoIcons.square_favorites_alt_fill;
                  break;
                case 'pool':
                case 'swimming pool':
                  icon = Icons.pool;
                  break;
                case 'gym':
                case 'fitness center':
                  icon = Icons.fitness_center;
                  break;
                default:
                  icon = CupertinoIcons.checkmark_circle_fill;
              }
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: spacingUnit(0.75),
                ),
                decoration: BoxDecoration(
                  color: TravelloTheme.paperLightContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: TravelloTheme.primaryMain,
                    ),
                    SizedBox(width: spacingUnit(0.75)),
                    Text(
                      amenity,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTransportSummary() {
    final transport = bookingData['transport'];
    if (transport == null) return const SizedBox();

    final pickupLocation = bookingData['pickupLocation'] ?? '';
    final dropoffLocation = bookingData['dropoffLocation'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TravelloTheme.primaryMainContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.car_detailed,
                color: TravelloTheme.primaryMain,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transport.name ?? 'Transport',
                    style: TravelloTheme.subtitle
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${transport.vehicleModel ?? ''} • ${transport.type ?? ''}',
                    style: TravelloTheme.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (pickupLocation.isNotEmpty || dropoffLocation.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: TravelloTheme.primaryMain,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 30,
                    color: Colors.grey[400],
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup',
                      style: TravelloTheme.caption,
                    ),
                    Text(
                      pickupLocation.isNotEmpty ? pickupLocation : '-',
                      style: TravelloTheme.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Drop-off',
                      style: TravelloTheme.caption,
                    ),
                    Text(
                      dropoffLocation.isNotEmpty ? dropoffLocation : '-',
                      style: TravelloTheme.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            if (transport.isAC == true) ...[
              Icon(
                CupertinoIcons.snow,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              const Text(
                'Air Conditioned',
                style: TravelloTheme.caption,
              ),
              const SizedBox(width: 16),
            ],
            Icon(
              CupertinoIcons.person_2,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              '${transport.seatingCapacity ?? 0} Seats',
              style: TravelloTheme.caption,
            ),
          ],
        ),
      ],
    );
  }

  Widget _hotelImageFallback(Color primary) => Container(
        width: double.infinity,
        height: 170,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary.withValues(alpha: 0.7), primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(CupertinoIcons.building_2_fill,
              size: 56, color: Colors.white54),
        ),
      );

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]}';
  }

  Widget _buildStepIndicatorWithNumber(int step, String label, bool isCompleted,
      bool isActive, Color activeColor) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color:
                isCompleted || isActive ? activeColor : const Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isCompleted || isActive ? activeColor : Colors.grey.shade500,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive, Color activeColor) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive ? activeColor : const Color(0xFFE0E0E0),
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
