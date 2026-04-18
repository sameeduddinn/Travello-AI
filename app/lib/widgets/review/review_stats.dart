import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ReviewStats extends StatelessWidget {
  const ReviewStats({super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Column(
          children: [
            RichText(
              softWrap: true,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(text: '', style: TextStyle(color: colorScheme.onSurface, fontSize: 16), children: [
                TextSpan(text: '4.5', style: TravelloTheme.title.copyWith(fontWeight: FontWeight.bold)),
                const TextSpan(text: '/5'),
              ])
            ),
            const SizedBox(height: 4),
            const Text('1.234 Ratings', style: TravelloTheme.caption,)
          ],
        ),
        SizedBox(width: spacingUnit(5)),
        Expanded(
          child: Column(children: [
            Row(children: [
              const Text('5'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.star, size: 16, color: colorScheme.onSurfaceVariant)),
              Expanded(
                child: ClipRRect(
                  borderRadius: ThemeRadius.medium,
                  child: LinearProgressIndicator(value: 0.8, backgroundColor: Colors.grey.withValues(alpha: 0.5), semanticsLabel: 'Level progress indicator',)
                ),
              )
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Text('4'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.star, size: 16, color: colorScheme.onSurfaceVariant)),
              Expanded(
                child: ClipRRect(
                  borderRadius: ThemeRadius.medium,
                  child: LinearProgressIndicator(value: 0.4, backgroundColor: Colors.grey.withValues(alpha: 0.5), semanticsLabel: 'Level progress indicator',)
                ),
              )
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Text('3'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.star, size: 16, color: colorScheme.onSurfaceVariant)),
              Expanded(
                child: ClipRRect(
                  borderRadius: ThemeRadius.medium,
                  child: LinearProgressIndicator(value: 0.2, backgroundColor: Colors.grey.withValues(alpha: 0.5), semanticsLabel: 'Level progress indicator',)
                ),
              )
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Text('2'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.star, size: 16, color: colorScheme.onSurfaceVariant)),
              Expanded(
                child: ClipRRect(
                  borderRadius: ThemeRadius.medium,
                  child: LinearProgressIndicator(value: 0, backgroundColor: Colors.grey.withValues(alpha: 0.5), semanticsLabel: 'Level progress indicator',)
                ),
              )
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Text('1'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.star, size: 16, color: colorScheme.onSurfaceVariant)),
              Expanded(
                child: ClipRRect(
                  borderRadius: ThemeRadius.medium,
                  child: LinearProgressIndicator(value: 0.1, backgroundColor: Colors.grey.withValues(alpha: 0.5), semanticsLabel: 'Level progress indicator',)
                ),
              )
            ]),
          ]),
        )
      ]
    );
  }
}