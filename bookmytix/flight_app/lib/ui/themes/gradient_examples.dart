import 'package:flutter/material.dart';
import 'theme_system.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// TRAVELLO AI - GRADIENT USAGE EXAMPLES & PATTERNS
/// Copy-paste these patterns into your screens and widgets
/// ════════════════════════════════════════════════════════════════════════════

/// 📌 EXAMPLE 1: Hero Splash Banner
class GradientHeroBanner extends StatelessWidget {
  const GradientHeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: TravelloTheme.gradientHeroGold,
        borderRadius: TravelloTheme.radiusBig,
        boxShadow: TravelloTheme.shadowLarge,
      ),
      child: Center(
        child: Text(
          'Welcome to Travello AI',
          style: TravelloTheme.title.copyWith(
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 📌 EXAMPLE 2: Premium Card with Gradient
class GradientCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String
      gradientName; // 'accent', 'beige', 'sky', 'sunset', 'ocean', 'ai'

  const GradientCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.gradientName = 'accent',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.getGradient(gradientName),
        borderRadius: TravelloTheme.radiusMedium,
        boxShadow: TravelloTheme.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TravelloTheme.subtitle),
          const SizedBox(height: 8),
          Text(subtitle, style: TravelloTheme.paragraph),
        ],
      ),
    );
  }
}

/// 📌 EXAMPLE 3: Gradient Button with Icon
class GradientIconButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final String gradientName;
  final VoidCallback onPressed;

  const GradientIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.gradientName = 'accent',
  });

  @override
  State<GradientIconButton> createState() => _GradientIconButtonState();
}

class _GradientIconButtonState extends State<GradientIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPressed() {
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 0.95).animate(_controller),
      child: Container(
        decoration: BoxDecoration(
          gradient: context.getGradient(widget.gradientName),
          borderRadius: TravelloTheme.radiusMedium,
          boxShadow: TravelloTheme.shadowGold,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onPressed,
            borderRadius: TravelloTheme.radiusMedium,
            splashColor: Colors.white.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TravelloTheme.subtitle2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 📌 EXAMPLE 4: Gradient Background Page
class GradientBackgroundPage extends StatelessWidget {
  final String backgroundGradient; // 'dark', 'hero', 'sky'
  final Widget child;

  const GradientBackgroundPage({
    super.key,
    required this.child,
    this.backgroundGradient = 'dark',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: context.getGradient(backgroundGradient),
      ),
      child: child,
    );
  }
}

/// 📌 EXAMPLE 5: Travel Feature Box (for Flight/Hotel/Train etc)
class GradientFeatureBox extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String
      travelType; // 'flight'→sky, 'train'→sunset, 'hotel'→ocean, 'ai'→ai
  final VoidCallback onTap;

  const GradientFeatureBox({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.travelType,
    required this.onTap,
  });

  String _getGradientForType(String type) {
    switch (type.toLowerCase()) {
      case 'flight':
        return 'sky';
      case 'train':
        return 'sunset';
      case 'hotel':
        return 'ocean';
      case 'ai':
        return 'ai';
      default:
        return 'accent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: context.getGradient(_getGradientForType(travelType)),
          borderRadius: TravelloTheme.radiusMedium,
          boxShadow: TravelloTheme.shadowMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: TravelloTheme.radiusSmall,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: TravelloTheme.subtitle2),
            const SizedBox(height: 4),
            Text(
              description,
              style: TravelloTheme.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 📌 EXAMPLE 6: Gradient Progress Indicator
class GradientProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String gradientName;

  const GradientProgressBar({
    super.key,
    required this.progress,
    this.gradientName = 'accent',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: TravelloTheme.radiusSmall,
      ),
      child: Stack(
        children: [
          Container(
            width: (MediaQuery.of(context).size.width * progress),
            decoration: BoxDecoration(
              gradient: context.getGradient(gradientName),
              borderRadius: TravelloTheme.radiusSmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// QUICK REFERENCE - Copy these snippets into your code
// ════════════════════════════════════════════════════════════════════════════

/*
┌─ USING GRADIENTS IN YOUR SCREENS ─────────────────────────────────┐

1️⃣  SIMPLE GRADIENT CONTAINER:
    Container(
      decoration: BoxDecoration(
        gradient: TravelloTheme.gradientHeroGold,
        borderRadius: TravelloTheme.radiusMedium,
      ),
      child: YourChild(),
    )

2️⃣  USING CONTEXT EXTENSION (EASIEST):
    context.gradientContainer(
      gradientName: 'hero',
      child: YourChild(),
    )

3️⃣  GRADIENT + SHADOW:
    Container(
      decoration: BoxDecoration(
        gradient: TravelloTheme.gradientAccentGold,
        borderRadius: TravelloTheme.radiusMedium,
        boxShadow: TravelloTheme.shadowLarge,
      ),
      child: YourChild(),
    )

4️⃣  TRAVEL-THEMED GRADIENT (Auto-select by type):
    GradientFeatureBox(
      title: 'Book Flights',
      description: 'Fast & Easy',
      icon: Icons.flight,
      travelType: 'flight',  // sky gradient
      onTap: () => Get.toNamed('/flight'),
    )

5️⃣  GRADIENT BACKGROUND PAGE:
    GradientBackgroundPage(
      backgroundGradient: 'dark',
      child: Scaffold(
        body: YourContent(),
      ),
    )

6️⃣  GRADIENT BUTTON:
    GradientIconButton(
      label: 'Book Now',
      icon: Icons.arrow_forward,
      gradientName: 'sunset',
      onPressed: () {},
    )

════════════════════════════════════════════════════════════════════════════

📊 AVAILABLE GRADIENTS:
  • hero     → Gold Radiant (Splash screens, heroes)
  • dark     → Dark Luxury (Backgrounds)
  • accent   → Gold + Beige (Primary buttons, cards)
  • beige    → Soft Light (Secondary buttons)
  • sky      → Sky Blue (Flight/Air sections)
  • sunset   → Coral to Gold (Train/Transport sections)
  • ocean    → Teal/Cyan (Hotel/Water sections)
  • ai       → Purple + Gold (AI Assistant sections)
  • success  → Green (Success states)
  • warning  → Orange (Alerts, warnings)

════════════════════════════════════════════════════════════════════════════

🎯 SPACING, TEXT & SHADOW USAGE:
  TravelloTheme.spacing(3)        // 24px (3 × 8)
  TravelloTheme.radiusMedium      // BorderRadius.circular(10)
  TravelloTheme.shadowMedium      // Medium box shadow
  TravelloTheme.title             // text style
  TravelloTheme.subtitle          // text style

==========================================================================*/
