import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/controllers/payment_form_controller.dart';
import 'package:flight_app/utils/design_system_formatters.dart';
import 'package:flight_app/utils/design_system_validators.dart';
import 'package:flight_app/widgets/app_input/ds_input_field.dart';

class CreditCardInfo extends StatefulWidget {
  const CreditCardInfo({super.key});

  @override
  State<CreditCardInfo> createState() => _CreditCardInfoState();
}

class _CreditCardInfoState extends State<CreditCardInfo> {
  late final PaymentFormController _ctrl;
  String? _network;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<PaymentFormController>();
    _ctrl.cardNumberCtrl.addListener(_onCardNumberChanged);
  }

  void _onCardNumberChanged() {
    final digits = _ctrl.cardNumberCtrl.text.replaceAll(' ', '');
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
    if (network != _network) setState(() => _network = network);
  }

  @override
  void dispose() {
    _ctrl.cardNumberCtrl.removeListener(_onCardNumberChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Card network logos ─────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedOpacity(
              opacity:
                  (_network == null || _network == 'mastercard') ? 1.0 : 0.2,
              duration: const Duration(milliseconds: 200),
              child: Image.asset('assets/images/master_card.png', height: 26),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: (_network == null || _network == 'visa') ? 1.0 : 0.2,
              duration: const Duration(milliseconds: 200),
              child: Image.asset('assets/images/visa.png', height: 26),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Card number ────────────────────────────────────────────────────
        DSInputField(
          label: 'CARD NUMBER',
          hint: '0000  0000  0000  0000',
          controller: _ctrl.cardNumberCtrl,
          focusNode: _ctrl.cardNumberFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [CardNumberFormatter()],
          validator: DSValidators.cardNumber,
          onChanged: _ctrl.validateCardNumber,
          autofillHints: const [AutofillHints.creditCardNumber],
        ),
        const SizedBox(height: 16),

        // ── Expiry + CVV ───────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DSInputField(
                label: 'EXPIRY',
                hint: 'MM/YY',
                controller: _ctrl.expiryCtrl,
                focusNode: _ctrl.expiryFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [ExpiryFormatter()],
                validator: DSValidators.cardExpiry,
                onChanged: _ctrl.validateExpiry,
                autofillHints: const [AutofillHints.creditCardExpirationDate],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DSInputField(
                label: 'CVV',
                hint: '•••',
                controller: _ctrl.cvvCtrl,
                focusNode: _ctrl.cvvFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [CvvFormatter()],
                obscureText: true,
                validator: DSValidators.cvv,
                onChanged: _ctrl.validateCvv,
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Tooltip(
                    message: '3–4 digits on back of card',
                    child: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Cardholder name ────────────────────────────────────────────────
        DSInputField(
          label: 'CARDHOLDER NAME',
          hint: 'Name as printed on card',
          controller: _ctrl.cardNameCtrl,
          focusNode: _ctrl.cardNameFocus,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.characters,
          validator: DSValidators.cardholderName,
          onChanged: _ctrl.validateCardName,
          autofillHints: const [AutofillHints.creditCardName],
        ),
      ],
    );
  }
}
