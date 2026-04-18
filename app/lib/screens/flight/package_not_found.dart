import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/utils/no_data.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PackageNotFound extends StatelessWidget {
  const PackageNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Package', style: TravelloTheme.subtitle),
          backgroundColor: Colors.transparent,
          leading: BackIconButton(onTap: () {
            Get.back();
          }),
          centerTitle: true,
        ),
        body: Center(
          child: NoData(
            image: ImgApi.emptyPackage,
            title: 'Package Not Found',
            desc:
                'No packages are available for this route right now. Try exploring a different destination.',
            secondaryAction: () {
              Get.toNamed(AppLink.home);
            },
            secondaryTxtBtn: 'BACK TO HOME',
          ),
        ));
  }
}
