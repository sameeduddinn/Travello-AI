import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_palette.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/widgets/decorations/rounded_deco_main.dart';
import 'package:flutter/material.dart';

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 450,
          width: MediaQuery.of(context).size.width,
          alignment: Alignment.center,
          padding: EdgeInsets.all(spacingUnit(3)),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(ImgApi.homeBanner),
              alignment: const Alignment(0, -0.3),
              fit: BoxFit.cover,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Text(
              'Where do you want to go?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Positioned(
            bottom: 0,
            left: 0,
            child: RoundedDecoMain(
              height: 70,
              bgDecoration: BoxDecoration(
                color: colorScheme(context).surfaceContainerLowest,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme(context).surfaceContainerLowest,
                    blurRadius: 0.0,
                    spreadRadius: 0.0,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
            )),
      ],
    );
  }
}
