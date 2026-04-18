import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flight_app/constants/app_constants.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/app/app_routes.dart';
import 'package:flight_app/controllers/notification_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/utils/auth_service.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/config/supabase_config.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Supabase anon key is not configured. Update lib/config/supabase_config.dart first.',
    );
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (_) {
    // Supabase init failure (e.g. no internet at launch) — app still opens,
    // auth features will show errors gracefully instead of crashing.
  }

  await AuthService.initializeDemoUsers();

  // TEMPORARY - add this line, run once, then remove it
  // await AuthService.clearAllUsers();

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
    final bool isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      enableScaleWH: () => !isDesktopPlatform,
      enableScaleText: () => !isDesktopPlatform,
      builder: (context, child) {
        return GetMaterialApp(
          title: branding.name,
          debugShowCheckedModeBanner: false,
          navigatorKey: Get.key,
          themeMode: ThemeMode.light, // Light-only
          theme: luxuryLightTheme,
          // Also set darkTheme to the same light theme to prevent any accidental
          // dark-mode switches from changing the visuals.
          darkTheme: luxuryLightTheme,
          initialRoute: AppLink.launchSplash,
          getPages: appRoutes,
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();

            final bool isDesktop = !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.linux);

            return LayoutBuilder(
              builder: (context, constraints) {
                final rawScale = MediaQuery.textScalerOf(context).scale(1.0);
                final safeScale = rawScale.clamp(1.0, 1.05);

                final baseMq = MediaQuery.of(context).copyWith(
                  boldText: false,
                  textScaler: TextScaler.linear(safeScale),
                );

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
                      constraints:
                          const BoxConstraints(maxWidth: desktopMaxWidth),
                      child: MediaQuery(data: desktopMq, child: child),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
