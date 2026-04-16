import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/user/auth_wrap.dart';
import 'package:flight_app/widgets/user/otp_form.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class OtpPin extends StatelessWidget {
  const OtpPin({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isCompact = MediaQuery.of(context).size.width <= 370;

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
                shadowColor: Colors.black),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: R.r(context, 8)),
          actions: [
            FilledButton(
                onPressed: () {
                  Get.toNamed(AppLink.contact);
                },
                style: ThemeButton.btnSmall.merge(ThemeButton.white),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.headset_mic,
                        color: TravelloTheme.primaryMain,
                        size: R.r(context, 16)),
                    SizedBox(width: isCompact ? 2.w : 4.w),
                    Text(isCompact ? 'Help' : 'Help and Support',
                        style: TextStyle(
                          color: TravelloTheme.primaryMain,
                          fontSize: R.sp(context, 12),
                        )),
                  ],
                ))
          ],
        ),
        body: const AuthWrap(content: OtpForm()));
  }
}
