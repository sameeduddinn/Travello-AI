import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// TRAVELLO AI - UNIFIED THEME SYSTEM
/// Consolidates all theme definitions + Beautiful Gradient Themes
/// ════════════════════════════════════════════════════════════════════════════

const String appFont = 'Ubuntu';

// ═══════════════════════════════════════════════════════════════════════════
// UNIFIED PALETTE (Consolidates theme_palette.dart)
// ═══════════════════════════════════════════════════════════════════════════
class TravelloTheme {
  // GOLD ACCENT (Primary)
  static const Color primaryMain = Color(0xFFD4AF37);
  static const Color primaryLight = Color(0xFFC6A75E);
  static const Color primaryDark = Color(0xFFB8935C);

  // WARM BEIGE (Secondary)
  static const Color secondaryMain = Color(0xFFE6C68E);
  static const Color secondaryLight = Color(0xFFF5E6D3);
  static const Color secondaryDark = Color(0xFFC6A75E);

  // SKY BLUE (Tertiary)
  static const Color tertiaryMain = Color(0xFF4A90E2);
  static const Color tertiaryLight = Color(0xFF87CEEB);
  static const Color tertiaryDark = Color(0xFF2E5C8A);

  // BACKGROUNDS
  static const Color backgroundLight = Color(0xFFF0F2F5);
  static const Color paperLight = Color(0xFFFFFFFF);
  static const Color paperDark = Color(0xFF0D0D0D);
  static const Color defaultLight = Color(0xFFFFFFFF);
  static const Color defaultDark = Color(0xFF111111);

  // CONTAINERS (Material 3 style surfaces)
  static const Color paperLightDim = Color(0xFFF2F2F2);
  static const Color paperLightContainerLowest = Color(0xFFFFFFFF);
  static const Color paperLightContainerLow = Color(0xFFF7F7F7);
  static const Color paperLightContainerHighest = Color(0xFFEEEEEE);

  static const Color primaryMainContainer = Color(0xFFFFF4D6);
  static const Color secondaryMainContainer = Color(0xFFFFF3DA);

  // TEXT COLORS
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF4D4D4D);
  static const Color textMuted = Color(0xFF808080);
  static const Color textDisabled = Color(0xFFB3B3B3);

  // ═════════════════════════════════════════════════════════════════════════
  // PREMIUM GRADIENT DEFINITIONS (Beautiful Gradients for UI)
  // ═════════════════════════════════════════════════════════════════════════

  /// ✨ HERO SECTION - Luxury Gold Radiant Gradient
  /// Used for: Splash screens, app intro, hero banners
  static const LinearGradient gradientHeroGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD4AF37), // Bright Gold
      Color(0xFFC6A75E), // Muted Gold
      Color(0xFFB8935C), // Deep Gold
    ],
  );

  /// ✨ PREMIUM DARK LUXURY - Deep Background Gradient
  /// Used for: App backgrounds, decorative sections
  static const LinearGradient gradientDarkLuxury = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1A1A), // Dark Grey
      Color(0xFF0D0D0D), // Deep Black
      Color(0xFF000000), // Pure Black
    ],
  );

  /// ✨ ACCENT GRADIENT - Gold + Beige Mix (Buttons, Cards)
  /// Used for: Primary buttons, card accents, highlights
  static const LinearGradient gradientAccentGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD4AF37), // Gold
      Color(0xFFE6C68E), // Beige
    ],
  );

  /// ✨ SOFT BEIGE - Secondary Premium Gradient
  /// Used for: Secondary buttons, calm sections
  static const LinearGradient gradientBeigeLight = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFFFF8E7), // Very Light Beige
      Color(0xFFE6C68E), // Medium Beige
      Color(0xFFC6A75E), // Warm Beige
    ],
  );

  /// ✨ TRAVEL GRADIENT 1 - Sky Blue (Flight themed)
  /// Used for: Flight sections, sky imagery, travel vibes
  static const LinearGradient gradientSkyTravel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF87CEEB), // Sky Blue
      Color(0xFF4A90E2), // Deep Blue
      Color(0xFF2E5C8A), // Navy
    ],
  );

  /// ✨ TRAVEL GRADIENT 2 - Sunset Golden (Train/Hotel themed)
  /// Used for: Train/Hotel sections, warm travel moments
  static const LinearGradient gradientSunsetTravel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF6B6B), // Coral Red
      Color(0xFFFFB347), // Orange
      Color(0xFFD4AF37), // Gold
    ],
  );

  /// ✨ TRAVEL GRADIENT 3 - Ocean Teal (Sea/Water themed)
  /// Used for: Hotel, beaches, water activities
  static const LinearGradient gradientOceanTravel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF20B2AA), // Light Sea Green
      Color(0xFF008B8B), // Dark Cyan
      Color(0xFF004D4D), // Deep Ocean
    ],
  );

  /// ✨ PREMIUM GRADIENT - Vibrant Purple + Gold blend
  /// Used for: AI Assistant, special features, premium sections
  static const LinearGradient gradientAIPremium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B5CF6), // Purple
      Color(0xFFD4AF37), // Gold
      Color(0xFFA855F7), // Lighter Purple
    ],
  );

  /// ✨ GRADIENT - Dark + Gold Accent (Cards elevation)
  /// Used for: Elevated cards, special display panels
  static final LinearGradient gradientElevatedCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFF1A1A1A), // Dark
      const Color(0xFF2D2D2D), // Lighter Dark
      const Color(0xFFD4AF37).withValues(alpha: 0.1), // Gold tint
    ],
  );

  // BRAND GRADIENT VARIANTS (for legacy + new UI)

  static const LinearGradient gradientPrimaryLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE6C68E),
      Color(0xFFD4AF37),
      Color(0xFFC6A75E),
    ],
  );

  static const LinearGradient gradientPrimaryDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFB8935C),
      Color(0xFFD4AF37),
    ],
  );

  static const LinearGradient gradientSecondaryLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF8E7),
      Color(0xFFF5E6D3),
      Color(0xFFE6C68E),
    ],
  );

  static const LinearGradient gradientSecondaryDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC6A75E),
      Color(0xFFE6C68E),
    ],
  );

  /// Eye-catching mix (Gold x Sky)
  static const LinearGradient gradientMixedLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF87CEEB),
      Color(0xFFF5E6D3),
      Color(0xFFD4AF37),
    ],
  );

  static const LinearGradient gradientMixedMain = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4A90E2),
      Color(0xFFD4AF37),
      Color(0xFFE6C68E),
    ],
  );

  static const LinearGradient gradientMixedDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2E5C8A),
      Color(0xFFB8935C),
      Color(0xFF111111),
    ],
  );

  /// ✨ SUCCESS GRADIENT - Green (Confirmations, success states)
  static const LinearGradient gradientSuccess = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF10B981), // Emerald
      Color(0xFF059669), // Dark Emerald
    ],
  );

  /// ✨ WARNING GRADIENT - Orange (Alerts, warnings)
  static const LinearGradient gradientWarning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF59E0B), // Amber
      Color(0xFFD97706), // Dark Amber
    ],
  );

  // ═════════════════════════════════════════════════════════════════════════
  // SPACING (Consolidates theme_spacing.dart)
  // ═════════════════════════════════════════════════════════════════════════
  static double spacing(num val) => spacingUnit(val);
  static const double spacingXSmall = 4;
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingXLarge = 32;

  // ═════════════════════════════════════════════════════════════════════════
  // RADIUS (Consolidates theme_radius.dart)
  // ═════════════════════════════════════════════════════════════════════════
  static const BorderRadius radiusXSmall = BorderRadius.all(Radius.circular(3));
  static const BorderRadius radiusSmall = BorderRadius.all(Radius.circular(5));
  static const BorderRadius radiusMedium =
      BorderRadius.all(Radius.circular(10));
  static const BorderRadius radiusBig = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusMax = BorderRadius.all(Radius.circular(50));

  // ═════════════════════════════════════════════════════════════════════════
  // SHADOWS (Consolidates theme_shadow.dart)
  // ═════════════════════════════════════════════════════════════════════════
  static List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    )
  ];

  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 8,
      offset: const Offset(0, 4),
    )
  ];

  static List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 8),
    )
  ];

  static List<BoxShadow> shadowGold = [
    BoxShadow(
      color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    )
  ];

  // ═════════════════════════════════════════════════════════════════════════
  // TEXT STYLES (Consolidates theme_text.dart)
  // ═════════════════════════════════════════════════════════════════════════
  static const TextStyle titleLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    fontFamily: appFont,
    color: TravelloTheme.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    fontFamily: appFont,
    color: TravelloTheme.textPrimary,
  );

  static const TextStyle title2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: appFont,
    color: TravelloTheme.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: appFont,
    color: TravelloTheme.textPrimary,
  );

  static const TextStyle subtitle2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontFamily: appFont,
    color: TravelloTheme.textPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontFamily: appFont,
    color: TravelloTheme.textSecondary,
  );

  static const TextStyle paragraph = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: appFont,
    color: TravelloTheme.textSecondary,
  );

  static const TextStyle paragraphBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFamily: appFont,
    color: TravelloTheme.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: appFont,
    color: TravelloTheme.textMuted,
  );

  // Additional text styles for specific components
  static const TextStyle sectionHeading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontFamily: appFont,
    color: TravelloTheme.textPrimary,
  );

  static const TextStyle durationBadge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: appFont,
    color: TravelloTheme.textMuted,
  );

  static const TextStyle cardHeading = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFamily: appFont,
    color: Color(0xFFD4AF37),
  );

  static const TextStyle selectSeatHeading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: appFont,
    color: TravelloTheme.textPrimary,
  );

  // ═════════════════════════════════════════════════════════════════════════
  // BUTTON STYLES (Consolidates theme_button.dart)
  // ═════════════════════════════════════════════════════════════════════════
  static ButtonStyle btnPrimary = FilledButton.styleFrom(
    backgroundColor: primaryMain,
    foregroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: radiusMedium),
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  );

  static ButtonStyle btnSecondary = FilledButton.styleFrom(
    backgroundColor: secondaryMain,
    foregroundColor: Colors.black,
    shape: const RoundedRectangleBorder(borderRadius: radiusMedium),
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  );

  static ButtonStyle btnGradient = FilledButton.styleFrom(
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: radiusMedium),
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  );

  // ═════════════════════════════════════════════════════════════════════════
  // BOX DECORATIONS WITH GRADIENTS
  // ═════════════════════════════════════════════════════════════════════════

  /// Premium card decoration with gradient
  static BoxDecoration cardDecoration = BoxDecoration(
    gradient: gradientElevatedCard,
    borderRadius: radiusMedium,
    boxShadow: shadowMedium,
  );

  /// Hero section decoration
  static BoxDecoration heroDecoration = BoxDecoration(
    gradient: gradientHeroGold,
    borderRadius: radiusBig,
    boxShadow: shadowLarge,
  );

  /// Button gradient decoration
  static Decoration buttonGradientDecoration = BoxDecoration(
    gradient: gradientAccentGold,
    borderRadius: radiusMedium,
    boxShadow: shadowGold,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MATERIAL THEME DATA
// ═══════════════════════════════════════════════════════════════════════════

ColorScheme colorScheme(BuildContext context) => Theme.of(context).colorScheme;

double spacingUnit(num unit) => (unit * 8).toDouble();

Color lighten(Color color, [double amount = 0.1]) {
  final t = amount.clamp(0.0, 1.0);
  return Color.lerp(color, Colors.white, t) ?? color;
}

Color darken(Color color, [double amount = 0.1]) {
  final t = amount.clamp(0.0, 1.0);
  return Color.lerp(color, Colors.black, t) ?? color;
}

final ColorScheme _luxuryDarkColorScheme = ColorScheme.fromSeed(
  seedColor: TravelloTheme.primaryMain,
  brightness: Brightness.dark,
).copyWith(
  primary: TravelloTheme.primaryMain,
  secondary: TravelloTheme.secondaryMain,
  tertiary: TravelloTheme.tertiaryMain,
  surface: TravelloTheme.paperDark,
  onSurface: Colors.white,
);

final ColorScheme _luxuryLightColorScheme = ColorScheme.fromSeed(
  seedColor: TravelloTheme.primaryMain,
  brightness: Brightness.light,
).copyWith(
  primary: TravelloTheme.primaryMain,
  secondary: TravelloTheme.secondaryMain,
  tertiary: TravelloTheme.tertiaryMain,
  surface: TravelloTheme.paperLight,
  onSurface: TravelloTheme.textPrimary,
);

final ThemeData luxuryDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: _luxuryDarkColorScheme,
  scaffoldBackgroundColor: TravelloTheme.defaultDark,
  fontFamily: appFont,
  appBarTheme: const AppBarTheme(
    backgroundColor: TravelloTheme.paperDark,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
);

final ThemeData luxuryLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: _luxuryLightColorScheme,
  scaffoldBackgroundColor: TravelloTheme.backgroundLight,
  fontFamily: appFont,
  appBarTheme: const AppBarTheme(
    backgroundColor: TravelloTheme.paperLight,
    foregroundColor: TravelloTheme.textPrimary,
    elevation: 0,
    centerTitle: true,
  ),
);

// ═══════════════════════════════════════════════════════════════════════════
// LEGACY COMPATIBILITY LAYER
// (Many screens still reference these symbols.)
// ═══════════════════════════════════════════════════════════════════════════

class ThemeRadius {
  static const BorderRadius xsmall = TravelloTheme.radiusXSmall;
  static const BorderRadius small = TravelloTheme.radiusSmall;
  static const BorderRadius medium = TravelloTheme.radiusMedium;
  static const BorderRadius big = TravelloTheme.radiusBig;
}

class ThemeShade {
  static BoxShadow shadeSoft(BuildContext context) => BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 10,
        offset: const Offset(0, 4),
      );

  static BoxShadow shadeMedium(BuildContext context) => BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 16,
        offset: const Offset(0, 8),
      );

  static BoxShadow shadeHard(BuildContext context) => BoxShadow(
        color: Colors.black.withValues(alpha: 0.22),
        blurRadius: 24,
        offset: const Offset(0, 12),
      );
}

class ThemePalette {
  static const Color primaryMain = TravelloTheme.primaryMain;
  static const LinearGradient gradientPrimaryLight =
      TravelloTheme.gradientPrimaryLight;
  static const LinearGradient gradientPrimaryDark =
      TravelloTheme.gradientPrimaryDark;
}

class ThemeButton {
  static final ButtonStyle btnSmall = FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.small),
  );

  static final ButtonStyle btnBig = FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
  );

  static final ButtonStyle primary = FilledButton.styleFrom(
    backgroundColor: TravelloTheme.primaryMain,
    foregroundColor: Colors.black,
    shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
  );

  static final ButtonStyle secondary = FilledButton.styleFrom(
    backgroundColor: TravelloTheme.secondaryMain,
    foregroundColor: Colors.black,
    shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
  );

  static final ButtonStyle tertiary = FilledButton.styleFrom(
    backgroundColor: TravelloTheme.tertiaryMain,
    foregroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
  );

  static final ButtonStyle black = FilledButton.styleFrom(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
  );

  static final ButtonStyle white = FilledButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
  );

  static ButtonStyle invert(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: colorScheme(context).surface,
        foregroundColor: colorScheme(context).onSurface,
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle invert2(BuildContext context) => FilledButton.styleFrom(
        backgroundColor: TravelloTheme.primaryMainContainer,
        foregroundColor: colorScheme(context).onPrimaryContainer,
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle outlinedPrimary(BuildContext context) =>
      OutlinedButton.styleFrom(
        foregroundColor: TravelloTheme.primaryMain,
        side: const BorderSide(color: TravelloTheme.primaryMain),
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle outlinedSecondary(BuildContext context) =>
      OutlinedButton.styleFrom(
        foregroundColor: TravelloTheme.secondaryMain,
        side: const BorderSide(color: TravelloTheme.secondaryMain),
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle outlinedTertiary(BuildContext context) =>
      OutlinedButton.styleFrom(
        foregroundColor: TravelloTheme.tertiaryMain,
        side: const BorderSide(color: TravelloTheme.tertiaryMain),
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle outlinedBlack() => OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: Colors.black),
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle outlinedWhite() => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle outlinedInvert(BuildContext context) =>
      OutlinedButton.styleFrom(
        foregroundColor: colorScheme(context).onSurface,
        side: BorderSide(color: colorScheme(context).outline),
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle outlinedInvert2(BuildContext context) =>
      OutlinedButton.styleFrom(
        foregroundColor: colorScheme(context).onPrimaryContainer,
        side: BorderSide(color: colorScheme(context).primaryContainer),
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle outlinedDefault(BuildContext context) =>
      OutlinedButton.styleFrom(
        foregroundColor: colorScheme(context).onSurface,
        side: BorderSide(color: colorScheme(context).outlineVariant),
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle tonalPrimary(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: colorScheme(context).primaryContainer,
        foregroundColor: colorScheme(context).onPrimaryContainer,
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle tonalSecondary(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: colorScheme(context).secondaryContainer,
        foregroundColor: colorScheme(context).onSecondaryContainer,
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle tonalTertiary(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: colorScheme(context).tertiaryContainer,
        foregroundColor: colorScheme(context).onTertiaryContainer,
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle tonalDefault(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: colorScheme(context).surface,
        foregroundColor: colorScheme(context).onSurface,
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.medium),
      );

  static ButtonStyle textPrimary(BuildContext context) => TextButton.styleFrom(
        foregroundColor: TravelloTheme.primaryMain,
      );

  static ButtonStyle textSecondary(BuildContext context) =>
      TextButton.styleFrom(
        foregroundColor: TravelloTheme.secondaryMain,
      );

  static ButtonStyle textTertiary(BuildContext context) => TextButton.styleFrom(
        foregroundColor: TravelloTheme.tertiaryMain,
      );

  static ButtonStyle iconBtn(BuildContext context) => IconButton.styleFrom(
        backgroundColor: TravelloTheme.paperLightContainerLow,
        foregroundColor: colorScheme(context).onSurface,
        shape: const RoundedRectangleBorder(borderRadius: ThemeRadius.small),
      );
}

class VSpace extends StatelessWidget {
  const VSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: TravelloTheme.spacingMedium);
  }
}

class VSpaceShort extends StatelessWidget {
  const VSpaceShort({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: TravelloTheme.spacingSmall);
  }
}

class VSpaceBig extends StatelessWidget {
  const VSpaceBig({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: TravelloTheme.spacingLarge);
  }
}

class LineSpace extends StatelessWidget {
  const LineSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colorScheme(context).outlineVariant.withValues(alpha: 0.25),
      ),
    );
  }
}

class LineList extends StatelessWidget {
  const LineList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: colorScheme(context).outlineVariant.withValues(alpha: 0.35),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// CONVENIENCE EXTENSIONS FOR EASY USAGE
/// ════════════════════════════════════════════════════════════════════════════

extension TravelloGradients on BuildContext {
  /// Get gradient by name
  LinearGradient getGradient(String name) {
    switch (name) {
      case 'hero':
        return TravelloTheme.gradientHeroGold;
      case 'dark':
        return TravelloTheme.gradientDarkLuxury;
      case 'accent':
        return TravelloTheme.gradientAccentGold;
      case 'beige':
        return TravelloTheme.gradientBeigeLight;
      case 'sky':
        return TravelloTheme.gradientSkyTravel;
      case 'sunset':
        return TravelloTheme.gradientSunsetTravel;
      case 'ocean':
        return TravelloTheme.gradientOceanTravel;
      case 'ai':
        return TravelloTheme.gradientAIPremium;
      case 'success':
        return TravelloTheme.gradientSuccess;
      case 'warning':
        return TravelloTheme.gradientWarning;
      default:
        return TravelloTheme.gradientAccentGold;
    }
  }

  /// Quick gradient container builder
  Widget gradientContainer({
    required String gradientName,
    required Widget child,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadows,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: getGradient(gradientName),
        borderRadius: borderRadius ?? TravelloTheme.radiusMedium,
        boxShadow: shadows ?? TravelloTheme.shadowMedium,
      ),
      child: child,
    );
  }
}
