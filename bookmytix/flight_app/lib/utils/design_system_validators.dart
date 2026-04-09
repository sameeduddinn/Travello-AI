/// DSValidators
/// Pure, composable field validators for the booking flow.
/// Each function returns null on pass, or a human-readable error string.
abstract class DSValidators {
  // ── Name ────────────────────────────────────────────────────────────────────
  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    if (v.trim().length < 2) return 'Minimum 2 characters';
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(v.trim())) {
      return 'Letters only';
    }
    return null;
  }

  // ── Email ───────────────────────────────────────────────────────────────────
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // ── Phone ───────────────────────────────────────────────────────────────────
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'Too short — enter full number';
    if (digits.length > 15) return 'Too long — check your number';
    return null;
  }

  // ── Card number (with Luhn check) ───────────────────────────────────────────
  static String? cardNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Card number is required';
    final digits = v.replaceAll(' ', '');
    if (digits.length != 16) return 'Must be 16 digits';
    if (!RegExp(r'^\d{16}$').hasMatch(digits)) return 'Digits only';
    if (!_luhn(digits)) return 'Invalid card number';
    return null;
  }

  // ── Expiry MM/YY ────────────────────────────────────────────────────────────
  static String? cardExpiry(String? v) {
    if (v == null || v.trim().isEmpty) return 'Expiry date is required';
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(v)) return 'Use MM/YY format';
    final parts = v.split('/');
    final month = int.tryParse(parts[0]) ?? 0;
    if (month < 1 || month > 12) return 'Invalid month';
    final now = DateTime.now();
    final year = 2000 + (int.tryParse(parts[1]) ?? 0);
    if (year < now.year || (year == now.year && month < now.month)) {
      return 'This card has expired';
    }
    return null;
  }

  // ── CVV ─────────────────────────────────────────────────────────────────────
  static String? cvv(String? v) {
    if (v == null || v.trim().isEmpty) return 'CVV is required';
    if (!RegExp(r'^\d{3,4}$').hasMatch(v.trim())) {
      return 'Enter 3 or 4 digits';
    }
    return null;
  }

  // ── Cardholder name ─────────────────────────────────────────────────────────
  static String? cardholderName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Cardholder name is required';
    if (v.trim().length < 3) return 'Enter full name as on card';
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(v.trim())) {
      return 'Letters and spaces only';
    }
    return null;
  }

  // ── Luhn algorithm ──────────────────────────────────────────────────────────
  static bool _luhn(String number) {
    int sum = 0;
    bool isEven = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);
      if (isEven) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      isEven = !isEven;
    }
    return sum % 10 == 0;
  }

  // ── Compose multiple validators ──────────────────────────────────────────────
  static String? Function(String?) compose(
      List<String? Function(String?)> validators) {
    return (String? value) {
      for (final fn in validators) {
        final result = fn(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
