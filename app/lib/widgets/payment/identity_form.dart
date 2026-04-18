import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/controllers/payment_form_controller.dart';
import 'package:flight_app/utils/design_system_formatters.dart';
import 'package:flight_app/utils/design_system_validators.dart';
import 'package:flight_app/widgets/app_input/ds_input_field.dart';

class IdentityForm extends StatelessWidget {
  const IdentityForm({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<PaymentFormController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── First + Last name side-by-side ─────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DSInputField(
                label: 'FIRST NAME',
                hint: 'First name',
                controller: ctrl.firstNameCtrl,
                focusNode: ctrl.firstNameFocus,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                validator: DSValidators.name,
                onChanged: ctrl.validateFirstName,
                autofillHints: const [AutofillHints.givenName],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DSInputField(
                label: 'LAST NAME',
                hint: 'Last name',
                controller: ctrl.lastNameCtrl,
                focusNode: ctrl.lastNameFocus,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                validator: DSValidators.name,
                onChanged: ctrl.validateLastName,
                autofillHints: const [AutofillHints.familyName],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Phone number ───────────────────────────────────────────────────
        DSInputField(
          label: 'PHONE NUMBER',
          hint: '3001234567',
          controller: ctrl.phoneCtrl,
          focusNode: ctrl.phoneFocus,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneDigitsOnlyFormatter()],
          validator: DSValidators.phone,
          onChanged: ctrl.validatePhone,
          prefixIcon: Icons.phone_outlined,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
      ],
    );
  }
}
