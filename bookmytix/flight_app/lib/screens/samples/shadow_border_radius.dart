import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class ShadowBorderRadius extends StatelessWidget {
  const ShadowBorderRadius({super.key});

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
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          height: 100,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TravelloTheme.primaryMainContainer,
            boxShadow: [ThemeShade.shadeSoft(context)],
            borderRadius: ThemeRadius.small,
          ),
          child: const Text('Small Radius - Soft Shadow')
        ),
        const VSpace(),
        Container(
          height: 100,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TravelloTheme.primaryMainContainer,
            boxShadow: [ThemeShade.shadeMedium(context)],
            borderRadius: ThemeRadius.medium,
          ),
          child: const Text('Medium Radius - Medium Shadow')
        ),
        const VSpace(),
        Container(
          height: 100,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TravelloTheme.primaryMainContainer,
            boxShadow: [ThemeShade.shadeHard(context)],
            borderRadius: ThemeRadius.big,
          ),
          child: const Text('Large Radius - Hard Shadow')
        ),
      ])
    );
  }
}