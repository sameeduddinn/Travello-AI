import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ColorCollection extends StatelessWidget {
  const ColorCollection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Collection', style: TravelloTheme.subtitle,),
        centerTitle: true,
        leading: BackIconButton(onTap: () {
          Get.back();
        }),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const TitleBasic(title: 'Primary Colors'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.primaryLight,
            child: const Text('Primary Light', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.primaryMain,
            child: const Text('Primary Main', style: TextStyle(color: Colors.white))
          )),
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.primaryDark,
            child: const Text('Primary Dark', style: TextStyle(color: Colors.white))
          )),
        ]),
        const VSpace(),

        const TitleBasic(title: 'Secondary Colors'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.secondaryLight,
            child: const Text('Secondary Light', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.secondaryMain,
            child: const Text('Secondary Main', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.secondaryDark,
            child: const Text('Secondary Dark', style: TextStyle(color: Colors.white))
          )),
        ]),
        const VSpace(),

        const TitleBasic(title: 'Tertiary Colors'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.tertiaryLight,
            child: const Text('Tertiary Light', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.tertiaryMain,
            child: const Text('Tertiary Main', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            color: TravelloTheme.tertiaryDark,
            child: const Text('Tertiary Dark', style: TextStyle(color: Colors.white))
          )),
        ]),
        const VSpace(),

        const TitleBasic(title: 'Gradient Mixed'),
        Row(children: [
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: TravelloTheme.gradientMixedLight
            ),
            child: const Text('Gradient Light', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: TravelloTheme.gradientMixedMain
            ),
            child: const Text('Gradient Main', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: TravelloTheme.gradientMixedDark
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
              gradient: TravelloTheme.gradientPrimaryDark
            ),
            child: const Text('Primary Dark', style: TextStyle(color: Colors.white))
          )),
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: TravelloTheme.gradientPrimaryLight
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
              gradient: TravelloTheme.gradientSecondaryDark
            ),
            child: const Text('Secondary Dark', style: TextStyle(color: Colors.black))
          )),
          Expanded(child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: TravelloTheme.gradientSecondaryLight
            ),
            child: const Text('Secondary Light', style: TextStyle(color: Colors.black))
          )),
        ]),
        const VSpace(),
      ])
    );
  }
}