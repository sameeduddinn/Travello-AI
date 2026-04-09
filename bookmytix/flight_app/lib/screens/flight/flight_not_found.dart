import 'package:flight_app/app/app_link.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_text.dart';
import 'package:flight_app/utils/no_data.dart';
import 'package:flight_app/widgets/app_button/back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';

class FlightNotFound extends StatelessWidget {
  const FlightNotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Flight', style: ThemeText.subtitle),
          backgroundColor: Colors.transparent,
          centerTitle: true,
          leading: BackIconButton(onTap: () {
            Get.back();
          }),
        ),
        body: Center(
          child: NoData(
            image: ImgApi.emptyNotFound,
            title: 'Flight Not Found',
            desc:
                'No flights matched your search. Try different dates, routes, or adjust your filters.',
            primaryAction: () {
              Get.toNamed(AppLink.flightList);
            },
            primaryTxtBtn: 'FIND ANOTHER FLIGHT',
            secondaryAction: () {
              Get.toNamed(AppLink.home);
            },
            secondaryTxtBtn: 'BACK TO HOME',
          ),
        ));
  }
}
