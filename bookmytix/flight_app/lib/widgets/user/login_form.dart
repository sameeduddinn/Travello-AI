import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/app_input/app_textfield.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/utils/location_preference_service.dart';
import 'package:flight_app/widgets/user/saved_credentials_dialog.dart';
import 'package:flight_app/widgets/onboarding/city_selection_sheet.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _loginKey = GlobalKey<FormBuilderState>();
  bool _hidePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final credentials = await AuthService.getRememberedCredentials();
    if (credentials != null && mounted) {
      setState(() {
        _rememberMe = true;
      });

      // Show professional saved credentials dialog
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => SavedCredentialsDialog(
              emailOrPhone: credentials['emailOrPhone']!,
              onUseCredentials: () {
                Navigator.pop(context);
                // Auto-fill credentials
                _loginKey.currentState?.patchValue({
                  'name': credentials['emailOrPhone'],
                  'password': credentials['password'],
                });

                Get.snackbar(
                  'Credentials Loaded',
                  'Click Continue to login',
                  backgroundColor: Colors.green.shade600,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 2),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  borderRadius: 10,
                  margin: const EdgeInsets.all(10),
                );
              },
              onDifferentAccount: () async {
                Navigator.pop(context);
                // Clear saved credentials
                await AuthService.clearRememberMe();
                setState(() {
                  _rememberMe = false;
                });

                Get.snackbar(
                  'Login Manually',
                  'Enter your credentials to login',
                  backgroundColor: Colors.blue.shade600,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 2),
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  borderRadius: 10,
                  margin: const EdgeInsets.all(10),
                );
              },
            ),
          );
        }
      });
    }
  }

  void handleShowPassword() {
    setState(() {
      _hidePassword = !_hidePassword;
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
      key: _loginKey,
      child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          /// STUNNING ILLUSTRATION - LOGIN
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
                      // Large decorative circle - back
                      Positioned(
                        top: 20,
                        right: 60,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.withValues(alpha: 0.15),
                                Colors.deepOrange.withValues(alpha: 0.08),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Airplane flying illustration
                      Positioned(
                        top: 30,
                        right: 80,
                        child: Transform.rotate(
                          angle: -0.3,
                          child: Icon(
                            Icons.flight,
                            size: 50,
                            color: Colors.orange.shade400,
                          ),
                        ),
                      ),
                      // Travel destination marker
                      Positioned(
                        top: 35,
                        left: 70,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.pink.shade300,
                                Colors.purple.shade300,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      // Main passport/ticket illustration
                      Positioned(
                        bottom: 20,
                        child: Container(
                          width: 100,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 60,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Luggage illustration
                      Positioned(
                        bottom: 35,
                        right: 90,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade400,
                                Colors.orange.shade500,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.luggage,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      // Globe/world illustration
                      Positioned(
                        bottom: 30,
                        left: 75,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.teal.shade300,
                                Colors.green.shade400,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.public,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // Sparkle effects
                      Positioned(
                        top: 50,
                        left: 50,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Colors.amber.shade300,
                        ),
                      ),
                      Positioned(
                        top: 80,
                        right: 50,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.pink.shade200,
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
                  'Welcome Back!',
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
                  'Login to continue your journey',
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

          /// DEMO CREDENTIALS HINT
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.5),
                  colorScheme.primaryContainer.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Try Demo Account',
                        style: TravelloTheme.subtitle.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Username: John Doe | Password: 0123456789',
                        style: TravelloTheme.caption.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
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
                label: 'Email or Phone Number',
                onChanged: (value) => field.didChange(value),
                errorText: field.hasError
                    ? 'Please enter your email or phone number'
                    : null,
                prefixIcon: Icons.email_outlined,
              );
            },
            validator: FormBuilderValidators.required(),
          ),
          const VSpace(),
          FormBuilderField(
            name: 'password',
            builder: (FormFieldState<dynamic> field) {
              return AppTextField(
                label: 'Password',
                obscureText: _hidePassword,
                onChanged: (value) => field.didChange(value),
                errorText: field.hasError ? 'Please fill your password!' : null,
                prefixIcon: Icons.lock_outline,
                suffix: IconButton(
                    onPressed: () {
                      handleShowPassword();
                    },
                    icon: _hidePassword == true
                        ? const Icon(Icons.visibility_outlined, size: 20)
                        : const Icon(Icons.visibility_off_outlined, size: 20)),
              );
            },
            validator: FormBuilderValidators.required(),
          ),
          const VSpace(),

          /// REMEMBER ME CHECKBOX
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });

                  // Show cookie/save confirmation message
                  if (_rememberMe) {
                    Get.snackbar(
                      'Credentials Saved',
                      'Your login information will be securely saved for faster access next time',
                      backgroundColor: Colors.green.shade600,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 3),
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.white),
                      borderRadius: 10,
                      margin: const EdgeInsets.all(10),
                    );
                  } else {
                    Get.snackbar(
                      'Credentials Cleared',
                      'Your saved login information has been removed',
                      backgroundColor: Colors.orange.shade600,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      borderRadius: 10,
                      margin: const EdgeInsets.all(10),
                    );
                  }
                },
              ),
              const Text('Remember Me', style: TravelloTheme.caption),
              const Spacer(),
              InkWell(
                onTap: () {
                  Get.toNamed(AppLink.resetPassword);
                },
                child: Text(
                  'Forgot Password?',
                  style: TravelloTheme.caption.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const VSpace(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_loginKey.currentState?.saveAndValidate() ??
                            false) {
                          setState(() {
                            _isLoading = true;
                          });

                          final formData = _loginKey.currentState?.value;

                          // Login the user
                          final user = await AuthService.loginUser(
                            emailOrPhone: formData!['name'],
                            password: formData['password'],
                          );

                          if (!context.mounted) return;

                          setState(() {
                            _isLoading = false;
                          });

                          if (user != null) {
                            // Save Remember Me if checked
                            if (_rememberMe) {
                              await AuthService.saveRememberMe(
                                formData['name'],
                                formData['password'],
                              );
                            } else {
                              await AuthService.clearRememberMe();
                            }

                            if (!context.mounted) return;

                            // Show success message with animation
                            Get.snackbar(
                              'Login Successful',
                              'Welcome back, ${user['name']}!',
                              backgroundColor: Colors.green.shade600,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.TOP,
                              duration: const Duration(seconds: 2),
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.white),
                              borderRadius: 10,
                              margin: const EdgeInsets.all(10),
                            );

                            // Check if user has set their origin city
                            final hasCity =
                                await LocationPreferenceService.hasOriginCity();

                            if (!context.mounted) return;

                            if (!hasCity) {
                              // Show city selection bottom sheet for personalization
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
                              // Already has city preference, go directly to home
                              Get.offAllNamed(AppLink.home);
                            }
                          } else {
                            // Show error message with better styling
                            Get.snackbar(
                              'Login Failed',
                              'Invalid credentials. Please check your email/phone and password.',
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
                    : Text('CONTINUE',
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
                      'OR CONTINUE WITH',
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

          /// GOOGLE LOGIN - PREMIUM STYLE
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
                  // TODO: Implement Google Sign In
                  Get.snackbar(
                    'Coming Soon',
                    'Google Sign In will be available soon!',
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
                        'Continue with Google',
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

          /// APPLE LOGIN - PREMIUM STYLE
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
                  // TODO: Implement Apple Sign In
                  Get.snackbar(
                    'Coming Soon',
                    'Apple Sign In will be available soon!',
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
                        'Continue with Apple',
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

          /// SIGN UP LINK
          Center(
            child: TextButton(
              onPressed: () {
                Get.toNamed(AppLink.register);
              },
              child: Text.rich(
                TextSpan(
                  text: 'Don\'t have an account? ',
                  style: TravelloTheme.caption.copyWith(fontSize: 15),
                  children: [
                    TextSpan(
                      text: 'Sign Up Now',
                      style: TravelloTheme.caption.copyWith(
                        fontSize: 15,
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
