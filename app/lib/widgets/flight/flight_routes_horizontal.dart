import 'package:flight_app/models/flight_route.dart';
import 'package:flight_app/widgets/cards/flight_route_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class FlightRoutesHorizontal extends StatelessWidget {
  const FlightRoutesHorizontal({
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VSpaceShort(),
          Text(title, style: TravelloTheme.subtitle),
          if (dateLabel != null) Text(dateLabel!, style: TravelloTheme.caption),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: routes.length,
                shrinkWrap: true,
                itemBuilder: ((context, index) {
                  FlightRoute item = routes[index];
                  return SizedBox(
                    width: MediaQuery.of(context).size.width * 0.33,
                    child: FlightRouteCard(
                      airport: item.airport,
                      time: DateFormat.jm().format(item.time),
                      type: item.type,
                    ),
                  );
                })),
          ),
        ],
      ),
    );
  }
}
