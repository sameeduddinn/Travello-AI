import 'package:flight_app/models/flight_route.dart';
import 'package:flight_app/widgets/cards/flight_route_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightRoutes extends StatelessWidget {
  const FlightRoutes({
    super.key,
    required this.title,
    required this.routes,
    this.dateLabel,
  });

  final String title;
  final List<FlightRoute> routes;
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    const double itemHeight = 52;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSpaceShort(),
          Text(title, style: TravelloTheme.subtitle2),
          if (dateLabel != null)
            Text(dateLabel!,
                style: TravelloTheme.caption
                    .copyWith(color: colorScheme(context).onSurfaceVariant)),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: 24,
                child: Container(
                    width: 3,
                    height: itemHeight * 5,
                    decoration: BoxDecoration(
                        color: colorScheme(context).outline,
                        borderRadius: BorderRadius.circular(5))),
              ),
              ListView.builder(
                  itemCount: routes.length,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  itemBuilder: ((context, index) {
                    FlightRoute item = routes[index];
                    return FlightRouteCard(
                      airport: item.airport,
                      time: DateFormat.jm().format(item.time),
                      type: item.type,
                      mini: item.type == RouteType.transit,
                    );
                  }))
            ],
          ),
        ],
      ),
    );
  }
}
