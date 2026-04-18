import 'package:flight_app/models/airport.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

enum RouteType {
  depart, arrival, transit
}

class FlightRouteCard extends StatelessWidget {
  const FlightRouteCard({
    super.key,
    this.airport,
    required this.time,
    required this.type,
    this.mini = false
  });

  final Airport? airport;
  final String time;
  final RouteType type;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    IconData iconType(type) {
      switch(type) {
        case RouteType.depart:
          return CupertinoIcons.airplane;
        case RouteType.arrival:
          return CupertinoIcons.location_solid;
        default:
          return CupertinoIcons.building_2_fill;
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.only(
        left: mini ? 20 : 16,
        bottom: 8
      ),
      leading: Container(
        width: mini ? 10: 20,
        height: mini ? 10 : 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TravelloTheme.primaryMain,
          border: Border.all(
            width: mini ? 2 : 4,
            color: TravelloTheme.paperLight
          )
        ),
      ),
      title: Row(
        children: [
          Icon(iconType(type), size: 16),
          const SizedBox(width: 4),
          Text(time, style: TravelloTheme.headline),
        ],
      ),
      subtitle: airport != null ? Text(
        '${airport!.location} - ${airport!.name} (${airport!.code})',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TravelloTheme.paragraph
      ) : Container(),
    );
  }
}