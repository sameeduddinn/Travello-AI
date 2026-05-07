import 'dart:convert';

import 'package:get/get.dart';
import 'package:flight_app/models/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global reactive notification controller.
/// Register once via [Get.put] in main.dart (or lazily on first use).
/// Every bell badge across the app observes [unreadCount].
class NotificationController extends GetxController {
  static const String _storagePrefix = 'notifications_v1_';

  // ── Reactive notification lists ────────────────────────────────────────────
  final RxList<NotificationModel> today = <NotificationModel>[].obs;
  final RxList<NotificationModel> earlier = <NotificationModel>[].obs;

  // ── Derived reactive count ─────────────────────────────────────────────────
  final RxInt unreadCount = 0.obs;

  String _activeStorageKey = '';
  bool _isHydrating = false;

  Future<String> _resolveStorageKey() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      return '$_storagePrefix$userId';
    }

    return '${_storagePrefix}anonymous';
  }

  List<NotificationModel> _decodeList(dynamic source) {
    if (source is! List) return const <NotificationModel>[];

    return source
        .whereType<Map>()
        .map((item) => NotificationModel.fromJson(
            Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _persist() async {
    if (_activeStorageKey.isEmpty || _isHydrating) return;

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'today': today.map((n) => n.toJson()).toList(),
      'earlier': earlier.map((n) => n.toJson()).toList(),
    });
    await prefs.setString(_activeStorageKey, payload);
  }

  /// Reload notifications for whichever auth context is currently active.
  ///
  /// New users with no stored notifications will start at zero unread.
  Future<void> syncWithCurrentUser() async {
    final key = await _resolveStorageKey();
    _activeStorageKey = key;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);

    _isHydrating = true;
    try {
      if (raw == null || raw.isEmpty) {
        today.clear();
        earlier.clear();
        _recalculate();
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          today.assignAll(_decodeList(decoded['today']));
          earlier.assignAll(_decodeList(decoded['earlier']));
          _recalculate();
        } else {
          today.clear();
          earlier.clear();
          _recalculate();
        }
      }
    } catch (_) {
      today.clear();
      earlier.clear();
      _recalculate();
    } finally {
      _isHydrating = false;
    }

    await _persist();
  }

  void _recalculate() {
    unreadCount.value = today.where((n) => !n.isRead).length +
        earlier.where((n) => !n.isRead).length;
  }

  @override
  void onInit() {
    super.onInit();
    _recalculate();
    ever(today, (_) {
      _recalculate();
      _persist();
    });
    ever(earlier, (_) {
      _recalculate();
      _persist();
    });
    Future.microtask(syncWithCurrentUser);
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
