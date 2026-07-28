// =============================================================================
// ai_service.dart
// Supabase persistence layer for the AI Agent feature.
//
// Covers:
//   • ai_conversations  — chat session CRUD
//   • ai_messages       — per-turn message persistence
//   • agent_tasks       — create and monitor autonomous tasks
//   • ai_feedback       — thumbs-up / thumbs-down on messages
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_chat.dart';

class AIService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  // ──────────────────────────────────────────────────────────────────────────
  // CONVERSATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Create a new conversation; returns the generated UUID.
  static Future<String?> createConversation({String? title}) async {
    try {
      final uid = _uid;
      if (uid == null) return null;
      final res = await _db
          .from('ai_conversations')
          .insert({'user_id': uid, 'title': title})
          .select('id')
          .single();
      return res['id'] as String?;
    } catch (e) {
      debugPrint('[AIService] createConversation error: $e');
      return null;
    }
  }

  /// Fetch all active conversations for the current user, newest first.
  static Future<List<Map<String, dynamic>>> listConversations() async {
    try {
      final uid = _uid;
      if (uid == null) return [];
      final res = await _db
          .from('ai_conversation_summary')
          .select()
          .eq('user_id', uid)
          .eq('is_active', true)
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('[AIService] listConversations error: $e');
      return [];
    }
  }

  /// Update the title of a conversation (auto-called after the first user message).
  static Future<void> updateConversationTitle(
      String conversationId, String title) async {
    try {
      await _db
          .from('ai_conversations')
          .update({'title': title})
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('[AIService] updateConversationTitle error: $e');
    }
  }

  /// Soft-delete a conversation (sets is_active = false).
  static Future<void> archiveConversation(String conversationId) async {
    try {
      await _db
          .from('ai_conversations')
          .update({'is_active': false})
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('[AIService] archiveConversation error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MESSAGES
  // ──────────────────────────────────────────────────────────────────────────

  /// Persist a single message to ai_messages.
  static Future<String?> saveMessage(ChatMessage msg) async {
    try {
      final uid = _uid;
      if (uid == null || msg.conversationId == null) return null;
      final payload = {
        'conversation_id': msg.conversationId,
        'user_id': uid,
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.message,
        'message_type': msg.messageType,
        if (msg.metadata != null) 'metadata': msg.metadata,
      };
      final res = await _db
          .from('ai_messages')
          .insert(payload)
          .select('id')
          .single();
      return res['id'] as String?;
    } catch (e) {
      debugPrint('[AIService] saveMessage error: $e');
      return null;
    }
  }

  /// Load all messages in a conversation, oldest first.
  static Future<List<ChatMessage>> loadMessages(
      String conversationId) async {
    try {
      final uid = _uid;
      if (uid == null) return [];
      final res = await _db
          .from('ai_messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('user_id', uid)
          .order('created_at', ascending: true);
      return (res as List)
          .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AIService] loadMessages error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AGENT TASKS
  // ──────────────────────────────────────────────────────────────────────────

  /// Enqueue a new autonomous agent task; returns the task UUID.
  static Future<String?> createAgentTask({
    required String taskType,
    required String taskDescription,
    Map<String, dynamic>? taskParams,
    String? conversationId,
    int priority = 1,
  }) async {
    try {
      final uid = _uid;
      if (uid == null) return null;
      final res = await _db
          .from('agent_tasks')
          .insert({
            'user_id': uid,
            'conversation_id': conversationId,
            'task_type': taskType,
            'task_description': taskDescription,
            'task_params': taskParams,
            'priority': priority,
          })
          .select('id')
          .single();
      return res['id'] as String?;
    } catch (e) {
      debugPrint('[AIService] createAgentTask error: $e');
      return null;
    }
  }

  /// Fetch all agent tasks for the current user, newest first.
  static Future<List<AgentTask>> loadAgentTasks({String? status}) async {
    try {
      final uid = _uid;
      if (uid == null) return [];
      var query = _db
          .from('agent_task_summary')
          .select()
          .eq('user_id', uid);
      if (status != null) {
        query = query.eq('status', status);
      }
      final res = await query.order('created_at', ascending: false);
      return (res as List)
          .map((r) => AgentTask.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AIService] loadAgentTasks error: $e');
      return [];
    }
  }

  /// Cancel a pending or in-progress task.
  static Future<void> cancelAgentTask(String taskId) async {
    try {
      await _db
          .from('agent_tasks')
          .update({'status': 'cancelled'})
          .eq('id', taskId)
          .inFilter('status', ['pending', 'in_progress']);
    } catch (e) {
      debugPrint('[AIService] cancelAgentTask error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FEEDBACK
  // ──────────────────────────────────────────────────────────────────────────

  /// Submit thumbs-up (rating=1) or thumbs-down (rating=-1) on a message.
  static Future<void> submitFeedback({
    required String messageId,
    required int rating,       // 1 or -1
    String? feedbackText,
  }) async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _db.from('ai_feedback').upsert({
        'user_id': uid,
        'message_id': messageId,
        'rating': rating,
        'feedback_text': feedbackText,
      }, onConflict: 'user_id,message_id');
    } catch (e) {
      debugPrint('[AIService] submitFeedback error: $e');
    }
  }
}
