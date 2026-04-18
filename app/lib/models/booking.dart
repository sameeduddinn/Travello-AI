import 'package:flight_app/models/city.dart';
import 'package:flight_app/models/plane.dart';
import 'package:flight_app/models/user.dart';

final List<String> bookingSteps = ['Passenggers', 'Facilities', 'Checkout', 'Payment', 'Done'];

final List<User> passengerList = [
  userList[0].copyWith(baggage: 20, seat: 'A1', type: 'adult'),
  userList[1].copyWith(baggage: 20, seat: 'A2', type: 'adult'),
  userList[2].copyWith(baggage: 20, seat: 'A3', type: 'adult'),
  userList[3].copyWith(baggage: 20, seat: 'A4', type: 'elderly'),
  userList[4].copyWith(baggage: 20, seat: 'A5', type: 'adult'),
];

enum BookStatus {waiting, active, done, canceled}

class Booking {
  final String id;
  final DateTime dateOrder;
  final City from;
  final City to;
  final Plane plane;
  final double price;
  final DateTime depart;
  final DateTime arrival;
  final List<String>? facilities;
  final List<User> passengers;
  final BookStatus status;

  Booking({
    required this.id,
    required this.dateOrder,
    required this.from,
    required this.to,
    required this.plane,
    required this.price,
    required this.depart,
    required this.arrival,
    this.facilities,
    required this.passengers,
    required this.status
  });
}

final List<Booking> bookingList = [
  Booking(
    id: '1',
    dateOrder: DateTime.parse('2025-06-20 20:18:00'),
    from: cityList[1],
    to: cityList[2],
    plane: planeList[1],
    price: 800,
    depart: DateTime.parse('2025-07-20 20:18:00'),
    arrival: DateTime.parse('2025-07-21 20:18:00'),
    passengers: [passengerList[0], passengerList[1]],
    status: BookStatus.active
  ),
  Booking(
    id: '2',
    dateOrder: DateTime.parse('2025-06-20 20:18:00'),
    from: cityList[2],
    to: cityList[5],
    plane: planeList[1],
    price: 800,
    depart: DateTime.parse('2025-07-20 20:18:00'),
    arrival: DateTime.parse('2025-07-21 20:18:00'),
    passengers: [passengerList[0]],
    status: BookStatus.waiting
  ),
  Booking(
    id: '3',
    dateOrder: DateTime.parse('2025-06-20 20:18:00'),
    from: cityList[3],
    to: cityList[4],
    plane: planeList[1],
    price: 800,
    depart: DateTime.parse('2025-07-20 20:18:00'),
    arrival: DateTime.parse('2025-07-21 20:18:00'),
    passengers: [passengerList[0]],
    status: BookStatus.done
  ),
  Booking(
    id: '4',
    dateOrder: DateTime.parse('2025-06-20 20:18:00'),
    from: cityList[4],
    to: cityList[6],
    plane: planeList[1],
    price: 800,
    depart: DateTime.parse('2025-07-20 20:18:00'),
    arrival: DateTime.parse('2025-07-21 20:18:00'),
    passengers: [passengerList[0], passengerList[1], passengerList[4]],
    status: BookStatus.done
  ),
];