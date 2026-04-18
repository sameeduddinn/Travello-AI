import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class RoundTripTab extends StatelessWidget {
  const RoundTripTab(
      {super.key, required this.setTabMenu, required this.tabMenuIndex});

  final Function(int) setTabMenu;
  final int tabMenuIndex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(children: [
        Expanded(
            child: InkWell(
          onTap: () {
            setTabMenu(0);
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: spacingUnit(0.75),
            ),
            decoration: BoxDecoration(
              borderRadius: ThemeRadius.medium,
              color: tabMenuIndex == 0
                  ? TravelloTheme.primaryMainContainer
                  : TravelloTheme.paperLightDim,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(FontAwesomeIcons.planeDeparture,
                  size: 24,
                  color: tabMenuIndex == 0
                      ? colorScheme(context).onPrimaryContainer
                      : colorScheme(context).onSurface),
              const SizedBox(width: 16),
              Text('Departure',
                  style: TravelloTheme.subtitle.copyWith(
                      color: tabMenuIndex == 0
                          ? colorScheme(context).onPrimaryContainer
                          : colorScheme(context).onSurface))
            ]),
          ),
        )),
        const SizedBox(
          width: 4,
        ),
        Expanded(
            child: InkWell(
          onTap: () {
            setTabMenu(1);
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: spacingUnit(0.75),
            ),
            decoration: BoxDecoration(
              borderRadius: ThemeRadius.medium,
              color: tabMenuIndex == 1
                  ? TravelloTheme.primaryMainContainer
                  : TravelloTheme.paperLightDim,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(FontAwesomeIcons.planeArrival,
                  size: 24,
                  color: tabMenuIndex == 1
                      ? colorScheme(context).onPrimaryContainer
                      : colorScheme(context).onSurface),
              const SizedBox(width: 16),
              Text('Return',
                  style: TravelloTheme.subtitle.copyWith(
                      color: tabMenuIndex == 1
                          ? colorScheme(context).onPrimaryContainer
                          : colorScheme(context).onSurface))
            ]),
          ),
        ))
      ]),
    );
  }
}
