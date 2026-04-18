import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/widgets/user/verification_code_input.dart';
import 'package:get/route_manager.dart';

class EmailVerification extends StatelessWidget {
  const EmailVerification({super.key});

  @override
  Widget build(BuildContext context) {
    // Get email from route parameters
    final String email = Get.parameters['email'] ?? 'user@example.com';

    return VerificationCodeInput(
      email: email,
      onVerified: () {
        // Navigate to login page after successful verification
        Future.delayed(const Duration(milliseconds: 500), () {
          Get.offAllNamed(AppLink.login);
          // Show message to login with verified email
          Future.delayed(const Duration(milliseconds: 300), () {
            Get.snackbar(
              '✅ Email Verified',
              'Please login with your credentials to continue',
              backgroundColor: Colors.green.shade600,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 3),
              icon: const Icon(Icons.verified, color: Colors.white),
              borderRadius: 10.r,
              margin: EdgeInsets.all(10.r),
            );
          });
        });
      },
    );
  }
}
