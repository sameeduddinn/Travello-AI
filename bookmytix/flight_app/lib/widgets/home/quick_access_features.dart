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
    final isDesktop = w > 1200;
    final isTablet = w >= 600;

    final hPad = isDesktop
        ? spacingUnit(8)
        : isTablet
            ? 32.0
            : 16.0;
    final gap = spacingUnit(isTablet ? 2.5 : 1.5);

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
                icon: Icons.local_hospital_outlined,
                title: 'Healthcare',
                subtitle: 'Emergency Help',
                onTap: () => Get.toNamed(AppLink.healthcare),
              ),
              _FeatureCard(
                icon: Icons.psychology_outlined,
                title: 'AI Assistant',
                subtitle: 'Smart Travel Help',
                onTap: () => Get.toNamed(AppLink.aiAssistant),
              ),
            ];

            if (constraints.maxWidth < 360) {
              return Column(
                children: cards
                    .map((c) => Padding(
                        padding: EdgeInsets.only(bottom: gap), child: c))
                    .toList(),
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(child: cards[i]),
                  ]
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isSmall = w < 400;
    final isTablet = w >= 600;

    final iconSize = isSmall
        ? 24.0
        : isTablet
            ? 32.0
            : 26.0;
    final titleSize = isSmall
        ? 12.0
        : isTablet
            ? 15.0
            : 13.0;
    final subSize = isSmall
        ? 9.0
        : isTablet
            ? 11.0
            : 10.0;
    final pad = isSmall
        ? 14.0
        : isTablet
            ? 20.0
            : 16.0;

    final active = _hovered || _pressed;

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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: iconSize),
                ),
                const SizedBox(height: 9.6),
                Text(widget.title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
                const SizedBox(height: 2),
                Text(widget.subtitle,
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
  }
}
