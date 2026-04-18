import 'package:flight_app/models/airport.dart';
import 'package:flight_app/widgets/cards/flight_route_card.dart';

class FlightRoute {
  final String id;
  final Airport airport;
  final DateTime time;
  final RouteType type;

  FlightRoute({
    required this.id,
    required this.airport,
    required this.time,
    required this.type,
  });
}

final List<FlightRoute> departRoute = [
  FlightRoute(
    id: '1',
    airport: airportList[0],
    time: DateTime.parse('2025-07-21 20:18:00'),
    type: RouteType.depart,
  ),
  FlightRoute(
    id: '2',
    airport: airportList[4],
    time: DateTime.parse('2025-07-21 23:18:00'),
    type: RouteType.transit,
  ),
  FlightRoute(
    id: '3',
    airport: airportList[5],
    time: DateTime.parse('2025-07-22 05:18:00'),
    type: RouteType.arrival,
  ),
];

final List<FlightRoute> returnRoute = [
  FlightRoute(
    id: '1',
    airport: airportList[5],
    time: DateTime.parse('2025-07-29 05:18:00'),
    type: RouteType.arrival,
  ),
  FlightRoute(
    id: '2',
    airport: airportList[0],
    time: DateTime.parse('2025-07-29 20:18:00'),
    type: RouteType.depart,
  ),
];