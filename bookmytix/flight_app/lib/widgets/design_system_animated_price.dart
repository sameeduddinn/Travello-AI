import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_text.dart';

/// DSAnimatedPrice
/// Smoothly counts from [oldValue] to [newValue] over [duration].
///
/// Why: On add-ons pages, when the user toggles a seat or meal,
/// the total price ticking upward/downward instead of hard-jumping
/// confirms the system responded — a critical trust signal.
class DSAnimatedPrice extends StatelessWidget {
  const DSAnimatedPrice({
    super.key,
    required this.amount,
    this.currency = 'PKR',
    this.duration = const Duration(milliseconds: 350),
    this.style,
    this.currencyStyle,
  });

  final double amount;
  final String currency;
  final Duration duration;
  final TextStyle? style;
  final TextStyle? currencyStyle;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: amount),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, _) {
        final formatted = _formatAmount(value);
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$currency ',
              style: currencyStyle ??
                  ThemeText.caption.copyWith(
                    color: ThemePalette.primaryMain,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
            Text(
              formatted,
              style: style ??
                  ThemeText.title2.copyWith(
                    color: ThemePalette.primaryMain,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
            ),
          ],
        );
      },
    );
  }

  String _formatAmount(double v) {
    // Format with comma separators, no decimals for PKR
    final rounded = v.round();
    final s = rounded.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}
