import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/responsive_helper.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/user/auth_wrap.dart';
import 'package:flight_app/widgets/user/login_form.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          forceMaterialTransparency: true,
          toolbarHeight: isDesktop ? 56.h : 44.h,
          leadingWidth: isDesktop ? 64.w : 48.w,
          leading: Padding(
            padding: EdgeInsets.only(
              left: 12.w,
              top: isDesktop ? 2.h : 0,
              bottom: isDesktop ? 2.h : 0,
            ),
            child: BackIconButton(
                isSquare: true,
                onTap: () {
                  Get.back();
                }),
          ),
          actionsPadding: EdgeInsets.only(right: isDesktop ? 8.w : 0),
          actions: [
            TextButton(
                onPressed: () {
                  Get.toNamed(AppLink.register);
                },
                style: TextButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(horizontal: isDesktop ? 8.w : 4.w),
                  minimumSize: Size(0, isDesktop ? 36.h : 32.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('SIGN UP',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: R.sp(context, 13))),
                    SizedBox(width: 4.w),
                    Icon(Icons.arrow_forward,
                        color: Colors.white, size: R.r(context, 16))
                  ],
                ))
          ],
        ),
        body: const AuthWrap(content: LoginForm()));
  }
}
