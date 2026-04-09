import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class BackIconButton extends StatelessWidget {
  const BackIconButton({super.key, required this.onTap});

  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      padding: const EdgeInsets.all(12),
      child: IconButton(
        iconSize: 16,
        onPressed: onTap,
        style: ThemeButton.iconBtn(context),
        icon: const Icon(Icons.arrow_back_ios_new)
      ),
    );
  }
}