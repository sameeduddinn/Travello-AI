import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallPhone = screenWidth < 380 || screenHeight < 640;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: TravelloTheme.primaryMain),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Container(
                    padding: EdgeInsets.all(R.r(context, 24)),
                    decoration: BoxDecoration(
                        color: TravelloTheme.paperLight.withValues(alpha: 0.1),
                        image: DecorationImage(
                            image: AssetImage(ImgApi.welcomeBg),
                            fit: BoxFit.cover)),
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: ThemeSize.sm),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              /// TEXT
                              Text(
                                'Welcome to ${branding.name}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize:
                                        R.sp(context, isSmallPhone ? 32 : 42),
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1),
                              ),
                              const VSpaceShort(),
                              Text(branding.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TravelloTheme.title2.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.normal)),
                              const VSpaceBig(),

                              /// BUTTONS
                              SizedBox(
                                width: double.infinity,
                                height: R.rh(context, isSmallPhone ? 50 : 56),
                                child: FilledButton(
                                    onPressed: () {
                                      // Direct navigation to register page
                                      Get.toNamed('/register');
                                    },
                                    style: ThemeButton.btnBig.merge(
                                      FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor:
                                            TravelloTheme.primaryMain,
                                        elevation: 2,
                                        shadowColor: Colors.black26,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('SIGN UP',
                                          maxLines: 1,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: R.sp(context, 16),
                                              letterSpacing: 1)),
                                    )),
                              ),
                              Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: R.rh(context, 24)),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Expanded(child: LineList()),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: R.r(context, 8.0)),
                                          child: Text(
                                              'Already have an account?',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: R.sp(context,
                                                      isSmallPhone ? 14 : 16),
                                                  color: Colors.white)),
                                        ),
                                        const Expanded(child: LineList()),
                                      ])),
                              SizedBox(
                                width: double.infinity,
                                height: R.rh(context, isSmallPhone ? 50 : 56),
                                child: OutlinedButton(
                                    onPressed: () {
                                      // Direct navigation to login page
                                      Get.toNamed('/login');
                                    },
                                    style: ThemeButton.btnBig.merge(
                                      OutlinedButton.styleFrom(
                                        foregroundColor:
                                            TravelloTheme.primaryMain,
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.white, width: 2),
                                        elevation: 2,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('LOGIN',
                                          maxLines: 1,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: R.sp(context, 16),
                                              letterSpacing: 1)),
                                    )),
                              ),
                            ]),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
