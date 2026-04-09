import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/user/auth_wrap.dart';
import 'package:flight_app/widgets/user/otp_form.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class OtpPin extends StatelessWidget {
  const OtpPin({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        forceMaterialTransparency: true,
        leading: IconButton(
          onPressed: () {
            Get.toNamed(AppLink.register);
          },
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surface,
            elevation: 2,
            shadowColor: Colors.black
          ),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8),
        actions: [
          FilledButton(
            onPressed: () {
              Get.toNamed(AppLink.contact);
            },
            style: ThemeButton.btnSmall.merge(ThemeButton.white),
            child: const Row(
              children: [
                Icon(Icons.headset_mic, color: TravelloTheme.primaryMain),
                SizedBox(width: 4),
                Text('Help and Support', style: TextStyle(color: TravelloTheme.primaryMain)),
              ],
            )
          )
        ],
      ),
      body: const AuthWrap(content: OtpForm())
    );
  }
}