class NotificationModel {
  final String type; // 'success' | 'warning' | 'error' | 'info'
  final String category; // 'flight' | 'train' | 'hotel' | 'emergency' | 'ai'
  final String
      tag; // e.g. 'PIA', 'AirBlue', 'Train', 'Hotel', 'AI Trip', 'Emergency'
  final String title;
  final String subtitle;
  final String date;
  final String? image;
  final bool isRead;

  NotificationModel({
    required this.type,
    required this.category,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.date,
    this.image,
    this.isRead = false,
  });

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        type: type,
        category: category,
        tag: tag,
        title: title,
        subtitle: subtitle,
        date: date,
        image: image,
        isRead: isRead ?? this.isRead,
      );
}

// ── TODAY ─────────────────────────────────────────────────────────────────────
final List<NotificationModel> notifListToday = [
  NotificationModel(
    type: 'info',
    category: 'flight',
    tag: 'PIA',
    title: 'PIA PK-302 — Boarding open',
    subtitle: 'Karachi (KHI) → Lahore (LHE) · Gate B4 · Dep. 14:30',
    date: '2 hours ago',
    isRead: false,
  ),
  NotificationModel(
    type: 'info',
    category: 'hotel',
    tag: 'Hotel',
    title: 'Hotel check-in reminder',
    subtitle: 'Pearl Continental Lahore — Check-in tomorrow at 14:00',
    date: '5 hours ago',
    isRead: false,
  ),
  NotificationModel(
    type: 'info',
    category: 'ai',
    tag: 'AI Trip',
    title: 'Your Lahore trip is ready',
    subtitle:
        'Hotels, flights and activities have been suggested based on your preferences',
    date: 'Wednesday',
    isRead: false,
  ),
];

// ── EARLIER ───────────────────────────────────────────────────────────────────
final List<NotificationModel> notifListEarlier = [
  NotificationModel(
    type: 'success',
    category: 'train',
    tag: 'Train',
    title: 'Pakistan Railways — Ticket confirmed',
    subtitle: 'Karachi Express · Seat 14A · Dep. 7 Apr, 08:00 · PNR: 7842XXX',
    date: 'Tuesday',
    isRead: true,
  ),
  NotificationModel(
    type: 'success',
    category: 'flight',
    tag: 'AirBlue',
    title: 'AirBlue PA-201 — E-ticket ready',
    subtitle: 'Islamabad (ISB) → Karachi (KHI) · 10 Apr · Booking #AB9921',
    date: 'Monday',
    isRead: true,
  ),
  NotificationModel(
    type: 'warning',
    category: 'emergency',
    tag: 'Emergency',
    title: 'Nearby hospitals saved — Lahore',
    subtitle:
        'Services Medical Hospital, Shaukat Khanum, Jinnah Hospital nearby',
    date: 'Monday',
    isRead: true,
  ),
  NotificationModel(
    type: 'info',
    category: 'flight',
    tag: 'AirSial',
    title: 'Online check-in open — AirSial',
    subtitle: 'PF-101 Lahore → Multan · Check-in closes 1 hr before departure',
    date: 'Last week',
    isRead: true,
  ),
  NotificationModel(
    type: 'success',
    category: 'flight',
    tag: 'Serene',
    title: 'Serene Air SR-601 — Booking Confirmed',
    subtitle:
        'Karachi (KHI) → Islamabad (ISB) · 15 Apr, 07:45 · Ref: SA20260415C',
    date: 'Last week',
    isRead: true,
  ),
  NotificationModel(
    type: 'info',
    category: 'hotel',
    tag: 'Hotel',
    title: 'Early check-in available',
    subtitle:
        'Serena Hotel Islamabad — Early check-in from 10:00 AM on your arrival day',
    date: 'Last week',
    isRead: true,
  ),
];

// Combined (for unread badge)
List<NotificationModel> get notifList =>
    [...notifListToday, ...notifListEarlier];
