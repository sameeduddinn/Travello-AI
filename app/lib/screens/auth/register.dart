import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/utils/responsive_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/widgets/user/auth_wrap.dart';
import 'package:flight_app/widgets/user/register_form.dart';

class Register extends StatelessWidget {
  const Register({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          toolbarHeight: 56.h,
          actionsPadding: EdgeInsets.only(right: 8.w),
          actions: [
            TextButton(
                onPressed: () {
                  Get.toNamed(AppLink.login);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  minimumSize: Size(0, 36.h),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('LOGIN',
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
        body: const AuthWrap(content: RegisterForm()));
  }
}
