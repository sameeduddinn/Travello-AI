import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class TitleAction extends StatelessWidget {
  const TitleAction({
    super.key,
    required this.title,
    required this.textAction,
    required this.onTap,
    this.desc,
    this.size = 'default'
  });

  final String title;
  final String? desc;
  final String textAction;
  final String size;
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: size == 'small' ? TravelloTheme.subtitle2 : TravelloTheme.subtitle),
            const SizedBox(height: 4),
            desc != null ? Text(desc!, overflow: TextOverflow.ellipsis,) : Container(),
          ],
        ),
      ),
      const SizedBox(width: 16),
      size == 'small' ? TextButton(
        onPressed: () => {
          onTap()
        },
        style: ThemeButton.btnSmall,
        child: Text(textAction, style: TravelloTheme.paragraph.copyWith(height: 1))
      ) : FilledButton(
        onPressed: () => {
          onTap()
        },
        style: ThemeButton.btnSmall.merge(ThemeButton.tonalPrimary(context)),
        child: Text(textAction, style: TravelloTheme.paragraph.copyWith(height: 1))
      )
    ]);
  }
}

class TitleActionSetting extends StatelessWidget {
  const TitleActionSetting({
    super.key,
    required this.title,
    this.desc,
    required this.textAction,
    required this.onTap
  });

  final String title;
  final String? desc;
  final String textAction;
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TravelloTheme.subtitle),
            const SizedBox(height: 4),
            desc != null ? Text(desc!, overflow: TextOverflow.ellipsis,) : Container(),
          ],
        ),
      ),
      const SizedBox(width: 16),
      TextButton(
        onPressed: () => {
          onTap()
        },
        child: Text(textAction, style: TravelloTheme.paragraph.copyWith(fontWeight: FontWeight.bold, color: TravelloTheme.primaryMain))
      )
    ]);
  }
}