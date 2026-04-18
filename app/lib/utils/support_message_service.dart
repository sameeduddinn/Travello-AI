import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SupportMessage {
  final String id;
  final String topic;
  final String subject;
  final String description;
  final String status; // 'pending' | 'replied' | 'closed'
  final String sentAt; // ISO8601 string
  final String? replyText;

  SupportMessage({
    required this.id,
    required this.topic,
    required this.subject,
    required this.description,
    this.status = 'pending',
    required this.sentAt,
    this.replyText,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'subject': subject,
        'description': description,
        'status': status,
        'sentAt': sentAt,
        if (replyText != null) 'replyText': replyText,
      };

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: json['id'] as String,
        topic: json['topic'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String,
        status: (json['status'] as String?) ?? 'pending',
        sentAt: json['sentAt'] as String,
        replyText: json['replyText'] as String?,
      );

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
}

class SupportMessageService {
  static const _key = 'support_messages';

  static Future<List<SupportMessage>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  static Future<void> send({
    required String topic,
    required String subject,
    required String description,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();
    final newMsg = SupportMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      topic: topic,
      subject: subject,
      description: description,
      status: 'pending',
      sentAt: DateTime.now().toUtc().toIso8601String(),
    );
    final updated = [newMsg, ...existing];
    await prefs.setString(
        _key, jsonEncode(updated.map((m) => m.toJson()).toList()));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
