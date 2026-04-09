import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ButtonTab extends StatelessWidget {
  const ButtonTab({super.key, required this.isSelected, required this.text, required this.onSelect});

  final bool isSelected;
  final String text;
  final Function() onSelect;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        onSelect();
      },
      style: FilledButton.styleFrom(
        backgroundColor: isSelected ? TravelloTheme.primaryMainContainer : Colors.transparent,
        foregroundColor: isSelected ? colorScheme(context).onPrimaryContainer : colorScheme(context).onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: ThemeRadius.medium
        )
      ),
      child: Text(text, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold),),
    );
  }
}