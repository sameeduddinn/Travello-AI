import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class ColorCollection extends StatelessWidget {
  const ColorCollection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Collection', style: ThemeText.subtitle,),
        centerTitle: true,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
      ),
      body: ListView(padding: EdgeInsets.all(spacingUnit(2)), children: [
        const TitleBasic(title: 'Primary Colors'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.primaryLight,
            child: const Text('Primary Light', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.primaryMain,
            child: const Text('Primary Main', style: TextStyle(color: Colors.white))
          )),
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.primaryDark,
            child: const Text('Primary Dark', style: TextStyle(color: Colors.white))
          )),
        ]),
        const VSpace(),

        const TitleBasic(title: 'Secondary Colors'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.secondaryLight,
            child: const Text('Secondary Light', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.secondaryMain,
            child: const Text('Secondary Main', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.secondaryDark,
            child: const Text('Secondary Dark', style: TextStyle(color: Colors.white))
          )),
        ]),
        const VSpace(),

        const TitleBasic(title: 'Tertiary Colors'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.tertiaryLight,
            child: const Text('Tertiary Light', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.tertiaryMain,
            child: const Text('Tertiary Main', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: ThemePalette.tertiaryDark,
            child: const Text('Tertiary Dark', style: TextStyle(color: Colors.white))
          )),
        ]),
        const VSpace(),

        const TitleBasic(title: 'Gradient Mixed'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: ThemePalette.gradientMixedLight
            ),
            child: const Text('Gradient Light', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: ThemePalette.gradientMixedMain
            ),
            child: const Text('Gradient Main', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: ThemePalette.gradientMixedDark
            ),
            child: const Text('Gradient Dark', style: TextStyle(color: Colors.white))
          )),
        ]),
        const VSpace(),

        const TitleBasic(title: 'Gradient Primary'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: ThemePalette.gradientPrimaryDark
            ),
            child: const Text('Primary Dark', style: TextStyle(color: Colors.white))
          )),
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: ThemePalette.gradientPrimaryLight
            ),
            child: const Text('Primary Light', style: TextStyle(color: Colors.black))
          )),
        ]),
        const VSpace(),

        const TitleBasic(title: 'Gradient Secondary'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: ThemePalette.gradientSecondaryDark
            ),
            child: const Text('Secondary Dark', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: ThemePalette.gradientSecondaryLight
            ),
            child: const Text('Secondary Light', style: TextStyle(color: Colors.black))
          )),
        ]),
        const VSpace(),
      ])
    );
  }
}