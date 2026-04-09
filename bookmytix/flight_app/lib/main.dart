import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/app/app_routes.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:flight_app/ui/themes/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/utils/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize demo users from user.dart on first launch
  await AuthService.initializeDemoUsers();

  // Register global controllers
  Get.put(NotificationController(), permanent: true);

  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  final RxString _themeMode = 'auto'.obs;

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  _getThemeStatus() async {
    var mode = _prefs.then((SharedPreferences prefs) {
      return prefs.getString('appTheme') ?? 'auto';
    }).obs;

    _themeMode.value = await mode.value;

    switch (_themeMode.value) {
      case 'dark':
        Get.changeThemeMode(ThemeMode.dark);
        break;
      case 'light':
        Get.changeThemeMode(ThemeMode.light);
        break;
      default:
        break;
    }
  }

  MainApp({super.key}) {
    _getThemeStatus();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: branding.name,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Always use luxury dark theme
      theme: luxuryDarkTheme,
      darkTheme: luxuryDarkTheme,
      initialRoute: '/',
      getPages: appRoutes,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(boldText: false),
        child: child!,
      ),
    );
  }
}
