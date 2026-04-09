import 'package:flutter/material.dart';
import 'package:flight_app/widgets/cards/paper_card.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TitleIconCard extends StatelessWidget {
  const TitleIconCard({
    super.key,
    required this.icon,
    required this.title,
    this.desc,
    this.flat = false,
    required this.content
  });

  final IconData icon;
  final String title;
  final String? desc;
  final bool flat;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return PaperCard(flat: flat, content: Column(children: [
      ListTile(
        leading: Icon(icon),
        title: Text(title, style: TravelloTheme.title2),
        subtitle: desc != null ? Text(desc!, style: TravelloTheme.paragraph,) : null,
      ),
      const LineList(),
      content
    ]));
  }
}