import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flight_app/models/notification.dart';
import 'package:get/get.dart';

/// Singleton service — call from any booking confirmation screen to
/// push a real notification into the notifications panel.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  // ── helpers ───────────────────────────────────────────────────────────────

  String _airlineTag(String airline) {
    final a = airline.toLowerCase();
    if (a.contains('pia') || a.contains('pakistan international')) return 'PIA';
    if (a.contains('airblue')) return 'AirBlue';
    if (a.contains('airsial')) return 'AirSial';
    if (a.contains('serene')) return 'Serene';
    return airline.split(' ').first;
  }

  /// Route through the reactive [NotificationController] when registered,
  /// so the bell badge count updates instantly everywhere.
  void _prepend(NotificationModel n) {
    try {
      Get.find<NotificationController>().addNotification(n);
    } catch (_) {
      // Controller not yet registered (very early startup) — use static list
      notifListToday.insert(0, n);
    }
  }

  // ── FLIGHT ────────────────────────────────────────────────────────────────

  /// Booking confirmed — calls all related reminders automatically
  /// (check-in open, leave-home, and optional return-flight 24hr reminder).
  void flightBooked({
    required String airline,
    required String flightNumber,
    required String fromCode,
    required String toCode,
    required String date,
    required String departure,
    required String pnr,
    String seatClass = 'Economy',
    // Return trip fields
    String? returnDate,
    String? returnDeparture,
    String? returnFlightNumber,
  }) {
    // 1. Booking confirmation
    _prepend(NotificationModel(
      type: 'success',
      category: 'flight',
      tag: _airlineTag(airline),
      title: '$airline $flightNumber - Booking Confirmed',
      subtitle:
          '$fromCode -> $toCode | $date, $departure | $seatClass | PNR: $pnr',
      date: 'Just now',
      isRead: false,
    ));

    // 2. Online check-in reminder
    _prepend(NotificationModel(
      type: 'info',
      category: 'flight',
      tag: _airlineTag(airline),
      title: 'Online check-in now open - $airline $flightNumber',
      subtitle:
          '$fromCode -> $toCode | Dep $departure on $date | Check-in closes 1 hr before departure',
      date: 'Just now',
      isRead: false,
    ));

    // 3. Leave-home reminder (3 hrs before departure)
    _prepend(NotificationModel(
      type: 'warning',
      category: 'flight',
      tag: 'Reminder',
      title: 'Leave home 3 hrs before your flight',
      subtitle:
          '$airline $flightNumber | $fromCode -> $toCode | $date at $departure - allow time for check-in, security and boarding',
      date: 'Just now',
      isRead: false,
    ));

    // 4. Return flight 24-hr reminder (round trip)
    if (returnDate != null && returnFlightNumber != null) {
      final retFlight = returnFlightNumber.isNotEmpty
          ? returnFlightNumber
          : '$flightNumber (Return)';
      _prepend(NotificationModel(
        type: 'warning',
        category: 'flight',
        tag: _airlineTag(airline),
        title: '24-hr Return Flight Reminder - $retFlight',
        subtitle:
            '$toCode -> $fromCode | $returnDate${returnDeparture != null ? " at $returnDeparture" : ""} | '
            'Check-in open. Do not forget: baggage allowance, travel docs and CNIC.',
        date: 'Just now',
        isRead: false,
      ));

      // 5. Return baggage prep reminder — pack & confirm baggage allowance
      _prepend(NotificationModel(
        type: 'info',
        category: 'flight',
        tag: _airlineTag(airline),
        title: 'Pack return baggage before boarding - $retFlight',
        subtitle:
            'Your return flight $toCode -> $fromCode departs $returnDate${returnDeparture != null ? " at $returnDeparture" : ""}. '
            'Confirm your baggage allowance, avoid overweight fees and pack essentials 24 hrs in advance.',
        date: 'Just now',
        isRead: false,
      ));
    }
  }

  void flightCheckInOpen({
    required String airline,
    required String flightNumber,
    required String fromCode,
    required String toCode,
    required String departure,
    required String pnr,
  }) {
    _prepend(NotificationModel(
      type: 'info',
      category: 'flight',
      tag: _airlineTag(airline),
      title: '$airline $flightNumber - Online check-in open',
      subtitle:
          '$fromCode -> $toCode | Dep. $departure | Check-in closes 1 hr before departure',
      date: 'Just now',
      isRead: false,
    ));
  }

  // ── TRAIN ─────────────────────────────────────────────────────────────────

  /// Booking confirmed + automatic platform & leave-home reminder.
  void trainBooked({
    required String trainName,
    required String fromStation,
    required String toStation,
    required String date,
    required String departure,
    required String seatClass,
    required String coach,
    required String seat,
    required String pnr,
  }) {
    // 1. Booking confirmation
    _prepend(NotificationModel(
      type: 'success',
      category: 'train',
      tag: 'Train',
      title: 'Pakistan Railways - Ticket Confirmed',
      subtitle:
          '$trainName | $fromStation -> $toStation | $date, $departure | $seatClass | Coach $coach, Seat $seat | PNR: $pnr',
      date: 'Just now',
      isRead: false,
    ));

    // 2. Platform boarding reminder
    _prepend(NotificationModel(
      type: 'info',
      category: 'train',
      tag: 'Train',
      title: 'Arrive at station 30 min early - $trainName',
      subtitle:
          '$fromStation -> $toStation | $date at $departure | Carry CNIC. Platform announced 15 min before departure.',
      date: 'Just now',
      isRead: false,
    ));

    // 3. Leave-home reminder
    _prepend(NotificationModel(
      type: 'warning',
      category: 'train',
      tag: 'Reminder',
      title: 'Plan your journey to $fromStation station',
      subtitle:
          '$trainName departs $date at $departure - check traffic and leave home early to avoid missing your train.',
      date: 'Just now',
      isRead: false,
    ));
  }

  // ── HOTEL ─────────────────────────────────────────────────────────────────

  void hotelBooked({
    required String hotelName,
    required String city,
    required String roomType,
    required String checkIn,
    required String checkOut,
    required String bookingRef,
  }) {
    // 1. Booking confirmation
    _prepend(NotificationModel(
      type: 'success',
      category: 'hotel',
      tag: 'Hotel',
      title: '$hotelName - Booking Confirmed',
      subtitle:
          '$city | $roomType | Check-in: $checkIn | Check-out: $checkOut | Ref: $bookingRef',
      date: 'Just now',
      isRead: false,
    ));

    // 2. Check-in reminder
    _prepend(NotificationModel(
      type: 'info',
      category: 'hotel',
      tag: 'Hotel',
      title: 'Hotel check-in reminder - $hotelName',
      subtitle:
          'Check-in $checkIn at 14:00. Early check-in subject to availability. Carry valid CNIC/Passport. Ref: $bookingRef',
      date: 'Just now',
      isRead: false,
    ));

    // 3. Leave-home / travel reminder
    _prepend(NotificationModel(
      type: 'warning',
      category: 'hotel',
      tag: 'Reminder',
      title: 'Plan your journey to $hotelName',
      subtitle:
          'Check-in $checkIn - book a cab or reserve transport in advance to reach the hotel on time.',
      date: 'Just now',
      isRead: false,
    ));
  }

  void hotelCheckInReminder({
    required String hotelName,
    required String checkInTime,
    required String bookingRef,
  }) {
    _prepend(NotificationModel(
      type: 'info',
      category: 'hotel',
      tag: 'Hotel',
      title: '$hotelName - Check-in Reminder',
      subtitle:
          'Check-in today at $checkInTime. Please carry valid CNIC or Passport. Ref: $bookingRef',
      date: 'Just now',
      isRead: false,
    ));
  }
}
