import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_radius.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';

double getHeight(BuildContext context) {
  if (ThemeBreakpoints.mdUp(context)) {
    return 600;
  } else if (ThemeBreakpoints.smUp(context)) {
    return 400;
  } else if (ThemeBreakpoints.xsUp(context)) {
    return 300;
  } else {
    return 180;
  }
}

class AdsFood extends StatelessWidget {
  const AdsFood({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: spacingUnit(1)),
      width: double.infinity,
      height: getHeight(context),
      decoration: BoxDecoration(
        borderRadius: ThemeRadius.small,
        image: DecorationImage(
          image: NetworkImage(ImgApi.photo[75]),
          fit: BoxFit.cover
        )
      ),
    );
  }
}

class AdsHoliday extends StatelessWidget {
  const AdsHoliday({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: spacingUnit(1)),
      width: double.infinity,
      height: getHeight(context),
      decoration: BoxDecoration(
        borderRadius: ThemeRadius.small,
        image: DecorationImage(
          image: NetworkImage(ImgApi.photo[78]),
          fit: BoxFit.cover
        )
      ),
    );
  }
}