import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_radius.dart';
import 'package:flight_app/ui/themes/theme_shadow.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class ShadowBorderRadius extends StatelessWidget {
  const ShadowBorderRadius({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Button Collection', style: ThemeText.subtitle,),
        centerTitle: true,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
      ),
      body: ListView(padding: EdgeInsets.all(spacingUnit(2)), children: [
        Container(
          height: 100,
          padding: EdgeInsets.all(spacingUnit(2)),
          decoration: BoxDecoration(
            color: colorScheme(context).primaryContainer,
            boxShadow: [ThemeShade.shadeSoft(context)],
            borderRadius: ThemeRadius.small,
          ),
          child: const Text('Small Radius - Soft Shadow')
        ),
        const VSpace(),
        Container(
          height: 100,
          padding: EdgeInsets.all(spacingUnit(2)),
          decoration: BoxDecoration(
            color: colorScheme(context).primaryContainer,
            boxShadow: [ThemeShade.shadeMedium(context)],
            borderRadius: ThemeRadius.medium,
          ),
          child: const Text('Medium Radius - Medium Shadow')
        ),
        const VSpace(),
        Container(
          height: 100,
          padding: EdgeInsets.all(spacingUnit(2)),
          decoration: BoxDecoration(
            color: colorScheme(context).primaryContainer,
            boxShadow: [ThemeShade.shadeHard(context)],
            borderRadius: ThemeRadius.big,
          ),
          child: const Text('Large Radius - Hard Shadow')
        ),
      ])
    );
  }
}