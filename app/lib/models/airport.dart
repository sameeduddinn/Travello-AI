import 'package:flight_app/constants/image_api.dart';

class Airport {
  final String id;
  final String code;
  final String name;
  final String? photo;
  final String location;

  Airport({
    required this.id,
    required this.code,
    required this.name,
    this.photo,
    required this.location,
  });
}

final List<Airport> airportList = [
  Airport(
      id: '1',
      photo: ImgApi.photo[121],
      code: 'KHI',
      name: 'Jinnah International Airport',
      location: 'Karachi'),
  Airport(
      id: '2',
      photo: ImgApi.photo[122],
      code: 'LHE',
      name: 'Allama Iqbal International Airport',
      location: 'Lahore'),
  Airport(
      id: '3',
      photo: ImgApi.photo[123],
      code: 'ISB',
      name: 'Islamabad International Airport',
      location: 'Islamabad'),
  Airport(
      id: '4',
      photo: ImgApi.photo[124],
      code: 'PEW',
      name: 'Bacha Khan International Airport',
      location: 'Peshawar'),
  Airport(
      id: '5',
      photo: ImgApi.photo[125],
      code: 'MUX',
      name: 'Multan International Airport',
      location: 'Multan'),
  Airport(
      id: '6',
      photo: ImgApi.photo[126],
      code: 'UET',
      name: 'Quetta International Airport',
      location: 'Quetta'),
  Airport(
      id: '7',
      photo: ImgApi.photo[127],
      code: 'LYP',
      name: 'Faisalabad International Airport',
      location: 'Faisalabad'),
  Airport(
      id: '8',
      photo: ImgApi.photo[128],
      code: 'SKT',
      name: 'Sialkot International Airport',
      location: 'Sialkot'),
  Airport(
      id: '9',
      photo: ImgApi.photo[129],
      code: 'SKD',
      name: 'Skardu Airport',
      location: 'Skardu'),
  Airport(
      id: '10',
      photo: ImgApi.photo[130],
      code: 'GIL',
      name: 'Gilgit Airport',
      location: 'Gilgit'),
  Airport(
      id: '11',
      photo: ImgApi.photo[121],
      code: 'SWN',
      name: 'Sukkur Airport',
      location: 'Sukkur'),
  Airport(
      id: '12',
      photo: ImgApi.photo[122],
      code: 'BHV',
      name: 'Bahawalpur Airport',
      location: 'Bahawalpur'),
  Airport(
      id: '13',
      photo: ImgApi.photo[123],
      code: 'RWP',
      name: 'Benazir Bhutto International Airport',
      location: 'Rawalpindi'),
];
