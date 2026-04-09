import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PointCard extends StatelessWidget {
  const PointCard({
    super.key,
    required this.color,
    required this.title,
    required this.btnText,
    required this.progress,
    this.max = 100,
    this.onTap,
    this.label = ''
  });

  final Color color;
  final String title;
  final String btnText;
  final double progress;
  final double max;
  final Function()? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: ThemeRadius.medium,
        boxShadow: [ThemeShade.shadeSoft(context)],
        color: TravelloTheme.paperLight
      ),
      child: Column(
        children: [
          /// PROPERTIES
          Row(
            children: [
              /// TEXT
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Icon(Icons.stars, color: color, size: 26),
                    const SizedBox(width: 4),
                    Text('$progress$label', style: TravelloTheme.title.copyWith(height: 1)),
                    Text(' / $max$label', style: TravelloTheme.subtitle2),
                  ])
                ]),
              ),
              /// BUTTON
              OutlinedButton(
                onPressed: onTap,
                style: ThemeButton.outlinedInvert(context),
                child: Text(btnText, style: TravelloTheme.subtitle2),
              )
            ],
          ),
          const SizedBox(height: 8,),
          ClipRRect(
            borderRadius: ThemeRadius.small,
            child: LinearProgressIndicator(
              value: progress / max,
              backgroundColor: TravelloTheme.paperLightDim,
              color: color,
              minHeight: 10,
              semanticsLabel: 'Progress indicator',
            ),
          ),
        ],
      ),
    );
  }
}