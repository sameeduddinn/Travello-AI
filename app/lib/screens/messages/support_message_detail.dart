import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/support_message_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SupportMessageDetail extends StatelessWidget {
  const SupportMessageDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final msg = Get.arguments as SupportMessage;
    final hasReply = msg.adminReply != null && msg.adminReply!.trim().isNotEmpty;

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
        title: const Text(
          'Support Message',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _StatusBadge(status: msg.status),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Original complaint card ──────────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF5D8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.support_agent_rounded,
                          color: TravelloTheme.primaryMain, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.topic,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: TravelloTheme.primaryMain),
                          ),
                          Text(
                            'You · ${msg.formattedDate}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _FieldLabel(text: 'SUBJECT'),
                const SizedBox(height: 4),
                Text(
                  msg.subject,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 14),
                const _FieldLabel(text: 'YOUR MESSAGE'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    msg.description,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Reply card ───────────────────────────────────────────────────
          _SectionCard(
            child: hasReply
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.mark_email_read_rounded,
                                color: Colors.green.shade600, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Support Team',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700),
                                ),
                                Text(
                                  msg.formattedReplyDate.isNotEmpty
                                      ? msg.formattedReplyDate
                                      : 'Replied',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _FieldLabel(text: 'REPLY'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          msg.adminReply!,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade800,
                              height: 1.6),
                        ),
                      ),
                    ],
                  )
                : _EmptyReplyState(status: msg.status),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF999999),
            letterSpacing: 0.8),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'replied':
        return Colors.green.shade600;
      case 'closed':
        return Colors.grey.shade500;
      default:
        return const Color(0xFFD4AF37);
    }
  }

  IconData get _icon {
    switch (status) {
      case 'replied':
        return Icons.check_circle_rounded;
      case 'closed':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  String get _label {
    switch (status) {
      case 'replied':
        return 'Replied';
      case 'closed':
        return 'Closed';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 12, color: _color),
            const SizedBox(width: 4),
            Text(_label,
                style: TextStyle(
                    fontSize: 11,
                    color: _color,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _EmptyReplyState extends StatelessWidget {
  final String status;
  const _EmptyReplyState({required this.status});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(Icons.hourglass_top_rounded,
                size: 36, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              status == 'closed' ? 'This ticket is closed.' : 'Waiting for reply…',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              status == 'closed'
                  ? 'No reply was recorded for this ticket.'
                  : 'Our support team will respond within 24 hours.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
