import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class AppInputBox extends StatelessWidget {
  const AppInputBox({super.key, required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: ThemeRadius.medium,
        border: Border.all(
          width: 1,
          color: Theme.of(context).colorScheme.outline
        )
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: content,
      ),
    );
  }
}