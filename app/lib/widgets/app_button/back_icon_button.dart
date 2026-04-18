import 'package:flutter/material.dart';

class BackIconButton extends StatelessWidget {
  const BackIconButton({super.key, required this.onTap, this.isSquare = false});

  final Function() onTap;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double buttonSize = isSquare ? 36 : 34;

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        iconSize: 18,
        padding: EdgeInsets.zero,
        constraints:
            BoxConstraints.tightFor(width: buttonSize, height: buttonSize),
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: Size(buttonSize, buttonSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: colorScheme.surface.withValues(alpha: 0.92),
          foregroundColor: colorScheme.onSurface,
          shape: isSquare
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              : const CircleBorder(),
        ),
        icon: const Icon(Icons.arrow_back_ios_new),
      ),
    );
  }
}
