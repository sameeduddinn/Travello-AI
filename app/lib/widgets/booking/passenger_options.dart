import 'package:flight_app/models/list_item.dart';
import 'package:flight_app/models/booking.dart';

final List<ListItem> passengerOptions = [
  ListItem(
    value: passengerList[0].id,
    label: '${passengerList[0].title} ${passengerList[0].name}',
    text: 'ID Number: ${passengerList[0].idCard}'
  ),
  ListItem(
    value: passengerList[1].id,
    label: '${passengerList[1].title} ${passengerList[1].name}',
    text: 'ID Number: ${passengerList[1].idCard}'
  ),
  ListItem(
    value: passengerList[2].id,
    label: '${passengerList[2].title} ${passengerList[2].name}',
    text: 'ID Number: ${passengerList[2].idCard}'
  ),
  ListItem(
    value: passengerList[3].id,
    label: '${passengerList[3].title} ${passengerList[3].name}',
    text: 'ID Number: ${passengerList[3].idCard}'
  ),
  ListItem(
    value: passengerList[4].id,
    label: '${passengerList[4].title} ${passengerList[4].name}',
    text: 'ID Number: ${passengerList[4].idCard}'
  ),
];