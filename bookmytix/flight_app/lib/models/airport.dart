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
    code: 'UET',
    name: 'Quetta International Airport',
    location: 'Quetta',
  ),
  Airport(
      id: '6',
      photo: ImgApi.photo[126],
      code: 'MUX',
      name: 'Multan International Airport',
      location: 'Multan'),
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
      code: 'RYK',
      name: 'Shaikh Zayed International Airport',
      location: 'Rahim Yar Khan'),
  Airport(
      id: '10',
      photo: ImgApi.photo[130],
      code: 'SKZ',
      name: 'Sukkur Airport',
      location: 'Sukkur'),
  Airport(
      id: '11',
      photo: ImgApi.photo[121],
      code: 'BHV',
      name: 'Bahawalpur Airport',
      location: 'Bahawalpur'),
  Airport(
      id: '12',
      photo: ImgApi.photo[122],
      code: 'GWD',
      name: 'Gwadar International Airport',
      location: 'Gwadar'),
  Airport(
      id: '13',
      photo: ImgApi.photo[123],
      code: 'HDD',
      name: 'Hyderabad Airport',
      location: 'Hyderabad'),
  Airport(
      id: '14',
      photo: ImgApi.photo[124],
      code: 'SGI',
      name: 'Sargodha Airport',
      location: 'Sargodha'),
  Airport(
    id: '15',
    photo: ImgApi.photo[125],
    code: 'GIL',
    name: 'Gilgit Airport',
    location: 'Gilgit',
  ),
  Airport(
      id: '16',
      photo: ImgApi.photo[126],
      code: 'SKD',
      name: 'Skardu Airport',
      location: 'Skardu'),
  Airport(
      id: '17',
      photo: ImgApi.photo[127],
      code: 'DBA',
      name: 'D.I. Khan Airport',
      location: 'Dera Ismail Khan'),
  Airport(
      id: '18',
      photo: ImgApi.photo[128],
      code: 'SBQ',
      name: 'Sibi Airport',
      location: 'Sibi'),
  Airport(
      id: '19',
      photo: ImgApi.photo[129],
      code: 'JAG',
      name: 'Jacobabad Airport',
      location: 'Jacobabad'),
  Airport(
      id: '20',
      photo: ImgApi.photo[130],
      code: 'TFT',
      name: 'Turbat Airport',
      location: 'Turbat'),
  Airport(
      id: '21',
      photo: ImgApi.photo[121],
      code: 'PAJ',
      name: 'Parachinar Airport',
      location: 'Parachinar'),
  Airport(
      id: '22',
      photo: ImgApi.photo[122],
      code: 'KDU',
      name: 'Skardu Airport',
      location: 'Skardu'),
  Airport(
      id: '23',
      photo: ImgApi.photo[123],
      code: 'WNS',
      name: 'Nawabshah Airport',
      location: 'Nawabshah'),
  Airport(
      id: '24',
      photo: ImgApi.photo[124],
      code: 'ZHB',
      name: 'Zhob Airport',
      location: 'Zhob'),
  Airport(
      id: '25',
      photo: ImgApi.photo[125],
      code: 'CJL',
      name: 'Chitral Airport',
      location: 'Chitral'),
  Airport(
      id: '26',
      photo: ImgApi.photo[126],
      code: 'BNP',
      name: 'Bannu Airport',
      location: 'Bannu'),
  Airport(
      id: '27',
      photo: ImgApi.photo[127],
      code: 'KDD',
      name: 'Khuzdar Airport',
      location: 'Khuzdar'),
  Airport(
      id: '28',
      photo: ImgApi.photo[128],
      code: 'MWD',
      name: 'Mianwali Airport',
      location: 'Mianwali'),
  Airport(
      id: '29',
      photo: ImgApi.photo[129],
      code: 'RAZ',
      name: 'Rawalakot Airport',
      location: 'Rawalakot'),
  Airport(
      id: '30',
      photo: ImgApi.photo[130],
      code: 'REQ',
      name: 'Reko Diq Airport',
      location: 'Reko Diq')
];
