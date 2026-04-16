import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

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

class TransactionalService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final Set<String> _localOtpRequests = <String>{};
  static final Random _rng = Random();

  static String? _lastError;
  static String? get lastError => _lastError;

  static void _setError(String? value) {
    _lastError = value;
  }

  static String _newLocalRequestId() {
    return 'local_${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(999999)}';
  }

  static String normalizePkPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('3')) {
      return '+92$digits';
    }
    if (digits.length == 11 && digits.startsWith('03')) {
      return '+92${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('923')) {
      return '+$digits';
    }
    return phone.trim();
  }

  static Future<PaymentOtpSendResult> sendPaymentOtp({
    required String bookingType,
    required String paymentMethod,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      _setError(null);

      final response = await _supabase.functions.invoke(
        'send-payment-otp',
        body: <String, dynamic>{
          'bookingType': bookingType,
          'paymentMethod': paymentMethod,
          'email': email.trim().toLowerCase(),
          'phone': normalizePkPhone(phoneNumber),
        },
      );

      final status = response.status;
      final responseOk = status >= 200 && status < 300;
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{});

      if (!responseOk) {
        final msg =
            map['message']?.toString() ?? 'Unable to send OTP right now.';
        _setError(msg);
        return PaymentOtpSendResult(success: false, message: msg);
      }

      final requestId = map['requestId']?.toString() ??
          map['request_id']?.toString() ??
          map['otpRequestId']?.toString();

      if (requestId == null || requestId.isEmpty) {
        _setError('OTP request id missing from backend response.');
        return const PaymentOtpSendResult(
          success: false,
          message: 'OTP service response is incomplete.',
        );
      }

      final message = map['message']?.toString() ?? 'OTP sent successfully.';
      return PaymentOtpSendResult(
        success: true,
        requestId: requestId,
        message: message,
      );
    } catch (_) {
      // Demo-safe fallback if edge function is not deployed yet.
      final localId = _newLocalRequestId();
      _localOtpRequests.add(localId);
      return PaymentOtpSendResult(
        success: true,
        requestId: localId,
        isFallback: true,
        message:
            'Demo mode: OTP backend not configured yet. Use any 6-digit code to continue.',
      );
    }
  }

  static Future<bool> verifyPaymentOtp({
    required String requestId,
    required String code,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      _setError(null);

      final normalizedCode = code.trim();
      if (normalizedCode.length != 6) {
        _setError('Please enter a valid 6-digit OTP.');
        return false;
      }

      if (requestId.startsWith('local_')) {
        final exists = _localOtpRequests.contains(requestId);
        if (!exists) {
          _setError('OTP session expired. Please request a new code.');
          return false;
        }
        _localOtpRequests.remove(requestId);
        return true;
      }

      final response = await _supabase.functions.invoke(
        'verify-payment-otp',
        body: <String, dynamic>{
          'requestId': requestId,
          'code': normalizedCode,
          'email': email.trim().toLowerCase(),
          'phone': normalizePkPhone(phoneNumber),
        },
      );

      final status = response.status;
      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{});

      final responseOk = status >= 200 && status < 300;
      final verified = map['verified'] == true || map['success'] == true;

      if (responseOk && verified) return true;

      final msg = map['message']?.toString() ?? 'Invalid or expired OTP.';
      _setError(msg);
      return false;
    } catch (e) {
      _setError('Unable to verify OTP right now. Please try again.');
      return false;
    }
  }

  static Future<bool> saveBookingToSupabase(
      Map<String, dynamic> bookingData) async {
    try {
      _setError(null);
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final payload = <String, dynamic>{
        'user_id': user.id,
        'booking_id':
            (bookingData['bookingId'] ?? bookingData['pnr'] ?? '').toString(),
        'booking_type': (bookingData['bookingType'] ?? 'flight').toString(),
        'pnr': bookingData['pnr']?.toString(),
        'transaction_id': bookingData['transactionId']?.toString(),
        'contact_email': (bookingData['email'] ?? '').toString(),
        'contact_phone': bookingData['phone']?.toString(),
        'total_amount': (bookingData['total'] as num?)?.toDouble() ??
            (bookingData['grandTotal'] as num?)?.toDouble() ??
            0,
        'currency':
            (bookingData['currency'] ?? 'PKR').toString().replaceAll(' ', ''),
        'status': 'confirmed',
        'raw_payload': bookingData,
      };

      if ((payload['booking_id'] as String).isEmpty) {
        payload['booking_id'] =
            'BK${DateTime.now().millisecondsSinceEpoch}${_rng.nextInt(999)}';
      }

      await _supabase
          .from('bookings')
          .upsert(payload, onConflict: 'booking_id');
      return true;
    } catch (_) {
      _setError(
          'Supabase booking sync failed. Check bookings table/RLS setup.');
      return false;
    }
  }

  static Future<bool> savePaymentAttemptToSupabase({
    required String bookingId,
    required String paymentMethod,
    required double amount,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _setError(null);
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase.from('payment_attempts').insert(<String, dynamic>{
        'user_id': user.id,
        'booking_id': bookingId,
        'payment_method': paymentMethod,
        'amount': amount,
        'currency': 'PKR',
        'status': status,
        'metadata': metadata ?? <String, dynamic>{},
      });
      return true;
    } catch (_) {
      _setError('Supabase payment attempt logging failed.');
      return false;
    }
  }

  static Future<bool> sendBookingConfirmationEmail({
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      _setError(null);
      final response = await _supabase.functions.invoke(
        'send-booking-confirmation',
        body: bookingData,
      );

      final ok = response.status >= 200 && response.status < 300;
      if (!ok) {
        _setError('Booking email function failed (${response.status}).');
      }
      return ok;
    } catch (_) {
      _setError('Booking email service unavailable.');
      return false;
    }
  }
}
