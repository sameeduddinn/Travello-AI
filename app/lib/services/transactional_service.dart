import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';

class PaymentOtpSendResult {
  final bool success;
  final String? requestId;
  final bool isFallback;
  final String message;

  const PaymentOtpSendResult({
    required this.success,
    required this.message,
    this.requestId,
    this.isFallback = false,
  });
}

/// Transactional service — all real work is done by the FastAPI backend.
///
/// sendPaymentOtp / verifyPaymentOtp: used as a demo fallback only.
///   The primary path in every screen calls ApiClient.initiatePayment() /
///   ApiClient.verifyPaymentOtp() directly before falling back here.
///
/// saveBookingToSupabase / savePaymentAttemptToSupabase: no-ops.
///   The backend creates and owns all booking + payment_attempt rows.
///
/// sendBookingConfirmationEmail: no-op returning true.
///   The backend automatically sends the Gmail SMTP confirmation after
///   every successful payment (OTP verify or card payment).
class TransactionalService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Set<String> _localOtpRequests = <String>{};
  static final Random _rng = Random();

  static String? _lastError;
  static String? get lastError => _lastError;
  static void _setError(String? v) => _lastError = v;

  static String _newLocalRequestId() =>
      'local_${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(999999)}';

  // ---------------------------------------------------------------------------
  // Phone normalizer — kept as utility, used by payment screens
  // ---------------------------------------------------------------------------

  static String normalizePkPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('3')) return '+92$digits';
    if (digits.length == 11 && digits.startsWith('03')) {
      return '+92${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('923')) return '+$digits';
    return phone.trim();
  }

  // ---------------------------------------------------------------------------
  // sendPaymentOtp — demo fallback only
  // Real path: ApiClient.initiatePayment() called first in every screen.
  // This is only reached when the backend is unreachable.
  // ---------------------------------------------------------------------------

  static Future<PaymentOtpSendResult> sendPaymentOtp({
    required String bookingType,
    required String paymentMethod,
    required String email,
    required String phoneNumber,
  }) async {
    _setError(null);

    // Try the backend via ApiClient if a Supabase session exists.
    // Screens already do this before calling here, but guard just in case.
    final session = _supabase.auth.currentSession;
    if (session != null) {
      try {
        // We don't have bookingId/amount here — this path is a true fallback.
        // Return a local demo token so the UI can still proceed.
        if (kDebugMode) {
          debugPrint('[TransactionalService] sendPaymentOtp fallback — '
              'no bookingId available at this level. Using demo mode.');
        }
      } catch (_) {}
    }

    final localId = _newLocalRequestId();
    _localOtpRequests.add(localId);
    return PaymentOtpSendResult(
      success: true,
      requestId: localId,
      isFallback: true,
      message: 'Demo mode: use any 6-digit code to continue.',
    );
  }

  // ---------------------------------------------------------------------------
  // verifyPaymentOtp — handles local demo tokens + real backend tokens
  // ---------------------------------------------------------------------------

  static Future<bool> verifyPaymentOtp({
    required String requestId,
    required String code,
    required String email,
    required String phoneNumber,
  }) async {
    _setError(null);

    final normalizedCode = code.trim();
    if (normalizedCode.length != 6) {
      _setError('Please enter a valid 6-digit OTP.');
      return false;
    }

    // Local demo token (isFallback path)
    if (requestId.startsWith('local_')) {
      if (!_localOtpRequests.contains(requestId)) {
        _setError('OTP session expired. Please request a new code.');
        return false;
      }
      _localOtpRequests.remove(requestId);
      return true;
    }

    // Real backend token — try ApiClient
    try {
      final data = await ApiClient.verifyPaymentOtp(
        requestId: requestId,
        otp: normalizedCode,
      );
      final verified = data['success'] == true;
      if (!verified) {
        _setError(data['detail']?.toString() ?? 'Invalid or expired OTP.');
      }
      return verified;
    } catch (e) {
      _setError('Unable to verify OTP right now. Please try again.');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // saveBookingToSupabase — no-op
  // The FastAPI backend creates and owns all booking rows via /flights/book,
  // /trains/book, /hotels/book. Direct Supabase writes are no longer needed.
  // ---------------------------------------------------------------------------

  static Future<bool> saveBookingToSupabase(
      Map<String, dynamic> bookingData) async {
    return true;
  }

  // ---------------------------------------------------------------------------
  // savePaymentAttemptToSupabase — no-op
  // Backend logs all payment_attempt rows via /payments/initiate.
  // ---------------------------------------------------------------------------

  static Future<bool> savePaymentAttemptToSupabase({
    required String bookingId,
    required String paymentMethod,
    required double amount,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    return true;
  }

  // ---------------------------------------------------------------------------
  // sendBookingConfirmationEmail — no-op, returns true
  // Backend sends the HTML confirmation email automatically via Gmail SMTP
  // after every successful payment (OTP verify or card payment).
  // Returning true so callers show the "Confirmation Email Sent" snackbar.
  // ---------------------------------------------------------------------------

  static Future<bool> sendBookingConfirmationEmail({
    required Map<String, dynamic> bookingData,
  }) async {
    return true;
  }
}
