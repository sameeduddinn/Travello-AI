import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      _nameCtrl.text = user['name'] ?? '';
      _phoneCtrl.text = user['phone'] ?? '';
      _emailCtrl.text = user['email'] ?? '';
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final success = await AuthService.updateUserProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
    setState(() => _isSaving = false);
    if (!mounted) return;
    if (success) {
      Get.snackbar(
        'Profile Updated',
        'Your profile has been saved successfully.',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
      Get.back();
    } else {
      Get.snackbar(
        'Update Failed',
        'Could not save changes. Please try again.',
        backgroundColor: Colors.orange.shade600,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: const Text('Edit Profile',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── Gold header with avatar ──────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 24, bottom: 32),
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
                      child: Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6)),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: isDark
                                    ? const Color(0xFF1a1a2e)
                                    : Colors.white,
                                child: Text(
                                  _nameCtrl.text.isNotEmpty
                                      ? _nameCtrl.text[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: TravelloTheme.primaryMain),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1a1a2e)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: TravelloTheme.primaryMain,
                                    width: 1.5),
                              ),
                              child: const Icon(Icons.edit,
                                  size: 14, color: TravelloTheme.primaryMain),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Form card ────────────────────────────────────
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
                            Text('Personal Information',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                    letterSpacing: 0.8)),
                            const SizedBox(height: 16),

                            // Name
                            const _FieldLabel('Full Name'),
                            const SizedBox(height: 6),
                            _ProfileField(
                              controller: _nameCtrl,
                              hint: 'Enter your full name',
                              icon: Icons.person_outline,
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(
                                    errorText: 'Name is required'),
                                FormBuilderValidators.minLength(2,
                                    errorText: 'Name is too short'),
                              ]),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),

                            // Email
                            const _FieldLabel('Email Address'),
                            const SizedBox(height: 6),
                            _ProfileField(
                              controller: _emailCtrl,
                              hint: 'Enter your email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(
                                    errorText: 'Email is required'),
                                FormBuilderValidators.email(
                                    errorText: 'Enter a valid email'),
                              ]),
                            ),
                            const SizedBox(height: 16),

                            // Phone
                            const _FieldLabel('Phone Number'),
                            const SizedBox(height: 6),
                            _ProfileField(
                              controller: _phoneCtrl,
                              hint: 'e.g. +92 300 1234567',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: FormBuilderValidators.minLength(7,
                                  errorText: 'Enter a valid phone number'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Save button ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
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
                              : const Icon(Icons.check_rounded),
                          label: Text(_isSaving ? 'Saving...' : 'Save Changes',
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
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7)));
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;

  const _ProfileField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(
          fontSize: 15, color: cs.onSurface, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.35)),
        prefixIcon: Icon(icon,
            size: 20, color: TravelloTheme.primaryMain.withValues(alpha: 0.8)),
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
