import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/utils/design_system_validators.dart';

/// PaymentFormController
/// Manages all form field states for the payment page.
/// Exposes [canPay] — a reactive bool that drives the CTA enabled/disabled state.
///
/// Architecture:
///   Each field has:
///   - A [TextEditingController] for value access
///   - A [FocusNode] for scroll-to-error
///   - An [Rx<String?>] error observable for inline error display
///   - A [RxBool] isDirty flag so pristine fields don't show errors on load
///
///   [canPay] = all 7 fields are valid (no errors AND not pristine)
class PaymentFormController extends GetxController {
  // ── Text controllers ──────────────────────────────────────────────────────
  final cardNumberCtrl = TextEditingController();
  final expiryCtrl = TextEditingController();
  final cvvCtrl = TextEditingController();
  final cardNameCtrl = TextEditingController();
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  // ── Focus nodes (for scroll-to-error) ────────────────────────────────────
  final cardNumberFocus = FocusNode();
  final expiryFocus = FocusNode();
  final cvvFocus = FocusNode();
  final cardNameFocus = FocusNode();
  final firstNameFocus = FocusNode();
  final lastNameFocus = FocusNode();
  final phoneFocus = FocusNode();

  // ── Validation error observables ─────────────────────────────────────────
  final cardNumberError = Rx<String?>(null);
  final expiryError = Rx<String?>(null);
  final cvvError = Rx<String?>(null);
  final cardNameError = Rx<String?>(null);
  final firstNameError = Rx<String?>(null);
  final lastNameError = Rx<String?>(null);
  final phoneError = Rx<String?>(null);

  // ── Dirty flags ──────────────────────────────────────────────────────────
  final _cardNumberDirty = false.obs;
  final _expiryDirty = false.obs;
  final _cvvDirty = false.obs;
  final _cardNameDirty = false.obs;
  final _firstNameDirty = false.obs;
  final _lastNameDirty = false.obs;
  final _phoneDirty = false.obs;

  // ── Loading state ────────────────────────────────────────────────────────
  final isLoading = false.obs;

  // ── canPay: observable — updated after every field validation ────────────
  final _canPay = false.obs;
  bool get canPay => _canPay.value;

  void _updateCanPay() {
    _canPay.value = cardNumberError.value == null &&
        _cardNumberDirty.value &&
        expiryError.value == null &&
        _expiryDirty.value &&
        cvvError.value == null &&
        _cvvDirty.value &&
        cardNameError.value == null &&
        _cardNameDirty.value &&
        firstNameError.value == null &&
        _firstNameDirty.value &&
        lastNameError.value == null &&
        _lastNameDirty.value &&
        phoneError.value == null &&
        _phoneDirty.value;
  }

  // ── Validate individual fields ────────────────────────────────────────────
  void validateCardNumber(String v) {
    _cardNumberDirty.value = true;
    cardNumberError.value = DSValidators.cardNumber(v);
    _updateCanPay();
  }

  void validateExpiry(String v) {
    _expiryDirty.value = true;
    expiryError.value = DSValidators.cardExpiry(v);
    _updateCanPay();
  }

  void validateCvv(String v) {
    _cvvDirty.value = true;
    cvvError.value = DSValidators.cvv(v);
    _updateCanPay();
  }

  void validateCardName(String v) {
    _cardNameDirty.value = true;
    cardNameError.value = DSValidators.cardholderName(v);
    _updateCanPay();
  }

  void validateFirstName(String v) {
    _firstNameDirty.value = true;
    firstNameError.value = DSValidators.name(v);
    _updateCanPay();
  }

  void validateLastName(String v) {
    _lastNameDirty.value = true;
    lastNameError.value = DSValidators.name(v);
    _updateCanPay();
  }

  void validatePhone(String v) {
    _phoneDirty.value = true;
    phoneError.value = DSValidators.phone(v);
    _updateCanPay();
  }

  // ── Force-validate everything (called on submit attempt) ─────────────────
  /// Returns true if all fields pass. Also scrolls to first error.
  bool validateAll(ScrollController scroll) {
    validateCardNumber(cardNumberCtrl.text);
    validateExpiry(expiryCtrl.text);
    validateCvv(cvvCtrl.text);
    validateCardName(cardNameCtrl.text);
    validateFirstName(firstNameCtrl.text);
    validateLastName(lastNameCtrl.text);
    validatePhone(phoneCtrl.text);

    if (!canPay) {
      _scrollToFirstError(scroll);
      return false;
    }
    return true;
  }

  void _scrollToFirstError(ScrollController scroll) {
    // Find and focus first invalid field
    if (cardNumberError.value != null) {
      cardNumberFocus.requestFocus();
    } else if (expiryError.value != null) {
      expiryFocus.requestFocus();
    } else if (cvvError.value != null) {
      cvvFocus.requestFocus();
    } else if (cardNameError.value != null) {
      cardNameFocus.requestFocus();
    } else if (firstNameError.value != null) {
      firstNameFocus.requestFocus();
    } else if (lastNameError.value != null) {
      lastNameFocus.requestFocus();
    } else if (phoneError.value != null) {
      phoneFocus.requestFocus();
    }
    // Animate scroll to top of form
    scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  void onClose() {
    cardNumberCtrl.dispose();
    expiryCtrl.dispose();
    cvvCtrl.dispose();
    cardNameCtrl.dispose();
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    phoneCtrl.dispose();
    cardNumberFocus.dispose();
    expiryFocus.dispose();
    cvvFocus.dispose();
    cardNameFocus.dispose();
    firstNameFocus.dispose();
    lastNameFocus.dispose();
    phoneFocus.dispose();
  }
}
