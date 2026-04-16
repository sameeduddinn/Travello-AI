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
import 'package:flight_app/utils/responsive_helper.dart';

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
                  'emailOrPhone': credentials['emailOrPhone'],
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

  Future<void> _handleGoogleSignIn() async {
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
          'Unable to start Google sign-in. Please try again.';
      Get.snackbar(
        'Google Sign-In Failed',
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
          'Complete sign-in in browser and return to the app.';
      Get.snackbar(
        'Continue Google Sign-In',
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
      'Login Successful',
      'Welcome, ${user['name']}!',
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
                  height: R.rh(context,
                      MediaQuery.of(context).size.height < 640 ? 130 : 180),
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Large decorative circle - back
                      Positioned(
                        top: R.r(context, 20),
                        right: R.r(context, 60),
                        child: Container(
                          width: R.r(context, 120),
                          height: R.r(context, 120),
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
                        top: R.r(context, 30),
                        right: R.r(context, 80),
                        child: Transform.rotate(
                          angle: -0.3,
                          child: Icon(
                            Icons.flight,
                            size: R.r(context, 50),
                            color: Colors.orange.shade400,
                          ),
                        ),
                      ),
                      // Travel destination marker
                      Positioned(
                        top: R.r(context, 35),
                        left: R.r(context, 70),
                        child: Container(
                          padding: EdgeInsets.all(R.r(context, 12)),
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
                          child: Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: R.r(context, 28),
                          ),
                        ),
                      ),
                      // Main passport/ticket illustration
                      Positioned(
                        bottom: R.r(context, 20),
                        child: Container(
                          width: R.r(context, 100),
                          height: R.r(context, 120),
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
                              Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: R.r(context, 40),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: R.r(context, 60),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: R.r(context, 40),
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
                        bottom: R.r(context, 35),
                        right: R.r(context, 90),
                        child: Container(
                          padding: EdgeInsets.all(R.r(context, 10)),
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
                          child: Icon(
                            Icons.luggage,
                            color: Colors.white,
                            size: R.r(context, 24),
                          ),
                        ),
                      ),
                      // Globe/world illustration
                      Positioned(
                        bottom: R.r(context, 30),
                        left: R.r(context, 75),
                        child: Container(
                          padding: EdgeInsets.all(R.r(context, 8)),
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
                          child: Icon(
                            Icons.public,
                            color: Colors.white,
                            size: R.r(context, 20),
                          ),
                        ),
                      ),
                      // Sparkle effects
                      Positioned(
                        top: R.r(context, 50),
                        left: R.r(context, 50),
                        child: Icon(
                          Icons.auto_awesome,
                          size: R.r(context, 16),
                          color: Colors.amber.shade300,
                        ),
                      ),
                      Positioned(
                        top: R.r(context, 80),
                        right: R.r(context, 50),
                        child: Icon(
                          Icons.auto_awesome,
                          size: R.r(context, 12),
                          color: Colors.pink.shade200,
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
                  'Welcome Back!',
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
                  'Login to continue your journey',
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
            name: 'emailOrPhone',
            autovalidateMode: AutovalidateMode.onUserInteraction,
            builder: (FormFieldState<dynamic> field) {
              return AppTextField(
                label: 'Email Address',
                onChanged: (value) => field.didChange(value),
                errorText: field.errorText,
                prefixIcon: Icons.email_outlined,
              );
            },
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              (value) {
                final v = value?.toString().trim() ?? '';

                final emailRegex =
                    RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

                if (!emailRegex.hasMatch(v)) {
                  return 'Enter a valid email address';
                }
                return null;
              }
            ]),
          ),
          const VSpace(),
          FormBuilderField(
            name: 'password',
            builder: (FormFieldState<dynamic> field) {
              return AppTextField(
                label: 'Password',
                obscureText: _hidePassword,
                onChanged: (value) => field.didChange(value),
                errorText: field.errorText,
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
            validator: FormBuilderValidators.required(
                errorText: 'Password is required'),
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
            height: R.rh(context, 50),
            child: FilledButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      final formState = _loginKey.currentState;
                      if (formState == null) return;

                      if (formState.saveAndValidate()) {
                        setState(() => _isLoading = true);

                        final formData = formState.value;

                        /// 🔹 SANITIZE INPUTS
                        final rawInput = (formData['emailOrPhone'] ?? '')
                            .toString()
                            .trim()
                            .replaceAll(RegExp(r'\s+'), '');

                        final emailOrPhone = rawInput.toLowerCase();
                        final String password =
                            (formData['password'] ?? '').toString().trim();

                        try {
                          /// 🔹 LOGIN API
                          final user = await AuthService.loginUser(
                            emailOrPhone: emailOrPhone,
                            password: password,
                          );

                          if (!context.mounted) return;

                          if (user != null) {
                            /// 🔹 REMEMBER ME
                            if (_rememberMe) {
                              await AuthService.saveRememberMe(
                                  emailOrPhone, password);
                            } else {
                              await AuthService.clearRememberMe();
                            }

                            if (!context.mounted) return;

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

                            final hasCity =
                                await LocationPreferenceService.hasOriginCity();

                            if (!context.mounted) return;

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
                          } else {
                            setState(() => _isLoading = false);
                            final errorMessage = AuthService.lastAuthError ??
                                'Invalid credentials. If you used Google before, continue with Google.';
                            Get.snackbar(
                              'Login Failed',
                              errorMessage,
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
                        } catch (e) {
                          if (!context.mounted) return;
                          setState(() => _isLoading = false);

                          Get.snackbar(
                            'Error',
                            'Something went wrong. Try again.',
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
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('CONTINUE',
                          maxLines: 1,
                          style: TravelloTheme.subtitle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: R.sp(context, 15),
                            letterSpacing: 1.0,
                          ))),
            ),
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
                      'OR CONTINUE WITH',
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

          /// GOOGLE LOGIN - PREMIUM STYLE
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
                onTap: _handleGoogleSignIn,
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
          SizedBox(height: R.rh(context, 12)),
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
                  style: TravelloTheme.caption
                      .copyWith(fontSize: R.sp(context, 15)),
                  children: [
                    TextSpan(
                      text: 'Sign Up Now',
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
