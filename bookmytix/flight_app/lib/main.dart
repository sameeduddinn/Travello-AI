import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/app/app_routes.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize demo users from user.dart on first launch
  await AuthService.initializeDemoUsers();
  
  // TEMPORARY - add this line, run once, then remove it
  await AuthService.clearAllUsers(); 

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

    // Light-only app: always keep ThemeMode.light.
    // (Even if an old preference says "dark", we ignore it.)
    Get.changeThemeMode(ThemeMode.light);
  }

  MainApp({super.key}) {
    _getThemeStatus();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: branding.name,
      debugShowCheckedModeBanner: false,
      navigatorKey: Get.key,
      themeMode: ThemeMode.light, // Light-only
      theme: luxuryLightTheme,
      // Also set darkTheme to the same light theme to prevent any accidental
      // dark-mode switches from changing the visuals.
      darkTheme: luxuryLightTheme,
      initialRoute: '/',
      getPages: appRoutes,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();

        final bool isDesktop = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux);

        return LayoutBuilder(
          builder: (context, constraints) {
            final baseMq = MediaQuery.of(context).copyWith(boldText: false);

            if (!isDesktop) {
              return MediaQuery(data: baseMq, child: child);
            }

            const desktopMaxWidth = 393.0;
            final constrainedWidth = constraints.maxWidth > desktopMaxWidth
                ? desktopMaxWidth
                : constraints.maxWidth;

            final desktopMq = baseMq.copyWith(
              size: Size(constrainedWidth, baseMq.size.height),
            );

            return ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: desktopMaxWidth),
                  child: MediaQuery(data: desktopMq, child: child),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
