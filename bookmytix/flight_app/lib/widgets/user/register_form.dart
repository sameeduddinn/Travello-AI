import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import 'package:flight_app/widgets/app_input/app_textfield.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

    const Widget fallbackAppleMark = FaIcon(
      FontAwesomeIcons.apple,
      size: 20,
      color: Colors.black,
    );

    final Widget appleMark = appleBrandIconUrl.isNotEmpty
        ? Image.network(
            appleBrandIconUrl,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallbackAppleMark,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallbackAppleMark,
          )
        : fallbackAppleMark;

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
                  height: MediaQuery.of(context).size.height < 640 ? 130 : 180,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Large sun/destination circle
                      Positioned(
                        top: 15,
                        left: 50,
                        child: Container(
                          width: 110,
                          height: 110,
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
                        top: 40,
                        left: 70,
                        child: Container(
                          padding: const EdgeInsets.all(12),
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
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      // Main ticket/boarding pass illustration
                      Positioned(
                        bottom: 25,
                        child: Container(
                          width: 110,
                          height: 130,
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
                              const Icon(
                                Icons.airplane_ticket,
                                color: Colors.white,
                                size: 45,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
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
                        top: 25,
                        right: 65,
                        child: Container(
                          padding: const EdgeInsets.all(10),
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
                          child: const Icon(
                            Icons.map,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      // Palm tree / vacation
                      Positioned(
                        bottom: 40,
                        right: 75,
                        child: Container(
                          padding: const EdgeInsets.all(8),
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
                          child: const Icon(
                            Icons.park,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      // Backpack illustration
                      Positioned(
                        bottom: 35,
                        left: 60,
                        child: Container(
                          padding: const EdgeInsets.all(9),
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
                          child: const Icon(
                            Icons.backpack,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      // Star/favorite destination
                      Positioned(
                        top: 60,
                        right: 45,
                        child: Icon(
                          Icons.star,
                          size: 24,
                          color: Colors.amber.shade400,
                        ),
                      ),
                      // Sparkle effects
                      Positioned(
                        top: 45,
                        left: 45,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: Colors.orange.shade300,
                        ),
                      ),
                      Positioned(
                        bottom: 70,
                        right: 55,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.pink.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Brand name
                Text(
                  branding.name,
                  style: TravelloTheme.headline.copyWith(
                    color: TravelloTheme.primaryMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Main heading
                Text(
                  'Sign Up',
                  style: TravelloTheme.title.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  'Join us and start your journey today',
                  style: TravelloTheme.headline.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          /// INPUT FIELD
          FormBuilderField(
            name: 'name',
            builder: (FormFieldState<dynamic> field) {
              return AppTextField(
                label: 'Full Name',
                onChanged: (value) => field.didChange(value),
                errorText:
                    field.hasError ? 'Please enter your full name' : null,
                prefixIcon: Icons.person_outline,
              );
            },
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(3,
                  errorText: 'Name must be at least 3 characters'),
            ]),
          ),
          const VSpace(),

          /// EMAIL FIELD
          FormBuilderField(
            name: 'email',
            builder: (FormFieldState<dynamic> field) {
              return AppTextField(
                label: 'Email Address',
                onChanged: (value) => field.didChange(value),
                errorText: field.hasError
                    ? 'Please enter a valid email address'
                    : null,
                prefixIcon: Icons.email_outlined,
                suffix:
                    field.value != null && field.value.toString().contains('@')
                        ? TextButton(
                            onPressed: () {
                              // Navigate to email verification with email parameter
                              Get.toNamed(
                                '${AppLink.emailVerification}?email=${field.value}',
                              );
                            },
                            child: Text(
                              'Verify',
                              style: TravelloTheme.caption.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
              );
            },
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.email(),
            ]),
          ),
          const VSpace(),

          /// PHONE NUMBER FIELD
          FormBuilderField(
            name: 'phone',
            builder: (FormFieldState<dynamic> field) {
              return AppTextField(
                label: 'Phone Number',
                onChanged: (value) => field.didChange(value),
                errorText:
                    field.hasError ? 'Please enter a valid phone number' : null,
                prefixIcon: Icons.phone_outlined,
              );
            },
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.numeric(),
              FormBuilderValidators.minLength(10,
                  errorText: 'Phone number must be at least 10 digits'),
            ]),
          ),
          const VSpace(),

          FormBuilderField(
            name: 'password',
            builder: (FormFieldState<dynamic> field) {
              return AppTextField(
                label: 'Password (min. 8 characters)',
                obscureText: _hidePassword,
                onChanged: (value) {
                  field.didChange(value);
                  _checkPasswordStrength(value);
                },
                errorText: field.hasError
                    ? 'Password must be at least 8 characters'
                    : null,
                prefixIcon: Icons.lock_outline,
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
              );
            },
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(8,
                  errorText: 'Password must be at least 8 characters'),
            ]),
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
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Use 8+ characters with mix of letters, numbers & symbols',
                  style: TextStyle(
                    fontSize: 11,
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
            builder: (FormFieldState<dynamic> field) {
              return AppTextField(
                label: 'Confirm Password',
                obscureText: _hideConfirmPassword,
                onChanged: (value) => field.didChange(value),
                errorText: field.hasError ? 'Passwords do not match' : null,
                prefixIcon: Icons.lock_outline,
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
              );
            },
            validator: (value) =>
                _registerKey.currentState?.fields['password']?.value != value
                    ? 'Passwords do not match'
                    : null,
          ),
          const VSpaceShort(),
          FormBuilderCheckbox(
            name: 'accept_terms',
            initialValue: false,
            title: const Text('Agree with our terms and condtions'),
            validator: FormBuilderValidators.equal(
              true,
              errorText: 'You must accept terms and conditions to continue',
            ),
          ),
          const VSpace(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_registerKey.currentState?.saveAndValidate() ??
                            false) {
                          setState(() {
                            _isLoading = true;
                          });

                          final formData = _registerKey.currentState?.value;

                          // Register the user with separate email and phone
                          final success = await AuthService.registerUser(
                            name: formData!['name'],
                            emailOrPhone:
                                formData['email'], // Primary identifier
                            email: formData['email'],
                            phone: formData['phone'],
                            password: formData['password'],
                          );

                          setState(() {
                            _isLoading = false;
                          });

                          if (success) {
                            // Show success message
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
                            // Navigate to email verification with email parameter
                            Get.offNamed(
                              '${AppLink.emailVerification}?email=${formData['email']}',
                            );
                          } else {
                            // Show error message
                            Get.snackbar(
                              'Registration Failed',
                              'This email or phone number is already registered. Please login instead.',
                              backgroundColor: Colors.orange.shade600,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.TOP,
                              icon: const Icon(Icons.warning_amber,
                                  color: Colors.white),
                              borderRadius: 10,
                              margin: const EdgeInsets.all(10),
                              duration: const Duration(seconds: 3),
                            );
                          }
                        }
                      },
                style: ThemeButton.btnBig.merge(FilledButton.styleFrom(
                  backgroundColor: TravelloTheme.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: Colors.black26,
                )),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text('SIGN UP',
                        style: TravelloTheme.subtitle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ))),
          ),
          const VSpace(),

          /// DIVIDER WITH "OR" - PROFESSIONAL STYLE
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                        fontSize: 11,
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
            height: 56,
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
                onTap: () {
                  // TODO: Implement Google Sign Up
                  Get.snackbar(
                    'Coming Soon',
                    'Google Sign Up will be available soon!',
                    backgroundColor: Colors.blue.shade600,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                    duration: const Duration(seconds: 2),
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    borderRadius: 10,
                    margin: const EdgeInsets.all(10),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
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
                      const SizedBox(width: 12),
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
          const SizedBox(height: 12),

          /// APPLE SIGNUP - PREMIUM STYLE
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF5F5F7),
                  const Color(0xFFE8E8ED).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // TODO: Implement Apple Sign Up
                  Get.snackbar(
                    'Coming Soon',
                    'Apple Sign Up will be available soon!',
                    backgroundColor: Colors.grey.shade100,
                    colorText: Colors.black87,
                    snackPosition: SnackPosition.TOP,
                    duration: const Duration(seconds: 2),
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    borderRadius: 10,
                    margin: const EdgeInsets.all(10),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.grey.shade300, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(child: appleMark),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sign up with Apple',
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
                  style: TravelloTheme.caption,
                  children: [
                    TextSpan(
                      text: 'Login Here',
                      style: TravelloTheme.caption.copyWith(
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
