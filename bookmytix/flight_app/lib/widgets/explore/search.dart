import 'package:flight_app/app/app_link.dart';
import 'package:flutter/material.dart';
import 'package:get/route_manager.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class SearchExplore extends StatelessWidget {
  const SearchExplore({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 80,
        decoration:
            BoxDecoration(color: TravelloTheme.paperLightContainerLowest),
        child: Stack(alignment: Alignment.bottomCenter, children: [
          /// SEARCH BOX
          InkWell(
            onTap: () {
              Get.toNamed(AppLink.searchList);
            },
            child: Container(
                height: 50,
                margin: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    borderRadius: ThemeRadius.medium,
                    color: colorScheme(context).outline),
                child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 8),
                      Text('Search Flights or Packages')
                    ])),
          ),
        ]));
  }
}
