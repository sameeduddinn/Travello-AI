import 'package:flutter/material.dart';

class BackIconButton extends StatelessWidget {
  const BackIconButton({super.key, required this.onTap, this.isSquare = false});

  final Function() onTap;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        iconSize: 12,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: const Size(28, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: colorScheme.surface.withValues(alpha: 0.85),
          foregroundColor: colorScheme.onSurface,
          shape: isSquare
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))
              : const CircleBorder(),
        ),
        icon: const Icon(Icons.arrow_back_ios_new),
      ),
    );
  }
}
