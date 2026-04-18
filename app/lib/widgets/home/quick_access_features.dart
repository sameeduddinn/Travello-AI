import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

const _kGold = Color(0xFFD4AF37);
const _kGoldDeep = Color(0xFFB8860B);

class QuickAccessFeatures extends StatelessWidget {
  const QuickAccessFeatures({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final hPad = w >= 1200
        ? spacingUnit(8)
        : w >= 720
            ? 32.0
            : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Features',
              style: TravelloTheme.title.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme(context).onSurface,
              )),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (_, constraints) {
            final cards = [
              _FeatureCard(
                icon: Icons.wb_sunny_outlined,
                title: 'Weather',
                subtitle: 'Live Forecasts',
                onTap: () => Get.toNamed(AppLink.weather),
              ),
              _FeatureCard(
                iconWidget: const _AiSparkleIcon(),
                title: 'AI Assistant',
                subtitle: 'Smart Travel Help',
                onTap: () => Get.toNamed(AppLink.aiAssistant),
              ),
              _FeatureCard(
                icon: Icons.local_hospital_outlined,
                title: 'Healthcare',
                subtitle: 'Emergency Help',
                onTap: () => Get.toNamed(AppLink.healthcare),
              ),
            ];

            final availableWidth = constraints.maxWidth;

            final gap = availableWidth >= 600 ? 16.0 : 12.0;
            const crossAxisCount = 3;
            final cardWidth =
                (availableWidth - gap * (crossAxisCount - 1)) / crossAxisCount;
            final cardHeight = cardWidth >= 180
                ? 176.0
                : cardWidth >= 145
                    ? 152.0
                    : 118.0;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              alignment: WrapAlignment.center,
              children: cards
                  .map((card) => SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: card,
                      ))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    this.icon,
    this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : assert(icon != null || iconWidget != null);

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;

    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = constraints.maxWidth;
      final isCompact = cardWidth < 150;
      final isMedium = cardWidth < 190;

      final iconSize = isCompact
          ? 20.0
          : isMedium
              ? 24.0
              : 30.0;
      final titleSize = isCompact
          ? 11.0
          : isMedium
              ? 12.5
              : 14.5;
      final subSize = isCompact
          ? 8.5
          : isMedium
              ? 9.5
              : 10.5;
      final pad = isCompact
          ? 10.0
          : isMedium
              ? 13.0
              : 16.0;
      final iconPad = isCompact ? 6.0 : 8.0;

      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed
                ? 0.97
                : active
                    ? 1.03
                    : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: active
                      ? [_kGold, _kGoldDeep]
                      : [const Color(0xFFE8C547), _kGoldDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kGold.withValues(alpha: active ? 0.40 : 0.20),
                    blurRadius: active ? 16 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(iconPad),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: widget.iconWidget ??
                        Icon(widget.icon, color: Colors.white, size: iconSize),
                  ),
                  SizedBox(height: isCompact ? 6 : 9.6),
                  Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  const SizedBox(height: 2),
                  Text(widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: subSize,
                        color: Colors.white.withValues(alpha: 0.80),
                      )),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// A custom composite AI icon — chat bubble with sparkle accents
class _AiSparkleIcon extends StatelessWidget {
  const _AiSparkleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main bot face
          const Center(
            child: Icon(Icons.smart_toy_outlined, color: Colors.white, size: 24),
          ),
          // Top-right sparkle
          Positioned(
            top: -4,
            right: -4,
            child: Icon(Icons.auto_awesome,
                color: Colors.yellow.shade200, size: 12),
          ),
          // Bottom-left mini sparkle
          Positioned(
            bottom: -2,
            left: -3,
            child: Icon(Icons.auto_awesome,
                color: Colors.yellow.shade100, size: 8),
          ),
        ],
      ),
    );
  }
}
