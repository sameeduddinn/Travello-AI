import 'package:flight_app/constants/image_api.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class AuthWrap extends StatelessWidget {
  const AuthWrap({super.key, required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isTablet = screenW >= 600;
    final isLargeTablet = screenW >= 900;

    // Responsive horizontal padding: snug on phone, generous on tablet/iPad
    final hPad = isLargeTablet
        ? screenW * 0.2
        : isTablet
            ? screenW * 0.1
            : 16.0;
    final vPad = screenH < 700 ? 12.0 : 24.0;

    // Card max-width: phone fills, tablet capped nicely
    final cardMaxWidth = isLargeTablet
        ? 520.0
        : isTablet
            ? 520.0
            : double.infinity;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  TravelloTheme.primaryMain.withValues(alpha: 0.8),
                ]
              : [
                  TravelloTheme.primaryMain,
                  TravelloTheme.primaryMain.withValues(alpha: 0.8),
                  const Color(0xFF6366f1),
                ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(ImgApi.welcomeBg),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: hPad,
                vertical: vPad,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardMaxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(isTablet ? 28.0 : 24.0),
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color:
                              TravelloTheme.primaryMain.withValues(alpha: 0.1),
                          blurRadius: 60,
                          offset: const Offset(0, 20),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
