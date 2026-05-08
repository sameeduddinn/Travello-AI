import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SupportMessage {
  final String id;
  final String topic;
  final String subject;
  final String description;
  final String status; // 'pending' | 'replied' | 'closed'
  final String sentAt; // ISO8601
  final String? adminReply;
  final String? repliedAt;

  SupportMessage({
    required this.id,
    required this.topic,
    required this.subject,
    required this.description,
    this.status = 'pending',
    required this.sentAt,
    this.adminReply,
    this.repliedAt,
  });

  // Handles both backend DB format and old local format
  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id:          json['id']?.toString() ?? '',
        topic:       json['topic']?.toString() ?? '',
        subject:     json['subject']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        status:      json['status']?.toString() ?? 'pending',
        sentAt:      (json['created_at'] ?? json['sentAt'])?.toString() ?? '',
        adminReply:  json['admin_reply']?.toString(),
        repliedAt:   json['replied_at']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'topic':       topic,
        'subject':     subject,
        'description': description,
        'status':      status,
        'sentAt':      sentAt,
        if (adminReply != null) 'admin_reply': adminReply,
        if (repliedAt != null)  'replied_at':  repliedAt,
      };

  String get formattedDate {
    try {
      final dt = DateTime.parse(sentAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return sentAt;
    }
  }

  String get formattedReplyDate {
    if (repliedAt == null) return '';
    try {
      final dt = DateTime.parse(repliedAt!).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class SupportMessageService {
  static const _cacheKey = 'support_messages_cache';

  /// Cache backend results locally so the tab shows something instantly on reload
  static Future<void> cacheMessages(List<SupportMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );
  }

  /// Load from local cache (used as fallback while fetching from backend)
  static Future<List<SupportMessage>> getCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
