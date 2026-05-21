import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';
import 'package:flight_app/utils/responsive_helper.dart';

/// ✨ ENTERPRISE-GRADE DYNAMIC HERO SECTION

class HeroSection extends StatelessWidget {
  final String serviceType;
  final VoidCallback? onCtaTap;

  const HeroSection({
    super.key,
    required this.serviceType,
    this.onCtaTap,
  });

  /// Hero content configuration per service
  Map<String, dynamic> get _heroContent {
    switch (serviceType) {
      case 'train':
        return {
          'image': 'assets/images/railway_banner.jpg',
          'title': 'Travel by Train Comfortably',
          'subtitle': 'Reserve your train seat across Pakistan',
          'cta': 'Book Your Train',
          'gradient': [
            const Color(0xFF0D1A0D).withValues(alpha: 0.72),
            const Color(0xFF1A3A1A).withValues(alpha: 0.45),
          ],
          'accentColor': TravelloTheme.primaryMain,
        };
      case 'hotel':
        return {
          'image': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80',
          'isNetwork': true,
          'title': 'Find Your Perfect Stay',
          'subtitle': 'Discover hotels at best nightly rates',
          'cta': 'Book Your Stay',
          'gradient': [
            const Color(0xFF1A0A00).withValues(alpha: 0.72),
            const Color(0xFF3D1F00).withValues(alpha: 0.45),
          ],
          'accentColor': TravelloTheme.primaryMain,
        };
      case 'car':
        return {
          'image': 'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=800&q=80',
          'isNetwork': true,
          'title': 'Book a Driver, Anytime',
          'subtitle': 'Professional drivers across Pakistan',
          'cta': 'Fill Form Below',
          'gradient': [
            const Color(0xFF0A0E1A).withValues(alpha: 0.72),
            const Color(0xFF1A2340).withValues(alpha: 0.45),
          ],
          'accentColor': TravelloTheme.primaryMain,
        };
      case 'flight':
      default:
        return {
          'image': 'assets/images/home_banner.jpg',
          'title': 'Where do you want to fly?',
          'subtitle': 'Book domestic flights across Pakistan',
          'cta': 'Book Your Flight',
          'gradient': [
            const Color(0xFF1A0E00).withValues(alpha: 0.72),
            const Color(0xFF3D2B00).withValues(alpha: 0.45),
          ],
          'accentColor': TravelloTheme.primaryMain,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _heroContent;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: Container(
        key: ValueKey(serviceType),
        height: screenHeight * (isMobile ? 0.50 : 0.55),
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: (content['isNetwork'] == true)
                ? NetworkImage(content['image']) as ImageProvider
                : AssetImage(content['image']),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.25),
              BlendMode.darken,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: content['gradient'],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: spacingUnit(isMobile ? 2 : 3)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Gold accent line — luxury brand signal
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: child,
                    ),
                    child: Container(
                      width: R.r(context, isMobile ? 36 : 48),
                      height: 2,
                      margin: EdgeInsets.only(bottom: R.rh(context, 14)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            TravelloTheme.primaryMain.withValues(alpha: 0.0),
                            TravelloTheme.primaryMain.withValues(alpha: 0.55),
                            TravelloTheme.primaryMain.withValues(alpha: 0.0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Main headline
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      content['title'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: R.sp(context, isMobile ? 26 : 36),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5,
                        shadows: const [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: R.rh(context, 16)),

                  // Subtitle
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 15 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      content['subtitle'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: R.sp(context, 16),
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.95),
                        height: 1.5,
                        letterSpacing: 0.3,
                        shadows: const [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: spacingUnit(isMobile ? 2 : 4)),

                  // Premium CTA Button
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 0.9 + (0.1 * value),
                          child: child,
                        ),
                      );
                    },
                    child: _buildPremiumCTA(context, content['cta'], isMobile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCTA(BuildContext context, String label, bool isMobile) {
    return _HoverScaleButton(
      onTap: onCtaTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacingUnit(isMobile ? 3 : 5),
          vertical: spacingUnit(isMobile ? 1.5 : 2),
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              TravelloTheme.primaryMain,
              TravelloTheme.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: TravelloTheme.primaryMain.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: R.sp(context, isMobile ? 15 : 18),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: R.r(context, 12)),
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: R.r(context, 22),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium hover/press scale animation wrapper
class _HoverScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverScaleButton({
    required this.child,
    this.onTap,
  });

  @override
  State<_HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<_HoverScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
