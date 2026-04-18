import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flight_app/models/notification.dart';
import 'package:flight_app/utils/support_message_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class Notification extends StatefulWidget {
  const Notification({super.key});

  @override
  State<Notification> createState() => _NotificationState();
}

class _NotificationState extends State<Notification>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late NotificationController _ctrl;

  // Local mutable copies mirroring controller (rebuilt after actions)
  late List<NotificationModel> _today;
  late List<NotificationModel> _earlier;
  List<SupportMessage> _messages = [];

  int get _unreadCount =>
      [..._today, ..._earlier].where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<NotificationController>();
    final args = Get.arguments;
    final initialTab =
        (args is Map && args['tab'] != null) ? args['tab'] as int : 0;
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: initialTab);
    _today = List.from(_ctrl.today);
    _earlier = List.from(_ctrl.earlier);
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final msgs = await SupportMessageService.getAll();
    if (mounted) setState(() => _messages = msgs);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _markAllRead() {
    _ctrl.markAllRead();
    setState(() {
      _today = List.from(_ctrl.today);
      _earlier = List.from(_ctrl.earlier);
    });
  }

  void _clearAll() {
    _ctrl.clearAll();
    setState(() {
      _today.clear();
      _earlier.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unreadCount;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: const Text('Updates',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(
                    fontSize: 13,
                    color: TravelloTheme.primaryMain,
                    fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: TravelloTheme.primaryMain,
                indicatorWeight: 2.5,
                labelColor: TravelloTheme.primaryMain,
                unselectedLabelColor: Colors.grey.shade500,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Notifications'),
                        if (unread > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$unread',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Messages'),
                ],
              ),
              Divider(height: 1, color: Colors.grey.shade200),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsTab(),
          _buildMessagesTab(),
        ],
      ),
    );
  }

  // ── NOTIFICATIONS TAB ────────────────────────────────────────────────────────
  Widget _buildNotificationsTab() {
    final hasAny = _today.isNotEmpty || _earlier.isNotEmpty;
    if (!hasAny) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFDF5D8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 40, color: TravelloTheme.primaryMain),
            ),
            const SizedBox(height: 20),
            const Text("You're all caught up!",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            Text('No new notifications at the moment.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return Column(
      children: [
        // ── Action bar ─────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_today.length + _earlier.length} notification${(_today.length + _earlier.length) == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
              GestureDetector(
                onTap: () => showDialog(
                  context: Get.context!,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear all notifications?'),
                    content: const Text(
                        'All notifications will be permanently removed.'),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: TravelloTheme.primaryMain),
                        onPressed: () {
                          Get.back();
                          _clearAll();
                        },
                        child: const Text('Clear All',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined,
                        size: 17, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    Text('Clear all',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        // ── List ───────────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            children: [
              if (_today.isNotEmpty) ...[
                const _SectionHeader(label: 'TODAY'),
                ..._today.asMap().entries.map((e) => _NotifTile(
                      item: e.value,
                      onDismiss: () {
                        setState(() => _today.removeAt(e.key));
                        _ctrl.today.removeAt(e.key);
                      },
                    )),
              ],
              if (_earlier.isNotEmpty) ...[
                const _SectionHeader(label: 'EARLIER'),
                ..._earlier.asMap().entries.map((e) => _NotifTile(
                      item: e.value,
                      onDismiss: () {
                        setState(() => _earlier.removeAt(e.key));
                        _ctrl.earlier.removeAt(e.key);
                      },
                    )),
              ],
              SizedBox(height: 20 + MediaQuery.of(Get.context!).padding.bottom),
            ],
          ),
        ),
      ],
    );
  }

  // ── MESSAGES TAB ─────────────────────────────────────────────────────────────
  Widget _buildMessagesTab() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF5D8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded,
                          color: TravelloTheme.primaryMain, size: 28),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: TravelloTheme.primaryMain,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('No messages yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Messages you send via Contact Admin\nwill appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Action bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_messages.length} message${_messages.length == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear all messages?'),
                    content: const Text(
                        'All support messages will be permanently removed.'),
                    actions: [
                      TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: TravelloTheme.primaryMain),
                        onPressed: () async {
                          Get.back();
                          await SupportMessageService.clearAll();
                          _loadMessages();
                        },
                        child: const Text('Clear All',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined,
                        size: 17, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    Text('Clear all',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _messages.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, i) => _MessageTile(msg: _messages[i]),
          ),
        ),
      ],
    );
  }
}

// ── Section header (TODAY / EARLIER) ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFF5F5F5),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF888888),
                letterSpacing: 1.0)),
      );
}

// ── Notification Tile ─────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onDismiss;
  const _NotifTile({required this.item, required this.onDismiss});

  // Left icon square — color + icon by category
  Color get _iconBg {
    switch (item.category) {
      case 'flight':
        return const Color(0xFFFDF5D8);
      case 'train':
        return const Color(0xFFFEF3DC);
      case 'hotel':
        return const Color(0xFFFDF5D8);
      case 'emergency':
        return const Color(0xFFFFEBEE);
      case 'ai':
        return const Color(0xFFFDF0C0);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Color get _iconColor {
    switch (item.category) {
      case 'flight':
        return const Color(0xFFD4AF37);
      case 'train':
        return const Color(0xFFB8935C);
      case 'hotel':
        return const Color(0xFFD4AF37);
      case 'emergency':
        return const Color(0xFFC62828);
      case 'ai':
        return const Color(0xFFD4AF37);
      default:
        return Colors.grey;
    }
  }

  IconData get _iconData {
    switch (item.category) {
      case 'flight':
        return Icons.flight_rounded;
      case 'train':
        return Icons.train_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'emergency':
        return Icons.local_hospital_rounded;
      case 'ai':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  // Tag badge colors per brand
  Color _tagColor(String tag) {
    switch (tag) {
      case 'PIA':
        return const Color(0xFFB8860B); // dark gold
      case 'AirBlue':
        return const Color(0xFFB8935C); // warm gold-brown
      case 'AirSial':
        return const Color(0xFFB8860B); // dark gold
      case 'Serene':
        return const Color(0xFFB8935C); // warm gold-brown
      case 'Train':
        return const Color(0xFFC49A3C); // muted gold
      case 'Hotel':
        return const Color(0xFFB8860B); // dark gold
      case 'AI Trip':
        return const Color(0xFFC49A3C); // muted gold
      case 'Emergency':
        return const Color(0xFFC62828); // red — kept for safety
      default:
        return const Color(0xFFB8935C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.title + item.date),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red.shade50,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: item.isRead ? Colors.white : const Color(0xFFFEF9EC),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unread dot
                Padding(
                  padding: const EdgeInsets.only(top: 16, right: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.isRead
                          ? Colors.transparent
                          : TravelloTheme.primaryMain,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Category icon square
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: _iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(_iconData, color: _iconColor, size: 22),
                ),
                const SizedBox(width: 11),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {},
                            child: Icon(Icons.more_horiz,
                                size: 18, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Tag badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _tagColor(item.tag).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(item.tag,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _tagColor(item.tag),
                            )),
                      ),
                      const SizedBox(height: 4),
                      Text(item.subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Text(item.date,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 0.6,
            indent: 69,
            color: Color(0xFFEEEEEE),
          ),
        ],
      ),
    );
  }
}

// ── Support Message Tile ──────────────────────────────────────────────────────
class _MessageTile extends StatelessWidget {
  final SupportMessage msg;
  const _MessageTile({required this.msg});

  Color get _statusColor {
    switch (msg.status) {
      case 'replied':
        return Colors.green.shade600;
      case 'closed':
        return Colors.grey.shade500;
      default:
        return const Color(0xFFD4AF37);
    }
  }

  String get _statusLabel {
    switch (msg.status) {
      case 'replied':
        return 'Replied';
      case 'closed':
        return 'Closed';
      default:
        return 'Pending';
    }
  }

  IconData get _statusIcon {
    switch (msg.status) {
      case 'replied':
        return Icons.check_circle_rounded;
      case 'closed':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFDF5D8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: TravelloTheme.primaryMain, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        msg.topic,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, size: 11, color: _statusColor),
                          const SizedBox(width: 3),
                          Text(_statusLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _statusColor,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  msg.subject,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  msg.description,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Support Team · ${msg.formattedDate}',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
