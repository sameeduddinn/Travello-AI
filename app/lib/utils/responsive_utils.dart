import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Responsive utility class for handling different screen sizes
/// Follows industry-standard breakpoints (Bootstrap, Tailwind, Material Design)
/// Platform-aware: Optimized separately for Web and Native Mobile apps
class ResponsiveUtils {
  // Breakpoints - Industry Standard
  // Mobile:  < 768px  (phones)
  // Tablet:  768-1024px  (tablets, small laptops)
  // Desktop: >= 1024px  (laptops, desktops, large screens)
  static const double mobileBreakpoint = 768.0;
  static const double desktopBreakpoint = 1024.0;

  // Max widths for different screen sizes
  // Based on popular frameworks (Bootstrap: 1140px, Tailwind: 1280px, Material: 1200px)
  static const double mobileMaxWidth = double.infinity; // Full width on mobile
  static const double tabletMaxWidth =
      900.0; // Comfortable reading width on tablets
  static const double desktopMaxWidth =
      1280.0; // Optimal desktop width (matches YouTube, Airbnb)

  /// Get maximum width based on screen size and platform
  ///
  /// WEB BEHAVIOR (Browser):
  /// - Mobile (< 768px): Full width - uses entire screen
  /// - Tablet (768-1024px): 900px max - centered, comfortable reading
  /// - Desktop (>= 1024px): 1280px max - professional layout (matches YouTube, Airbnb)
  ///
  /// MOBILE APP BEHAVIOR (Android/iOS APK/IPA):
  /// - Always uses full width (infinity) for native mobile experience
  /// - No artificial constraints - uses entire device screen
  /// - Works perfectly on phones, tablets, and foldables
  ///
  static double getMaxWidth(BuildContext context) {
    // ✅ Native mobile apps (Android/iOS): Always use full device width
    // This ensures downloaded apps use entire screen (phones, iPads, tablets)
    if (!kIsWeb) {
      return double.infinity; // Full width for native apps
    }

    // 🌐 Web browsers only: Use responsive breakpoints
    final width = MediaQuery.of(context).size.width;

    if (width < mobileBreakpoint) {
      return mobileMaxWidth; // Full width on mobile browsers
    } else if (width < desktopBreakpoint) {
      return tabletMaxWidth; // 900px max on tablets/small laptops
    } else {
      return desktopMaxWidth; // 1280px max on desktop browsers
    }
  }

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Get responsive padding
  static double getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return 16.0;
    } else if (isTablet(context)) {
      return 24.0;
    } else {
      return 32.0;
    }
  }

  /// Get responsive grid columns
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) {
      return 1; // Single column on mobile
    } else if (isTablet(context)) {
      return 2; // Two columns on tablet
    } else {
      return 3; // Three columns on desktop
    }
  }

  /// Get responsive font size multiplier
  static double getFontSizeMultiplier(BuildContext context) {
    if (isMobile(context)) {
      return 1.0;
    } else if (isTablet(context)) {
      return 1.1;
    } else {
      return 1.2;
    }
  }

  /// Get responsive cross axis count for GridView
  static int getCrossAxisCount(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 3;
    }
  }
}
