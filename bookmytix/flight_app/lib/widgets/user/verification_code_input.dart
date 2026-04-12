import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/route_manager.dart';
import 'dart:async';
import 'package:flight_app/ui/themes/theme_system.dart';

class VerificationCodeInput extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;

  const VerificationCodeInput({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<VerificationCodeInput> createState() => _VerificationCodeInputState();
}

class _VerificationCodeInputState extends State<VerificationCodeInput> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _resendCode() {
    Get.snackbar(
      'Code Resent',
      'A new verification code has been sent to ${widget.email}',
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.email_outlined, color: Colors.white),
      borderRadius: 10,
      margin: const EdgeInsets.all(10),
    );
    _startTimer();
  }

  void _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      Get.snackbar(
        'Invalid Code',
        'Please enter the complete 6-digit code',
        backgroundColor: Colors.orange.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.warning_outlined, color: Colors.white),
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isVerifying = false;
    });

    // For demo, accept "123456" as valid code
    if (code == '123456') {
      Get.snackbar(
        'Verified',
        'Email verified successfully!',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
        borderRadius: 10,
        margin: const EdgeInsets.all(10),
      );
      widget.onVerified();
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
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // Illustration
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.2),
                      colorScheme.secondary.withValues(alpha: 0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.email_outlined,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                'Verify Your Email',
                style: TravelloTheme.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: spacingUnit(0.75)),

              // Subtitle
              Text(
                'We sent a verification code to',
                style: TravelloTheme.paragraph.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacingUnit(0.4)),
              Text(
                widget.email,
                style: TravelloTheme.subtitle.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Code Input Boxes
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  // Calculate box size with tighter spacing for small screens
                  const spacing = 4;
                  const totalSpacing = spacing * 10; // 5 gaps between 6 boxes
                  final boxSize =
                      ((availableWidth - totalSpacing) / 6).clamp(45.0, 58.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: spacing / 2),
                        child: _CodeInputBox(
                          size: boxSize,
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            // Auto-verify when all 6 digits are entered
                            if (index == 5 && value.isNotEmpty) {
                              _verifyCode();
                            }
                          },
                        ),
                      );
                    }),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Timer and Resend
              _secondsRemaining > 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Resend code in $_secondsRemaining seconds',
                          style: TravelloTheme.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  : TextButton.icon(
                      onPressed: _resendCode,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'Resend Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

              const SizedBox(height: 16),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  style: ThemeButton.btnBig.merge(ThemeButton.primary),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'VERIFY CODE',
                          style: TravelloTheme.subtitle,
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Demo hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Demo: Use code 123456 to verify',
                        style: TravelloTheme.caption.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom padding for safe scrolling
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeInputBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final double size;

  const _CodeInputBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.size = 50,
  });

  @override
  State<_CodeInputBox> createState() => _CodeInputBoxState();
}

class _CodeInputBoxState extends State<_CodeInputBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onValueChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onValueChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  void _onValueChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFocus = widget.focusNode.hasFocus;
    final hasValue = widget.controller.text.isNotEmpty;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: hasFocus
            ? colorScheme.primaryContainer.withValues(alpha: 0.2)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFocus
              ? colorScheme.primary
              : hasValue
                  ? colorScheme.primary.withValues(alpha: 0.4)
                  : colorScheme.outline.withValues(alpha: 0.3),
          width: hasFocus ? 2.5 : 2,
        ),
        boxShadow: [
          if (hasFocus || hasValue)
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            showCursor: false,
            style: TravelloTheme.title.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
              isDense: true,
            ),
            onChanged: widget.onChanged,
          ),
          // Custom animated cursor
          if (hasFocus && !hasValue)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value > 0.5 ? 1.0 : 0.3,
                  child: Container(
                    width: 2,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              },
              onEnd: () {
                if (mounted && hasFocus && !hasValue) {
                  setState(() {});
                }
              },
            ),
        ],
      ),
    );
  }
}
