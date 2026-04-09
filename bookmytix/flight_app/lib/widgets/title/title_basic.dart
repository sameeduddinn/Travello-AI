import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TitleBasic extends StatelessWidget {
  const TitleBasic({
    super.key,
    required this.title,
    this.desc,
    this.size = 'medium',
  });

  final String title;
  final String size;
  final String? desc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (size == 'medium' ? TravelloTheme.subtitle : TravelloTheme.subtitle2)
              .copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        desc != null
            ? Text(desc!, overflow: TextOverflow.ellipsis)
            : Container(),
      ],
    );
  }
}

class TitleBasicSmall extends StatelessWidget {
  const TitleBasicSmall({super.key, required this.title, this.desc});

  final String title;
  final String? desc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TravelloTheme.headline.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        desc != null ? const SizedBox(height: 4) : Container(),
        desc != null
            ? Text(desc!, overflow: TextOverflow.ellipsis)
            : Container(),
      ],
    );
  }
}

class TitleBasicSeparator extends StatelessWidget {
  const TitleBasicSeparator({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        decoration: BoxDecoration(color: TravelloTheme.paperLightDim),
        child: TitleBasicSmall(title: title));
  }
}
