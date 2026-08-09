import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flight_app/utils/design_system_validators.dart';

/// Card-payment bottom sheet for an **already-created pending booking**.
///
/// Unlike the agent chat's card sheet (which creates the booking first), this
/// sheet is used from My Bookings / Booking Detail where the booking row already
/// exists with status `pending`. It only runs the payment step —
/// `POST /payments/initiate` on the booking UUID — so there is no double-booking
/// and no new passenger write. Card payment confirms instantly (no OTP), the
/// same as the manual and agent card flows.
///
/// Security: card number / CVV are entered in this form only — never typed into
/// chat, and never sent anywhere except the payment endpoint.
class CompletePaymentSheet extends StatefulWidget {
  /// Booking UUID (`booking['id']`) — the value `/payments/initiate` expects.
  /// For a whole-package payment this is the PRIMARY component (the transport
  /// leg, so the transfer it carries is dispatched correctly) — see
  /// [packageId].
  final String bookingId;
  final double amount;
  final String? email;
  /// When set, this ONE payment covers every component sharing this package
  /// id — the server verifies `amount` against all of them and refuses
  /// (leaving every component untouched) if it doesn't match, or if any
  /// component was already paid individually. Omit for an ordinary single
  /// booking, exactly as this sheet always worked before.
  final String? packageId;
  final void Function(String pnr, double amount) onSuccess;

  const CompletePaymentSheet({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.onSuccess,
    this.email,
    this.packageId,
  });

  @override
  State<CompletePaymentSheet> createState() => _CompletePaymentSheetState();
}

class _CompletePaymentSheetState extends State<CompletePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _processing = false;
  String? _errorMsg;

  static const _gold = Color(0xFFD4AF37);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  String _formatCardNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _formatExpiry(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) {
      return '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return digits;
  }

  Future<void> _processPayment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.amount <= 0) {
      setState(() => _errorMsg =
          'This booking has no amount due. Please refresh and try again.');
      return;
    }
    setState(() {
      _processing = true;
      _errorMsg = null;
    });

    try {
      final data = await ApiClient.initiatePayment(
        bookingId: widget.bookingId,
        method: 'card',
        amount: widget.amount,
        email: widget.email,
        packageId: widget.packageId,
      );
      final pnr = (data['pnr'] as String?) ??
          (data['booking_id'] as String?) ??
          '';
      if (mounted) Navigator.pop(context);
      widget.onSuccess(pnr, widget.amount);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_US');
    final amount = widget.amount.toInt();

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.credit_card_rounded,
                        color: _gold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          widget.packageId != null
                              ? 'Pay Whole Package'
                              : 'Complete Payment',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Amount Due: PKR ${fmt.format(amount)}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: _gold,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _CardField(
                controller: _nameCtrl,
                label: 'Cardholder Name',
                hint: 'As printed on card',
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                validator: DSValidators.cardholderName,
              ),
              const SizedBox(height: 14),
              _CardField(
                controller: _cardCtrl,
                label: 'Card Number',
                hint: '1234 5678 9012 3456',
                icon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
                maxLength: 19,
                onChanged: (v) {
                  final formatted = _formatCardNumber(v);
                  if (formatted != v) {
                    _cardCtrl.value = TextEditingValue(
                      text: formatted,
                      selection:
                          TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                },
                validator: DSValidators.cardNumber,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CardField(
                      controller: _expiryCtrl,
                      label: 'Expiry',
                      hint: 'MM/YY',
                      icon: Icons.calendar_month_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      onChanged: (v) {
                        final formatted = _formatExpiry(v);
                        if (formatted != v) {
                          _expiryCtrl.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                                offset: formatted.length),
                          );
                        }
                      },
                      validator: DSValidators.cardExpiry,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardField(
                      controller: _cvvCtrl,
                      label: 'CVV',
                      hint: '•••',
                      icon: Icons.lock_outline_rounded,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      obscureText: true,
                      validator: DSValidators.cvv,
                    ),
                  ),
                ],
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    disabledBackgroundColor: _gold.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Pay PKR ${fmt.format(amount)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed:
                      _processing ? null : () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('Secured by 256-bit encryption',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [CompletePaymentSheet] as a modal bottom sheet.
Future<void> showCompletePaymentSheet({
  required BuildContext context,
  required String bookingId,
  required double amount,
  String? email,
  String? packageId,
  required void Function(String pnr, double amount) onSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CompletePaymentSheet(
      bookingId: bookingId,
      amount: amount,
      email: email,
      packageId: packageId,
      onSuccess: onSuccess,
    ),
  );
}

// ── Card form field helper ────────────────────────────────────────────────────
class _CardField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _CardField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.maxLength,
    this.obscureText = false,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
          ),
        ),
      ],
    );
  }
}
