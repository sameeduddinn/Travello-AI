import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.content,
    this.coloured = false,
    this.colouredBorder = false,
    this.flat = false,
  });

  final Widget content;
  final bool coloured;
  final bool colouredBorder;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: coloured ? TravelloTheme.primaryMain : Theme.of(context).colorScheme.surface,
        borderRadius: ThemeRadius.medium,
        boxShadow: !flat ? [ThemeShade.shadeSoft(context)] : null,
        border: flat ? Border.all(
          width: 1,
          color: colouredBorder ? TravelloTheme.primaryMain : Theme.of(context).colorScheme.outline
        ) : null
      ),
      child: content
    );
  }
}