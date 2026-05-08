import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageForm extends StatefulWidget {
  const MessageForm({super.key});

  @override
  State<MessageForm> createState() => _MessageFormState();
}

class _MessageFormState extends State<MessageForm> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedTopic;
  bool _isSending = false;

  static const _topics = [
    'Booking Assistance',
    'Cancellation & Refund',
    'Payment Issues',
    'Account Management',
    'Technical Support',
    'Feedback & Suggestions',
    'Other Inquiries',
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    final topic = _selectedTopic!;
    final subject = _subjectCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final session   = Supabase.instance.client.auth.currentSession;
    final senderEmail = session?.user.email ?? '';
    final userId      = session?.user.id ?? '';

    // Persist to DB + email admin — backend handles both in one call
    await ApiClient.sendContactSupport(
      topic:       topic,
      subject:     subject,
      description: description,
      senderEmail: senderEmail,
      userId:      userId,
    );

    setState(() => _isSending = false);
    if (!mounted) return;

    // Reset form
    _formKey.currentState?.reset();
    _subjectCtrl.clear();
    _descCtrl.clear();
    setState(() => _selectedTopic = null);

    // Success snackbar
    Get.snackbar(
      '✅ Message Sent',
      'Our team will respond within 24 hours. Check Updates → Messages.',
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
      borderRadius: 10,
      margin: const EdgeInsets.all(10),
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
    );

    // Navigate to Messages tab — pop back to root first so the stack is clean
    Get.until((route) => route.isFirst);
    Get.toNamed(AppLink.notification, arguments: {'tab': 1});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TravelloTheme.primaryMain.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: TravelloTheme.primaryMain.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent_rounded,
                      color: TravelloTheme.primaryMain, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'We\'re here to help! Send us a message about your travel booking or any questions. We respond within 24 hours.',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.75),
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Topic dropdown ────────────────────────────────────────
            const _FieldLabel('Topic *'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedTopic,
              decoration: _inputDecoration(
                  cs, Icons.category_outlined, 'Select a topic'),
              dropdownColor: cs.surface,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: TravelloTheme.primaryMain),
              items: _topics
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t,
                          style: TextStyle(fontSize: 14, color: cs.onSurface))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedTopic = v),
              validator: (v) => v == null ? 'Please select a topic' : null,
            ),
            const SizedBox(height: 12),

            // ── Subject ────────────────────────────────────────────────
            const _FieldLabel('Subject *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _subjectCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(
                  cs, Icons.subject_rounded, 'Brief subject of your message'),
              style: TextStyle(fontSize: 14, color: cs.onSurface),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Subject is required'
                  : null,
            ),
            const SizedBox(height: 12),

            // ── Description ────────────────────────────────────────────
            const _FieldLabel('Message *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(cs, Icons.message_outlined,
                  'Describe your issue or question in detail...'),
              style: TextStyle(fontSize: 14, color: cs.onSurface),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Please write at least 10 characters'
                  : null,
            ),
            const SizedBox(height: 20),

            // ── Submit button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _isSending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: TravelloTheme.primaryMain,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_isSending ? 'Sending...' : 'Send Message',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Your message will appear in Updates → Messages',
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(ColorScheme cs, IconData icon, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: cs.onSurface.withValues(alpha: 0.35), fontSize: 13),
      prefixIcon: Icon(icon,
          size: 20, color: TravelloTheme.primaryMain.withValues(alpha: 0.8)),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TravelloTheme.primaryMain, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)));
}
