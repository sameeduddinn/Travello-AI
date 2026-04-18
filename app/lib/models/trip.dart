import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';

class Trip {
  final String id;
  final City from;
  final City to;
  final Plane plane;
  final double price;
  final double discount;
  final String label;
  final bool hasRefund;
  final bool roundTrip;
  final List<String>? tags;
  final DateTime depart;
  final DateTime arrival;
  final List<String>? facilities;
  final int transit;

  Trip({
    required this.id,
    required this.from,
    required this.to,
    required this.plane,
    required this.price,
    this.discount = 0,
    this.label = '',
    this.hasRefund = true,
    this.roundTrip = false,
    this.tags,
    required this.depart,
    required this.arrival,
    this.facilities,
    this.transit = 0
  });
}

final List<Trip> tripList = [
  Trip(
    id: '1',
    from: cityList[1],
    to: cityList[2],
    plane: planeList[1],
    price: 200,
    discount: 5,
    label: '5% OFF',
    depart: DateTime.parse('2025-07-20 20:18:00'),
    arrival: DateTime.parse('2025-07-21 20:18:00'),
  ),
  Trip(
    id: '2',
    from: cityList[2],
    to: cityList[5],
    plane: planeList[1],
    price: 800,
    discount: 30,
    label: '30% OFF',
    depart: DateTime.parse('2025-07-20 11:18:00'),
    arrival: DateTime.parse('2025-07-21 20:18:00'),
    roundTrip: true,
    transit: 2
  ),
  Trip(
    id: '3',
    from: cityList[3],
    to: cityList[4],
    plane: planeList[1],
    price: 1000,
    discount: 50,
    label: 'Best Value',
    depart: DateTime.parse('2025-07-20 12:18:00'),
    arrival: DateTime.parse('2025-07-21 02:18:00'),
  ),
  Trip(
    id: '4',
    from: cityList[4],
    to: cityList[6],
    plane: planeList[1],
    price: 350,
    discount: 10,
    label: '10% OFF',
    depart: DateTime.parse('2025-07-20 19:18:00'),
    arrival: DateTime.parse('2025-07-21 07:18:00'),
    transit: 1
  ),
  Trip(
    id: '5',
    from: cityList[1],
    to: cityList[2],
    plane: planeList[1],
    price: 450,
    discount: 10,
    label: '10% OFF',
    depart: DateTime.parse('2025-07-20 22:18:00'),
    arrival: DateTime.parse('2025-07-21 15:18:00'),
    roundTrip: true,
  ),
  Trip(
    id: '6',
    from: cityList[6],
    to: cityList[7],
    plane: planeList[1],
    price: 300,
    discount: 20,
    label: '20% OFF',
    depart: DateTime.parse('2025-07-20 13:18:00'),
    arrival: DateTime.parse('2025-07-21 01:18:00'),
  ),
  Trip(
    id: '7',
    from: cityList[7],
    to: cityList[8],
    plane: planeList[1],
    price: 100,
    discount: 1,
    label: '1% OFF',
    depart: DateTime.parse('2025-07-20 04:18:00'),
    arrival: DateTime.parse('2025-07-21 04:18:00'),
    roundTrip: true,
  ),
  Trip(
    id: '8',
    from: cityList[8],
    to: cityList[10],
    plane: planeList[2],
    price: 800,
    discount: 40,
    label: 'Best Price',
    depart: DateTime.parse('2025-07-20 07:18:00'),
    arrival: DateTime.parse('2025-07-21 01:18:00'),
    transit: 1
  ),
  Trip(
    id: '9',
    from: cityList[9],
    to: cityList[12],
    plane: planeList[2],
    price: 800,
    discount: 5,
    label: '5% OFF',
    depart: DateTime.parse('2025-07-20 10:18:00'),
    arrival: DateTime.parse('2025-07-21 11:18:00'),
    transit: 3
  ),
  Trip(
    id: '10',
    from: cityList[10],
    to: cityList[11],
    plane: planeList[3],
    price: 130,
    discount: 12,
    label: '12% OFF',
    depart: DateTime.parse('2025-07-20 22:18:00'),
    arrival: DateTime.parse('2025-07-21 00:18:00'),
    transit: 2
  ),
  Trip(
    id: '11',
    from: cityList[11],
    to: cityList[12],
    plane: planeList[3],
    price: 200,
    discount: 10,
    label: '10% OFF',
    depart: DateTime.parse('2025-07-20 23:18:00'),
    arrival: DateTime.parse('2025-07-21 05:18:00'),
    roundTrip: true,
  ),
  Trip(
    id: '12',
    from: cityList[12],
    to: cityList[15],
    plane: planeList[3],
    price: 750,
    discount: 5,
    label: '5% OFF',
    depart: DateTime.parse('2025-07-20 08:18:00'),
    arrival: DateTime.parse('2025-07-21 01:18:00'),
    transit: 1
  ),
  Trip(
    id: '13',
    from: cityList[13],
    to: cityList[14],
    plane: planeList[4],
    price: 240,
    discount: 10,
    label: '10% OFF',
    depart: DateTime.parse('2025-07-20 14:18:00'),
    arrival: DateTime.parse('2025-07-21 10:18:00'),
  ),
  Trip(
    id: '14',
    from: cityList[14],
    to: cityList[15],
    plane: planeList[5],
    price: 250,
    discount: 25,
    label: '25% OFF',
    depart: DateTime.parse('2025-07-20 15:18:00'),
    arrival: DateTime.parse('2025-07-21 15:18:00'),
    roundTrip: true,
  ),
  Trip(
    id: '15',
    from: cityList[15],
    to: cityList[16],
    plane: planeList[5],
    price: 600,
    discount: 1,
    label: '1% OFF',
    depart: DateTime.parse('2025-07-20 17:18:00'),
    arrival: DateTime.parse('2025-07-21 02:18:00'),
  ),
  Trip(
    id: '16',
    from: cityList[16],
    to: cityList[18],
    plane: planeList[5],
    price: 350,
    discount: 5,
    label: '5% OFF',
    depart: DateTime.parse('2025-07-20 18:18:00'),
    arrival: DateTime.parse('2025-07-21 05:18:00'),
    transit: 1
  ),
  Trip(
    id: '17',
    from: cityList[17],
    to: cityList[18],
    plane: planeList[6],
    price: 500,
    discount: 75,
    label: 'Best Value',
    depart: DateTime.parse('2025-07-20 20:18:00'),
    arrival: DateTime.parse('2025-07-21 20:18:00'),
  ),
  Trip(
    id: '18',
    from: cityList[18],
    to: cityList[19],
    plane: planeList[6],
    price: 400,
    discount: 10,
    label: '10% OFF',
    depart: DateTime.parse('2025-07-20 21:18:00'),
    arrival: DateTime.parse('2025-07-21 10:18:00'),
    roundTrip: true,
  ),
  Trip(
    id: '19',
    from: cityList[20],
    to: cityList[22],
    plane: planeList[7],
    price: 500,
    discount: 20,
    label: '20% OFF',
    depart: DateTime.parse('2025-07-20 18:18:00'),
    arrival: DateTime.parse('2025-07-21 07:18:00'),
    transit: 1
  ),
  Trip(
    id: '20',
    from: cityList[20],
    to: cityList[24],
    plane: planeList[9],
    price: 650,
    discount: 15,
    label: '15% OFF',
    depart: DateTime.parse('2025-07-20 15:18:00'),
    arrival: DateTime.parse('2025-07-21 02:18:00'),
    roundTrip: true,
    transit: 1
  )
];