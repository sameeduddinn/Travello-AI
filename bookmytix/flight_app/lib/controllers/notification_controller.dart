import 'package:get/get.dart';
import 'package:flight_app/models/notification.dart';

/// Global reactive notification controller.
/// Register once via [Get.put] in main.dart (or lazily on first use).
/// Every bell badge across the app observes [unreadCount].
class NotificationController extends GetxController {
  // ── Reactive notification lists ────────────────────────────────────────────
  final RxList<NotificationModel> today =
      <NotificationModel>[...notifListToday].obs;
  final RxList<NotificationModel> earlier =
      <NotificationModel>[...notifListEarlier].obs;

  // ── Derived reactive count ─────────────────────────────────────────────────
  final RxInt unreadCount = 0.obs;

  void _recalculate() {
    unreadCount.value = today.where((n) => !n.isRead).length +
        earlier.where((n) => !n.isRead).length;
  }

  @override
  void onInit() {
    super.onInit();
    _recalculate();
    ever(today, (_) => _recalculate());
    ever(earlier, (_) => _recalculate());
  }

  // ── Core Add ───────────────────────────────────────────────────────────────
  /// Prepend a new unread notification to [today].
  void addNotification(NotificationModel n) {
    today.insert(0, n);
  }

  // ── Booking Confirmation Notifications (Expedia/Booking.com style) ─────────

  /// Call this right after a flight booking is confirmed.
  void onFlightBooked({
    required String airline,
    required String flightNumber,
    required String from,
    required String to,
    required String date,
    required String bookingRef,
    String? returnDate,
    String? returnFlight,
  }) {
    addNotification(NotificationModel(
      type: 'success',
      category: 'flight',
      tag: airline,
      title: '$airline $flightNumber - Booking Confirmed',
      subtitle: '$from -> $to | $date | Ref: $bookingRef',
      date: 'Just now',
      isRead: false,
    ));

    // Check-in reminder (online check-in opens 24h before)
    addNotification(NotificationModel(
      type: 'info',
      category: 'flight',
      tag: airline,
      title: 'Online check-in opens soon',
      subtitle:
          '$airline $flightNumber · Check-in opens 24 hrs before departure on $date',
      date: 'Just now',
      isRead: false,
    ));

    // Leave-home reminder for outbound
    addNotification(NotificationModel(
      type: 'warning',
      category: 'flight',
      tag: 'Reminder',
      title: 'Leave home 3 hrs before departure',
      subtitle:
          'For $flightNumber on $date - allow time for check-in, security & boarding',
      date: 'Just now',
      isRead: false,
    ));

    // Return flight reminders (if round trip)
    if (returnDate != null && returnFlight != null) {
      addNotification(NotificationModel(
        type: 'warning',
        category: 'flight',
        tag: 'Reminder',
        title: '24-hr return flight reminder - $returnFlight',
        subtitle:
            '$to -> $from | $returnDate | Online check-in opens now. Don\'t forget your baggage allowance.',
        date: 'Just now',
        isRead: false,
      ));
    }
  }

  /// Call this after a hotel booking is confirmed.
  void onHotelBooked({
    required String hotelName,
    required String city,
    required String checkIn,
    required String checkOut,
    required int nights,
    required int guests,
    required String bookingRef,
  }) {
    addNotification(NotificationModel(
      type: 'success',
      category: 'hotel',
      tag: 'Hotel',
      title: '$hotelName - Booking Confirmed',
      subtitle:
          '$city | Check-in $checkIn | Check-out $checkOut | $nights nights | Ref: $bookingRef',
      date: 'Just now',
      isRead: false,
    ));

    // Check-in reminder
    addNotification(NotificationModel(
      type: 'info',
      category: 'hotel',
      tag: 'Hotel',
      title: 'Hotel check-in reminder - $hotelName',
      subtitle:
          'Check-in on $checkIn. Standard check-in time is 14:00. Early check-in subject to availability.',
      date: 'Just now',
      isRead: false,
    ));

    // Leave-home reminder
    addNotification(NotificationModel(
      type: 'warning',
      category: 'hotel',
      tag: 'Reminder',
      title: 'Plan your journey to $hotelName',
      subtitle:
          'Check-in $checkIn - book a cab or plan your route in advance to arrive on time.',
      date: 'Just now',
      isRead: false,
    ));
  }

  /// Call this after a train booking is confirmed.
  void onTrainBooked({
    required String trainName,
    required String from,
    required String to,
    required String date,
    required String departureTime,
    required String seat,
    required String pnr,
  }) {
    addNotification(NotificationModel(
      type: 'success',
      category: 'train',
      tag: 'Train',
      title: '$trainName - Ticket Confirmed',
      subtitle: '$from -> $to | $date | Seat $seat | PNR: $pnr',
      date: 'Just now',
      isRead: false,
    ));

    // Platform & boarding reminder
    addNotification(NotificationModel(
      type: 'info',
      category: 'train',
      tag: 'Train',
      title: 'Arrive at station 30 min before departure',
      subtitle:
          '$trainName departs $date at $departureTime from $from - allow time for platform & boarding.',
      date: 'Just now',
      isRead: false,
    ));

    // Leave-home reminder
    addNotification(NotificationModel(
      type: 'warning',
      category: 'train',
      tag: 'Reminder',
      title: 'Plan your journey to $from station',
      subtitle:
          'Train departs $date at $departureTime - check traffic and leave home early.',
      date: 'Just now',
      isRead: false,
    ));
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void markAllRead() {
    today.value = today.map((n) => n.copyWith(isRead: true)).toList();
    earlier.value = earlier.map((n) => n.copyWith(isRead: true)).toList();
    today.refresh();
    earlier.refresh();
  }

  void markRead(NotificationModel notif) {
    final tIdx =
        today.indexWhere((n) => n.title == notif.title && n.date == notif.date);
    if (tIdx != -1) {
      today[tIdx] = notif.copyWith(isRead: true);
    } else {
      final eIdx = earlier
          .indexWhere((n) => n.title == notif.title && n.date == notif.date);
      if (eIdx != -1) earlier[eIdx] = notif.copyWith(isRead: true);
    }
  }

  void clearAll() {
    today.clear();
    earlier.clear();
  }

  void clearToday() => today.clear();
  void clearEarlier() => earlier.clear();
}
