import 'dart:async';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:get/get.dart';
import 'package:flight_app/widgets/app_input/app_textfield.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ResetForm extends StatefulWidget {
  const ResetForm({super.key});

  @override
  State<ResetForm> createState() => _ResetFormState();
}

class _ResetFormState extends State<ResetForm> {
  int _currentStep = 1; // 1: Email, 2: Verification, 3: New Password
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final bool _isNotValid = false;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;

  // Verification code
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _remainingSeconds = 60;
  bool _canResend = false;
  String _verificationCode = ''; // Stores the sent code

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _codeControllers[i].addListener(() {
        if (_codeControllers[i].text.length == 1 && i < 5) {
          _codeFocusNodes[i + 1].requestFocus();
        }
        if (_codeControllers.every((c) => c.text.isNotEmpty)) {
          _verifyCode();
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _codeFocusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _sendVerificationCode() {
    // Generate random 6-digit code (in production, send via email/SMS)
    _verificationCode = '123456'; // Demo code
    _startTimer();

    Get.snackbar(
      'Verification Code Sent',
      'A 6-digit code has been sent to ${_emailController.text}',
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.mark_email_read, color: Colors.white),
      borderRadius: 10,
      margin: const EdgeInsets.all(10),
    );
  }

  void _verifyCode() async {
    final enteredCode = _codeControllers.map((c) => c.text).join();

    if (enteredCode == _verificationCode) {
      setState(() {
        _currentStep = 3;
      });
      Get.snackbar(
        'Verification Successful',
        'Please set your new password',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
    } else {
      Get.snackbar(
        'Invalid Code',
        'The verification code you entered is incorrect',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.error_outline, color: Colors.white),
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
      // Clear all fields
      for (var controller in _codeControllers) {
        controller.clear();
      }
      _codeFocusNodes[0].requestFocus();
    }
  }

  Future<void> _handleEmailSubmit() async {
    if (_emailFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Check if email exists
      final emailExists =
          await AuthService.checkEmailExists(_emailController.text);

      setState(() {
        _isLoading = false;
      });

      if (emailExists) {
        setState(() {
          _currentStep = 2;
        });
        _sendVerificationCode();
      } else {
        Get.snackbar(
          'Email Not Found',
          'No account found with this email',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
          icon: const Icon(Icons.error_outline, color: Colors.white),
          borderRadius: 10,
          margin: const EdgeInsets.all(10),
        );
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_passwordFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final success = await AuthService.resetPassword(
        emailOrPhone: _emailController.text,
        newPassword: _newPasswordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        Get.snackbar(
          'Password Changed',
          'Your password has been successfully changed',
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
          icon: const Icon(Icons.check_circle, color: Colors.white),
          borderRadius: 10,
          margin: const EdgeInsets.all(10),
        );
        await Future.delayed(const Duration(seconds: 1));
        Get.toNamed(AppLink.login);
      } else {
        Get.snackbar(
          'Reset Failed',
          'Failed to reset password. Please try again.',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
          icon: const Icon(Icons.error_outline, color: Colors.white),
          borderRadius: 10,
          margin: const EdgeInsets.all(10),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: ThemeSize.xs),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VSpace(),
            // Progress Indicator
            Row(
              children: List.generate(3, (index) {
                final stepNumber = index + 1;
                final isActive = stepNumber == _currentStep;
                final isCompleted = stepNumber < _currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive || isCompleted
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const VSpace(),

            // Step Content
            if (_currentStep == 1) _buildEmailStep(colorScheme),
            if (_currentStep == 2) _buildVerificationStep(colorScheme),
            if (_currentStep == 3) _buildNewPasswordStep(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailStep(ColorScheme colorScheme) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forgot Password?', style: TravelloTheme.title2),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a verification code',
            style: TravelloTheme.headline
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const VSpace(),
          AppTextField(
            controller: _emailController,
            label: 'Email Address',
            onChanged: (_) {},
            errorText: _isNotValid ? 'Please enter a valid email' : null,
            prefixIcon: Icons.email_outlined,
            validator:
                FormBuilderValidators.compose(<FormFieldValidator<String>>[
              FormBuilderValidators.required(),
              FormBuilderValidators.email(),
            ]),
          ),
          const VSpace(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _isLoading ? null : _handleEmailSubmit,
              style: ThemeButton.btnBig.merge(ThemeButton.primary),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('SEND CODE', style: TravelloTheme.subtitle),
            ),
          ),
          const VSpaceBig(),
        ],
      ),
    );
  }

  Widget _buildVerificationStep(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verification Code', style: TravelloTheme.title2),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to\n${_emailController.text}',
          style: TravelloTheme.headline
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const VSpace(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 50,
              height: 60,
              child: TextField(
                controller: _codeControllers[index],
                focusNode: _codeFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: TravelloTheme.title2,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (value) {
                  if (value.isEmpty && index > 0) {
                    _codeFocusNodes[index - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const VSpace(),
        Center(
          child: Column(
            children: [
              if (!_canResend)
                Text(
                  'Resend code in $_remainingSeconds seconds',
                  style: TravelloTheme.caption
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              if (_canResend)
                TextButton(
                  onPressed: () {
                    _sendVerificationCode();
                    for (var controller in _codeControllers) {
                      controller.clear();
                    }
                    _codeFocusNodes[0].requestFocus();
                  },
                  child: Text(
                    'Resend Code',
                    style: TravelloTheme.subtitle.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const VSpace(),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _currentStep = 1;
                for (var controller in _codeControllers) {
                  controller.clear();
                }
                _timer?.cancel();
              });
            },
            style: ThemeButton.btnBig,
            child: const Text('CHANGE EMAIL', style: TravelloTheme.subtitle),
          ),
        ),
        const VSpaceBig(),
      ],
    );
  }

  Widget _buildNewPasswordStep(ColorScheme colorScheme) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create New Password', style: TravelloTheme.title2),
          const SizedBox(height: 8),
          Text(
            'Your new password must be different from previously used passwords',
            style: TravelloTheme.headline
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const VSpace(),
          AppTextField(
            controller: _newPasswordController,
            label: 'New Password',
            obscureText: _hideNewPassword,
            onChanged: (_) {},
            prefixIcon: Icons.lock_outline,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _hideNewPassword = !_hideNewPassword;
                });
              },
              icon: _hideNewPassword
                  ? const Icon(Icons.visibility_outlined, size: 20)
                  : const Icon(Icons.visibility_off_outlined, size: 20),
            ),
            validator:
                FormBuilderValidators.compose(<FormFieldValidator<String>>[
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(6,
                  errorText: 'Password must be at least 6 characters'),
            ]),
          ),
          const VSpace(),
          AppTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            obscureText: _hideConfirmPassword,
            onChanged: (_) {},
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const VSpace(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _isLoading ? null : _handlePasswordReset,
              style: ThemeButton.btnBig.merge(ThemeButton.primary),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('RESET PASSWORD', style: TravelloTheme.subtitle),
            ),
          ),
          const VSpaceBig(),
        ],
      ),
    );
  }
}
