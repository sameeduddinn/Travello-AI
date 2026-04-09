import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class EditPassword extends StatefulWidget {
  const EditPassword({super.key});

  @override
  State<EditPassword> createState() => _EditPasswordState();
}

class _EditPasswordState extends State<EditPassword> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _hideCurrentPwd = true;
  bool _hideNewPwd = true;
  bool _hideConfirmPwd = true;
  bool _isSaving = false;
  String? _currentPwdError;
  int _pwdStrength = 0; // 0-4

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _calcStrength(String val) {
    int score = 0;
    if (val.length >= 8) score++;
    if (val.contains(RegExp(r'[A-Z]'))) score++;
    if (val.contains(RegExp(r'[0-9]'))) score++;
    if (val.contains(RegExp(r'[!@#\$&*~]'))) score++;
    setState(() => _pwdStrength = score);
  }

  Future<void> _submit() async {
    setState(() => _currentPwdError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final result = await AuthService.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    setState(() => _isSaving = false);
    if (!mounted) return;

    if (result == 'success') {
      Get.snackbar(
        'Password Changed',
        'Your password has been updated successfully.',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
      Get.back();
    } else if (result == 'wrong_password') {
      setState(() => _currentPwdError = 'Current password is incorrect');
      _formKey.currentState!.validate();
    } else {
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: TravelloTheme.primaryMain,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text('Change Password',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Gold header ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TravelloTheme.primaryMain,
                      TravelloTheme.primaryMain.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.lock_outline,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Secure your account',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          SizedBox(height: 4),
                          Text(
                              'Use a strong password with uppercase, numbers & symbols.',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form card ─────────────────────────────────────────
              Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current password
                      const _PwdFieldLabel('Current Password'),
                      const SizedBox(height: 6),
                      _PwdField(
                        controller: _currentCtrl,
                        hint: 'Enter current password',
                        obscure: _hideCurrentPwd,
                        onToggle: () =>
                            setState(() => _hideCurrentPwd = !_hideCurrentPwd),
                        validator: (_) {
                          if (_currentCtrl.text.isEmpty) {
                            return 'Current password is required';
                          }
                          return _currentPwdError;
                        },
                      ),
                      const SizedBox(height: 16),

                      // New password + strength
                      const _PwdFieldLabel('New Password'),
                      const SizedBox(height: 6),
                      _PwdField(
                        controller: _newCtrl,
                        hint: 'Min 6 characters',
                        obscure: _hideNewPwd,
                        onToggle: () =>
                            setState(() => _hideNewPwd = !_hideNewPwd),
                        onChanged: _calcStrength,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'New password is required';
                          }
                          if (val.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _StrengthBar(strength: _pwdStrength),
                      const SizedBox(height: 16),

                      // Confirm password
                      const _PwdFieldLabel('Confirm New Password'),
                      const SizedBox(height: 6),
                      _PwdField(
                        controller: _confirmCtrl,
                        hint: 'Repeat new password',
                        obscure: _hideConfirmPwd,
                        onToggle: () =>
                            setState(() => _hideConfirmPwd = !_hideConfirmPwd),
                        validator: (val) {
                          if (val != _newCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Submit button ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: TravelloTheme.primaryMain,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          cs.onSurface.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock_reset_rounded),
                    label: Text(_isSaving ? 'Updating...' : 'Update Password',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PwdFieldLabel extends StatelessWidget {
  final String text;
  const _PwdFieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)));
}

class _PwdField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _PwdField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.35)),
        prefixIcon: Icon(Icons.lock_outline,
            size: 20, color: TravelloTheme.primaryMain.withValues(alpha: 0.8)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
              size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide:
              const BorderSide(color: TravelloTheme.primaryMain, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final int strength; // 0-4
  const _StrengthBar({required this.strength});

  Color _color() {
    if (strength <= 1) return Colors.red.shade400;
    if (strength == 2) return Colors.orange.shade400;
    if (strength == 3) return Colors.yellow.shade700;
    return Colors.green.shade500;
  }

  String _label() {
    if (strength == 0) return '';
    if (strength <= 1) return 'Weak';
    if (strength == 2) return 'Fair';
    if (strength == 3) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    if (strength == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strength / 4,
            minHeight: 5,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(_color()),
          ),
        ),
        const SizedBox(height: 4),
        Text(_label(),
            style: TextStyle(
                fontSize: 11, color: _color(), fontWeight: FontWeight.w600)),
      ],
    );
  }
}
