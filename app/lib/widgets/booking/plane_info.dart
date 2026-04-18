import 'package:flight_app/models/plane.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class PlaneInfo extends StatelessWidget {
  const PlaneInfo({super.key, required this.plane});

  final Plane plane;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ClipRRect(
          borderRadius: ThemeRadius.xsmall,
          child: Image.network(
            plane.logo,
            width: 20,
          ),
        ),
        const SizedBox(width: 4,),
        Text(plane.name, style: TravelloTheme.paragraph),
        const Spacer(),
        Text(plane.code, style: TravelloTheme.paragraph),
        const SizedBox(width: 4,),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            borderRadius: ThemeRadius.xsmall,
            color: TravelloTheme.primaryMainContainer
          ),
          child: Text(plane.classType, style: TravelloTheme.caption),
        )
      ]),
    );
  }
}