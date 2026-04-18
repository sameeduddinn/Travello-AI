import 'package:supabase_flutter/supabase_flutter.dart';

class BookingEmailSendResult {
  final bool success;
  final String message;
  final String? recipient;

  const BookingEmailSendResult({
    required this.success,
    required this.message,
    this.recipient,
  });
}

class BookingEmailService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final RegExp _emailRegex =
      RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');

  static bool _isValidEmail(String email) {
    return _emailRegex.hasMatch(email.trim());
  }

  static Future<BookingEmailSendResult> sendBookingEmail({
    required String email,
    required String name,
    required String destination,
    required num amount,
    required String bookingId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final safeName = name.trim();
    final safeDestination = destination.trim();
    final safeBookingId = bookingId.trim();

    if (!_isValidEmail(normalizedEmail)) {
      return const BookingEmailSendResult(
        success: false,
        message: 'Valid email is required.',
      );
    }
    if (safeName.length < 2 ||
        safeDestination.length < 2 ||
        safeBookingId.length < 3 ||
        amount <= 0) {
      return const BookingEmailSendResult(
        success: false,
        message: 'Invalid booking email payload.',
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'send-booking-email',
        body: <String, dynamic>{
          'email': normalizedEmail,
          'name': safeName,
          'destination': safeDestination,
          'amount': amount,
          'booking_id': safeBookingId,
        },
      );

      final data = response.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{});

      final ok = response.status >= 200 && response.status < 300;
      final message = map['message']?.toString() ??
          (ok
              ? 'Booking confirmation email sent.'
              : 'Unable to send booking email.');

      return BookingEmailSendResult(
        success: ok,
        message: message,
        recipient: map['recipient']?.toString(),
      );
    } catch (e) {
      return BookingEmailSendResult(
        success: false,
        message: 'Booking email call failed: $e',
      );
    }
  }
}
