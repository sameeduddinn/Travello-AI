import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/screens/auth/login.dart';
import 'package:flight_app/screens/auth/otp_pin.dart';
import 'package:flight_app/screens/auth/register.dart';
import 'package:flight_app/screens/auth/reset_password.dart';
import 'package:flight_app/screens/auth/welcome.dart';
import 'package:flight_app/ui/layouts/general_layout.dart';
import 'package:get/route_manager.dart';

const int pageTransitionDuration = 200;

final List<GetPage> routesAuth = [
  GetPage(
    name: AppLink.welcome,
    page: () => const GeneralLayout(content: Welcome()),
  ),
  GetPage(
    name: AppLink.register,
    page: () => const GeneralLayout(content: Register()),
  ),
  GetPage(
    name: AppLink.login,
    page: () => const GeneralLayout(content: Login()),
  ),
  GetPage(
    name: AppLink.otp,
    page: () => const GeneralLayout(content: OtpPin()),
  ),
  GetPage(
    name: AppLink.resetPassword,
    page: () => const GeneralLayout(content: ResetPassword()),
  ),
];