import 'package:flight_app/constants/image_api.dart';
import 'package:flight_app/ui/themes/theme_breakpoints.dart';
import 'package:flight_app/ui/themes/theme_spacing.dart';
import 'package:flight_app/widgets/title/title_basic.dart';
import 'package:flutter/material.dart';

class PartnersLogo extends StatelessWidget {
  const PartnersLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: spacingUnit(2)),
        child: const TitleBasic(
          title: 'Our Partners',
        ),
      ),
      GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.all(spacingUnit(2)),
        physics: const ClampingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ThemeBreakpoints.smUp(context) ? 6 : 4,
          crossAxisSpacing: ThemeBreakpoints.smUp(context) ? 24 : 16,
          mainAxisSpacing: ThemeBreakpoints.smUp(context) ? 24 : 16,
          childAspectRatio: 1,
        ),
        itemCount: 12, // Replace with the actual number of items
        itemBuilder: (context, index) {
          return Image.network(
            ImgApi.photo[95+index], // Replace with the actual image URL
            fit: BoxFit.contain,
          );
        },
      )
    ],);
  }
}