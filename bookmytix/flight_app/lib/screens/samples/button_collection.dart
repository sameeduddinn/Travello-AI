import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ButtonCollection extends StatelessWidget {
  const ButtonCollection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Button Collection', style: TravelloTheme.subtitle,),
        centerTitle: true,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TitleBasic(title: 'Filled Button'),
          Wrap(runSpacing: 8, children: [
            FilledButton(
              onPressed: () {},
              style: ThemeButton.primary,
              child: const Text('Button Primary'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.secondary,
              child: const Text('Button Secondary'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.tertiary,
              child: const Text('Button Tertiary'),
            ),
          ],),

          const VSpace(),

          const TitleBasic(title: 'Basic Filled Button'),
          Wrap(runSpacing: 8, children: [
            FilledButton(
              onPressed: () {},
              style: ThemeButton.black,
              child: const Text('Button Black'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.white,
              child: const Text('Button White'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.invert(context),
              child: const Text('Button Invert'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.invert2(context),
              child: const Text('Button Invert v2'),
            ),
          ],),

          const VSpace(),

          const TitleBasic(title: 'Outlined Button'),
          Wrap(runSpacing: 8, children: [
            OutlinedButton(
              onPressed: () {},
              style: ThemeButton.outlinedPrimary(context),
              child: const Text('Button Primary'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: ThemeButton.outlinedSecondary(context),
              child: const Text('Button Secondary'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: ThemeButton.outlinedTertiary(context),
              child: const Text('Button Tertiary'),
            ),
          ]),

          const VSpace(),

          const TitleBasic(title: 'Outlined Basic Button'),
          Wrap(runSpacing: 8, children: [
            OutlinedButton(
              onPressed: () {},
              style: ThemeButton.outlinedBlack(),
              child: const Text('Button Black'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: ThemeButton.outlinedWhite(),
              child: const Text('Button White'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: ThemeButton.outlinedInvert(context),
              child: const Text('Button Invert'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: ThemeButton.outlinedInvert2(context),
              child: const Text('Button Invert2'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: ThemeButton.outlinedDefault(context),
              child: const Text('Button Default'),
            ),
          ]),
          const VSpace(),

          const TitleBasic(title: 'Tonal Button'),
          Wrap(runSpacing: 8, children: [
            FilledButton(
              onPressed: () {},
              style: ThemeButton.tonalPrimary(context),
              child: const Text('Button Primary'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.tonalSecondary(context),
              child: const Text('Button Secondary'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.tonalTertiary(context),
              child: const Text('Button Tertiary'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.tonalDefault(context),
              child: const Text('Button Default'),
            ),
          ]),

          const VSpace(),

          const TitleBasic(title: 'Text Button'),
          Wrap(runSpacing: 8, children: [
            TextButton(
              onPressed: () {},
              style: ThemeButton.textPrimary(context),
              child: const Text('Button Primary'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {},
              style: ThemeButton.textSecondary(context),
              child: const Text('Button Secondary'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {},
              style: ThemeButton.textTertiary(context),
              child: const Text('Button Tertiary'),
            ),
            const SizedBox(width: 8),
          ]),

          const VSpace(),

          const TitleBasic(title: 'Button Size'),
          Wrap(runSpacing: 8, children: [
            FilledButton(
              onPressed: () {},
              style: ThemeButton.btnSmall.merge(ThemeButton.tonalPrimary(context)),
              child: const Text('Button Small', style: TravelloTheme.caption,),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.tonalPrimary(context),
              child: const Text('Button Medium', style: TravelloTheme.paragraph,),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {},
              style: ThemeButton.btnBig.merge(ThemeButton.tonalPrimary(context)),
              child: const Text('Button Large', style: TravelloTheme.paragraph,),
            ),
          ]),
          const VSpaceBig()
        ],
      )
    );
  }
}