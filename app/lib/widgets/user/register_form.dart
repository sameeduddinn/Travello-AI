import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import 'package:flight_app/widgets/app_input/app_textfield.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/widgets/onboarding/city_selection_sheet.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class _PakPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final partialPattern = RegExp(r'^(?:0|03\d{0,9}|3\d{0,9})$');

    if (!partialPattern.hasMatch(text)) {
      return oldValue;
    }

    final maxLength = text.startsWith('3') ? 10 : 11;
    if (text.length > maxLength) {
      final limited = text.substring(0, maxLength);
      return TextEditingValue(
        text: limited,
        selection: TextSelection.collapsed(offset: limited.length),
      );
    }

    return newValue;
  }
}

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _registerKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  String _passwordStrength = '';
  Color _strengthColor = Colors.grey;
  double _strengthValue = 0.0;

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _strengthColor = Colors.grey;
        _strengthValue = 0.0;
      });
      return;
    }

    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    setState(() {
      if (strength <= 2) {
        _passwordStrength = 'Weak';
        _strengthColor = Colors.red;
        _strengthValue = 0.33;
      } else if (strength <= 4) {
        _passwordStrength = 'Medium';
        _strengthColor = Colors.orange;
        _strengthValue = 0.66;
      } else {
        _passwordStrength = 'Strong';
        _strengthColor = Colors.green;
        _strengthValue = 1.0;
      }
    });
  }

  Future<void> _handleGoogleSignUp() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final started = await AuthService.signInWithGoogle();
    if (!mounted) return;

    if (!started) {
      setState(() {
        _isLoading = false;
      });
      final errorMessage = AuthService.lastAuthError ??
          'Unable to start Google sign-up. Please try again.';
      Get.snackbar(
        'Google Sign-Up Failed',
        errorMessage,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.error_outline, color: Colors.white),
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
      return;
    }

    final user = await AuthService.waitForAuthenticatedUser();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (user == null) {
      final errorMessage = AuthService.lastAuthError ??
          'Complete sign-up in browser and return to the app.';
      Get.snackbar(
        'Continue Google Sign-Up',
        errorMessage,
        backgroundColor: Colors.blue.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.open_in_new, color: Colors.white),
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
      return;
    }

    Get.snackbar(
      'Welcome',
      'Google account connected successfully.',
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.check_circle, color: Colors.white),
      borderRadius: 10,
      margin: const EdgeInsets.all(10),
    );

    final hasCity = await LocationPreferenceService.hasOriginCity();
    if (!mounted) return;

    if (!hasCity) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => CitySelectionSheet(
          onComplete: () {
            Get.offAllNamed(AppLink.home);
          },
        ),
      );
    } else {
      Get.offAllNamed(AppLink.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final Widget fallbackGoogleMark = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF4285F4), // Blue
          Color(0xFF34A853), // Green
          Color(0xFFFBBC05), // Yellow
          Color(0xFFEA4335), // Red
        ],
      ).createShader(bounds),
      child: const FaIcon(
        FontAwesomeIcons.google,
        size: 18,
      ),
    );

    final Widget googleMark = googleBrandIconUrl.isNotEmpty
        ? Image.network(
            googleBrandIconUrl,
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallbackGoogleMark,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallbackGoogleMark,
          )
        : fallbackGoogleMark;

    return FormBuilder(
      key: _registerKey,
      child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          /// STUNNING ILLUSTRATION - SIGNUP
          Container(
            alignment: Alignment.center,
            child: Column(
              children: [
                // Beautiful illustration container
                SizedBox(
                  height: R.rh(context,
                      MediaQuery.of(context).size.height < 640 ? 130 : 180),
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Large sun/destination circle
                      Positioned(
                        top: R.r(context, 15),
                        left: R.r(context, 50),
                        child: Container(
                          width: R.r(context, 110),
                          height: R.r(context, 110),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.amber.shade300,
                                Colors.orange.withValues(alpha: 0.2),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Camera for memories
                      Positioned(
                        top: R.r(context, 40),
                        left: R.r(context, 70),
                        child: Container(
                          padding: EdgeInsets.all(R.r(context, 12)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade400,
                                Colors.pink.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: R.r(context, 26),
                          ),
                        ),
                      ),
                      // Main ticket/boarding pass illustration
                      Positioned(
                        bottom: R.r(context, 25),
                        child: Container(
                          width: R.r(context, 110),
                          height: R.r(context, 130),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.deepOrange.shade400,
                                Colors.orange.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.5),
                                blurRadius: 25,
                                offset: const Offset(0, 12),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.airplane_ticket,
                                color: Colors.white,
                                size: R.r(context, 45),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: R.r(context, 8),
                                    height: R.r(context, 8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: R.r(context, 8),
                                    height: R.r(context, 8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: R.r(context, 8),
                                    height: R.r(context, 8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Map/navigation illustration
                      Positioned(
                        top: R.r(context, 25),
                        right: R.r(context, 65),
                        child: Container(
                          padding: EdgeInsets.all(R.r(context, 10)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade300,
                                Colors.deepPurple.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.map,
                            color: Colors.white,
                            size: R.r(context, 24),
                          ),
                        ),
                      ),
                      // Palm tree / vacation
                      Positioned(
                        bottom: R.r(context, 40),
                        right: R.r(context, 75),
                        child: Container(
                          padding: EdgeInsets.all(R.r(context, 8)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.teal.shade500,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.park,
                            color: Colors.white,
                            size: R.r(context, 18),
                          ),
                        ),
                      ),
                      // Backpack illustration
                      Positioned(
                        bottom: R.r(context, 35),
                        left: R.r(context, 60),
                        child: Container(
                          padding: EdgeInsets.all(R.r(context, 9)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.indigo.shade300,
                                Colors.purple.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.backpack,
                            color: Colors.white,
                            size: R.r(context, 22),
                          ),
                        ),
                      ),
                      // Star/favorite destination
                      Positioned(
                        top: R.r(context, 60),
                        right: R.r(context, 45),
                        child: Icon(
                          Icons.star,
                          size: R.r(context, 24),
                          color: Colors.amber.shade400,
                        ),
                      ),
                      // Sparkle effects
                      Positioned(
                        top: R.r(context, 45),
                        left: R.r(context, 45),
                        child: Icon(
                          Icons.auto_awesome,
                          size: R.r(context, 14),
                          color: Colors.orange.shade300,
                        ),
                      ),
                      Positioned(
                        bottom: R.r(context, 70),
                        right: R.r(context, 55),
                        child: Icon(
                          Icons.auto_awesome,
                          size: R.r(context, 12),
                          color: Colors.pink.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: R.rh(context, 16)),
                // Brand name
                Text(
                  branding.name,
                  style: TravelloTheme.headline.copyWith(
                    color: TravelloTheme.primaryMain,
                    fontWeight: FontWeight.w600,
                    fontSize: R.sp(context, 14),
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: R.rh(context, 8)),
                // Main heading
                Text(
                  'Sign Up',
                  style: TravelloTheme.title.copyWith(
                    fontSize: R.sp(context, 34),
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: R.rh(context, 8)),
                // Subtitle
                Text(
                  'Join us and start your journey today',
                  style: TravelloTheme.headline.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: R.sp(context, 15),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: R.rh(context, 24)),

          /// INPUT FIELD
          FormBuilderField(
            name: 'name',
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'Name is required'),
              FormBuilderValidators.match(
                RegExp(r'^[a-zA-Z ]+$'),
                errorText: 'Name should contain only letters',
              ),
              FormBuilderValidators.minLength(3,
                  errorText: 'Name must be at least 3 characters'),
              FormBuilderValidators.maxLength(50),
            ]),
            builder: (field) => AppTextField(
              label: 'Full Name',
              onChanged: field.didChange,
              prefixIcon: Icons.person_outline,
              errorText: field.errorText, // ✅ FIXED
            ),
          ),
          const VSpace(),

          /// EMAIL FIELD
          FormBuilderField(
            name: 'email',
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'Email is required'),
              FormBuilderValidators.email(errorText: 'Enter a valid email'),
            ]),
            builder: (field) => AppTextField(
              label: 'Email Address',
              prefixIcon: Icons.email_outlined,
              onChanged: (value) => field.didChange(value),
              errorText: field.errorText,
            ),
          ),
          const VSpace(),

          /// PHONE NUMBER FIELD
          FormBuilderField(
            name: 'phone',
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(
                  errorText: 'Phone number is required'),
              FormBuilderValidators.match(
                RegExp(r'^(?:03[0-9]{9}|3[0-9]{9})$'),
                errorText:
                    'Enter a valid phone number',
              ),
            ]),
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Phone Number',
                  onChanged: field.didChange,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _PakPhoneInputFormatter(),
                  ],
                  errorText: field.errorText, // ✅ FIXED
                ),
                if (field.errorText == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Accepted: 03XXXXXXXXX or 3XXXXXXXXX',
                    style: TravelloTheme.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: R.sp(context, 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const VSpace(),

          FormBuilderField(
            name: 'password',
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'Password is required'),
              FormBuilderValidators.minLength(8,
                  errorText: 'Password must be at least 8 characters'),
              FormBuilderValidators.match(
                RegExp(
                  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#^()\-_=+\[\]{};:,.<>|~`]).{8,}$',
                ),
                errorText: 'Use 8+ chars with upper, lower, number & symbol',
              ),
            ]),
            builder: (field) => AppTextField(
              label: 'Password (min. 8 characters)',
              obscureText: _hidePassword,
              onChanged: (value) {
                field.didChange(value);
                _checkPasswordStrength(value);
              },
              prefixIcon: Icons.lock_outline,
              errorText: field.errorText, // ✅ FIXED
              suffix: IconButton(
                onPressed: () {
                  setState(() {
                    _hidePassword = !_hidePassword;
                  });
                },
                icon: _hidePassword
                    ? const Icon(Icons.visibility_outlined, size: 20)
                    : const Icon(Icons.visibility_off_outlined, size: 20),
              ),
            ),
          ),

          /// PASSWORD STRENGTH INDICATOR
          if (_passwordStrength.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _strengthValue,
                        backgroundColor: Colors.grey.shade300,
                        color: _strengthColor,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _passwordStrength,
                      style: TextStyle(
                        color: _strengthColor,
                        fontWeight: FontWeight.bold,
                        fontSize: R.sp(context, 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Use 8+ characters with mix of letters, numbers & symbols',
                  style: TextStyle(
                    fontSize: R.sp(context, 11),
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
          const VSpace(),

          FormBuilderField(
            name: 'repeat_password',
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              final confirmPassword = (value ?? '').toString().trim();
              final password =
                  _registerKey.currentState?.fields['password']?.value ?? '';

              if (confirmPassword.isEmpty) {
                return 'Confirm your password';
              }

              if (confirmPassword != password) {
                return 'Passwords do not match';
              }

              return null;
            },
            builder: (field) => AppTextField(
              label: 'Confirm Password',
              obscureText: _hideConfirmPassword,
              onChanged: field.didChange,
              prefixIcon: Icons.lock_outline,
              errorText: field.errorText, // ✅ FIXED
              suffix: IconButton(
                onPressed: () {
                  setState(() {
                    _hideConfirmPassword = !_hideConfirmPassword;
                  });
                },
                icon: _hideConfirmPassword
                    ? const Icon(Icons.visibility_outlined, size: 20)
                    : const Icon(Icons.visibility_off_outlined, size: 20),
              ),
            ),
          ),
          const VSpaceShort(),
          FormBuilderCheckbox(
            name: 'accept_terms',
            initialValue: false,
            title: const Text('Agree with our terms and conditions'),
            validator: FormBuilderValidators.equal(
              true,
              errorText: 'You must accept terms and conditions to continue',
            ),
          ),
          const VSpace(),
          SizedBox(
            width: double.infinity,
            height: R.rh(context, 54),
            child: FilledButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final formState = _registerKey.currentState;
                        if (formState == null) return;

                        if (!formState.saveAndValidate()) {
                          // Validation failed — fields already show inline
                          // errors, but also show a top-level hint so the
                          // user knows why the button didn't proceed.
                          Get.snackbar(
                            'Check Your Details',
                            'Please fix the highlighted errors before continuing.',
                            backgroundColor: Colors.orange.shade700,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.TOP,
                            duration: const Duration(seconds: 3),
                            icon: const Icon(Icons.warning_amber,
                                color: Colors.white),
                            borderRadius: 10,
                            margin: const EdgeInsets.all(10),
                          );
                          return;
                        }

                        setState(() => _isLoading = true);

                        final formData = formState.value;

                        /// 🔹 SANITIZE INPUTS
                        final String name = (formData['name'] ?? '')
                            .toString()
                            .trim()
                            .replaceAll(RegExp(r'\s+'), ' ');

                        final String email = (formData['email'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                        final String phone = (formData['phone'] ?? '')
                            .toString()
                            .trim()
                            .replaceAll(RegExp(r'\s+|-'), '');
                        final String normalizedPhone =
                            phone.startsWith('3') ? '0$phone' : phone;

                        final String password =
                            (formData['password'] ?? '').toString().trim();

                        try {
                          final success = await AuthService.registerUser(
                            name: name,
                            emailOrPhone: email,
                            email: email,
                            phone: normalizedPhone,
                            password: password,
                          );

                          if (!mounted) return;
                          setState(() => _isLoading = false);

                          if (success) {
                            Get.snackbar(
                              'Registration Successful',
                              'Please verify your email to continue.',
                              backgroundColor: Colors.green.shade600,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.TOP,
                              duration: const Duration(seconds: 2),
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.white),
                              borderRadius: 10,
                              margin: const EdgeInsets.all(10),
                            );

                            Get.offNamed(
                              '${AppLink.emailVerification}?email=$email',
                            );
                          } else {
                            final errorMessage = AuthService.lastAuthError ??
                                'Registration failed. Please try again.';
                            Get.snackbar(
                              'Registration Failed',
                              errorMessage,
                              backgroundColor: Colors.red.shade600,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.TOP,
                              icon: const Icon(Icons.error_outline,
                                  color: Colors.white),
                              borderRadius: 10,
                              margin: const EdgeInsets.all(10),
                              duration: const Duration(seconds: 4),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => _isLoading = false);

                          Get.snackbar(
                            'Error',
                            'Something went wrong. Please try again.',
                            backgroundColor: Colors.red.shade600,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.TOP,
                            icon: const Icon(Icons.error_outline,
                                color: Colors.white),
                            borderRadius: 10,
                            margin: const EdgeInsets.all(10),
                            duration: const Duration(seconds: 3),
                          );
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: TravelloTheme.primaryMain,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, R.rh(context, 54)),
                  padding: EdgeInsets.symmetric(horizontal: R.r(context, 16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: Colors.black26,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('SIGN UP',
                            maxLines: 1,
                            style: TravelloTheme.subtitle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              fontSize: R.sp(context, 15),
                            )))),
          ),
          const VSpace(),

          /// DIVIDER WITH "OR" - PROFESSIONAL STYLE
          Padding(
            padding: EdgeInsets.symmetric(vertical: R.rh(context, 16)),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.surface,
                          colorScheme.outline.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.r(context, 24)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: R.r(context, 16),
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'OR SIGN UP WITH',
                      style: TravelloTheme.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontSize: R.sp(context, 11),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.outline.withValues(alpha: 0.3),
                          colorScheme.surface,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// GOOGLE SIGNUP - PREMIUM STYLE
          Container(
            width: double.infinity,
            height: R.rh(context, 56),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF8F9FA),
                  const Color(0xFFE8F0FE).withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFF4285F4).withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleGoogleSignUp,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.r(context, 16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: R.r(context, 32),
                        height: R.r(context, 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: googleMark,
                        ),
                      ),
                      SizedBox(width: R.r(context, 12)),
                      Text(
                        'Sign up with Google',
                        style: TravelloTheme.subtitle.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: R.rh(context, 12)),
          const VSpaceBig(),

          /// LOGIN LINK
          Center(
            child: TextButton(
              onPressed: () {
                Get.offNamed(AppLink.login);
              },
              child: Text.rich(
                TextSpan(
                  text: 'Already have an account? ',
                  style: TravelloTheme.caption
                      .copyWith(fontSize: R.sp(context, 15)),
                  children: [
                    TextSpan(
                      text: 'Login Here',
                      style: TravelloTheme.caption.copyWith(
                        fontSize: R.sp(context, 15),
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
