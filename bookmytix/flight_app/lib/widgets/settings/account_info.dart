import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/utils/grabber_icon.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class AccountInfo extends StatefulWidget {
  const AccountInfo({super.key});

  @override
  State<AccountInfo> createState() => _AccountInfoState();
}

class _AccountInfoState extends State<AccountInfo> {
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  bool _isGuest = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final isGuest = await AuthService.isGuestMode();
    if (isGuest) {
      final guest = AuthService.getGuestUser();
      setState(() {
        _userName = guest['name'];
        _userEmail = 'guest@example.com';
        _userPhone = '';
        _isGuest = true;
        _isLoading = false;
      });
    } else {
      final user = await AuthService.getCurrentUser();
      setState(() {
        _userName = user?['name'] ?? 'User';
        _userEmail = user?['email'] ?? '';
        _userPhone = user?['phone'] ?? '';
        _isGuest = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GrabberIcon(),
        // ── Gold header banner with avatar ──────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16,
              20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TravelloTheme.primaryMain,
                TravelloTheme.primaryMain.withValues(alpha: 0.78),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      isDark ? const Color(0xFF1a1a2e) : Colors.white,
                  child: Text(
                    _isLoading || _userName.isEmpty
                        ? '?'
                        : _userName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: TravelloTheme.primaryMain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isLoading
                    ? const SizedBox(
                        height: 16, width: 80, child: LinearProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (_isGuest)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Guest Account',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            )
                          else
                            Text(
                              _userEmail,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),

        // ── Info rows ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Full Name',
                value: _isLoading ? '—' : (_userName.isEmpty ? '—' : _userName),
              ),
              _DividerLine(),
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _isLoading
                    ? '—'
                    : (_userEmail.isEmpty ? 'Not set' : _userEmail),
              ),
              _DividerLine(),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _isLoading
                    ? '—'
                    : (_userPhone.isEmpty ? 'Not available' : _userPhone),
              ),
            ],
          ),
        ),

        // ── Action buttons ─────────────────────────────────────────
        if (!_isGuest) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                20, 0, 20, 12),
            child: Column(
              children: [
                _ActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  subtitle: 'Update your name, email and phone',
                  onTap: () async {
                    Get.back();
                    await Get.toNamed(AppLink.editProfile);
                    _loadCurrentUser();
                  },
                  color: TravelloTheme.primaryMain,
                ),
                const SizedBox(height: 8),
                _ActionButton(
                  icon: Icons.lock_outline,
                  label: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppLink.editPassword);
                  },
                  color: cs.error,
                  outlined: true,
                ),
              ],
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () {
                  Get.back();
                  Get.toNamed(AppLink.login);
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign In to Your Account',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: TravelloTheme.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: TravelloTheme.primaryMain.withValues(alpha: 0.85)),
          const SizedBox(width: 12),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = outlined
        ? Theme.of(context).colorScheme.surface
        : color.withValues(alpha: 0.07);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: outlined
                  ? color.withValues(alpha: 0.45)
                  : color.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: color)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: color.withValues(alpha: 0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
