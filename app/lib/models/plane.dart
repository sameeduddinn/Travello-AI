import 'package:flight_app/constants/image_api.dart';

class Plane {
  final String id;
  final String code;
  final String name;
  final String description;
  final String logo;
  final String classType;
  final String? photo;

  Plane(
      {required this.id,
      required this.code,
      required this.name,
      required this.description,
      required this.logo,
      required this.classType,
      this.photo});
}

// ✈️ REALISTIC PAKISTANI DOMESTIC AIRCRAFT
// Used by: PIA, Airblue, SereneAir, AirSial
// Only includes aircraft actually operated on Pakistan domestic routes
final List<Plane> planeList = [
  // PRIMARY ECONOMY AIRCRAFT (Most Common)
  Plane(
    id: '1',
    code: 'A320',
    name: 'Airbus A320',
    classType: 'Economy',
    description:
        'Standard aircraft for Pakistan domestic flights - used by PIA, Airblue, SereneAir, AirSial. Capacity: 150-180 passengers.',
    logo: ImgApi.photo[91],
  ),
  Plane(
    id: '2',
    code: 'B737',
    name: 'Boeing 737-800',
    classType: 'Economy',
    description:
        'Popular narrow-body aircraft for domestic routes - used by PIA, Airblue, SereneAir. Capacity: 150-180 passengers.',
    logo: ImgApi.photo[92],
  ),
  Plane(
    id: '3',
    code: 'ATR72',
    name: 'ATR 72-500',
    classType: 'Economy',
    description:
        'Turboprop for short routes like Islamabad-Gilgit, Karachi-Gwadar - used by PIA, SereneAir. Capacity: 70 passengers.',
    logo: ImgApi.photo[93],
  ),
  Plane(
    id: '4',
    code: 'A320-B',
    name: 'Airbus A320',
    classType: 'Business',
    description:
        'Premium Airbus A320 with business class seating. Most common business class aircraft in Pakistan.',
    logo: ImgApi.photo[94],
  ),
  Plane(
    id: '5',
    code: 'B737-B',
    name: 'Boeing 737',
    classType: 'Business',
    description:
        'Business class configured Boeing 737 for premium domestic travel.',
    logo: ImgApi.photo[95],
  ),
  Plane(
    id: '6',
    code: 'A320-E',
    name: 'Airbus A320',
    classType: 'Economy',
    description:
        'Economy class Airbus A320 - most common aircraft on Karachi-Lahore, Karachi-Islamabad routes.',
    logo: ImgApi.photo[96],
  ),
  Plane(
    id: '7',
    code: 'B737-E',
    name: 'Boeing 737',
    classType: 'Economy',
    description:
        'Economy class Boeing 737 operated by PIA and Airblue on major domestic routes.',
    logo: ImgApi.photo[97],
  ),
  Plane(
    id: '8',
    code: 'ATR72-R',
    name: 'ATR 72',
    classType: 'Economy',
    description:
        'Regional turboprop aircraft perfect for northern areas and coastal routes (Skardu, Chitral, Gwadar).',
    logo: ImgApi.photo[98],
  ),
  Plane(
    id: '9',
    code: 'A320-P',
    name: 'Airbus A320',
    classType: 'First',
    description:
        'Premium economy A320 configuration with extra legroom and amenities.',
    logo: ImgApi.photo[99],
  ),
  Plane(
    id: '10',
    code: 'B737-P',
    name: 'Boeing 737',
    classType: 'First',
    description:
        'Premium economy Boeing 737 with enhanced comfort for longer domestic flights.',
    logo: ImgApi.photo[100],
  )
];
