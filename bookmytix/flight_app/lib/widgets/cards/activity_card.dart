import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
  });

  final String title;
  final String time;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(
        left: 16,
      ),
      leading: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            width: 4,
            color: TravelloTheme.paperLight
          )
        ),
      ),
      title: Text(time, style: TravelloTheme.caption.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,  style: TravelloTheme.headline.copyWith(color: isHighlighted ? Colors.orange : colorScheme(context).onSurface)),
        ],
      ),
    );
  }
}