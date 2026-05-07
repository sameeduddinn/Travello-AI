import 'package:flutter/material.dart';

class Hospital {
  final String id;
  final String name;
  final String city;
  final String address;
  final String phone;
  final String type;
  final bool hasEmergency;
  final double distance; // in km
  final double? lat;
  final double? lng;
  final String? mapsUrl;
  final double? rating;
  final int? ratingCount;

  Hospital({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.phone,
    required this.type,
    required this.hasEmergency,
    required this.distance,
    this.lat,
    this.lng,
    this.mapsUrl,
    this.rating,
    this.ratingCount,
  });
}

// Dummy Hospital Data for Pakistan
class PakistanHospitals {
  static List<Hospital> getHospitalsByCity(String city) {
    final allHospitals = getAllHospitals();
    return allHospitals.where((h) => h.city == city).toList();
  }

  static List<Hospital> getAllHospitals() {
    return [
      // Karachi
      Hospital(
        id: '1',
        name: 'Aga Khan University Hospital',
        city: 'Karachi',
        address: 'Stadium Road, Karachi',
        phone: '021-34864000',
        type: 'Multi-Specialty',
        hasEmergency: true,
        distance: 2.5,
      ),
      Hospital(
        id: '2',
        name: 'Jinnah Postgraduate Medical Centre',
        city: 'Karachi',
        address: 'Rafiqui Shaheed Road, Karachi',
        phone: '021-99201300',
        type: 'Government',
        hasEmergency: true,
        distance: 3.8,
      ),
      Hospital(
        id: '3',
        name: 'Liaquat National Hospital',
        city: 'Karachi',
        address: 'Stadium Road, Karachi',
        phone: '021-111-456-456',
        type: 'Multi-Specialty',
        hasEmergency: true,
        distance: 2.1,
      ),

      // Lahore
      Hospital(
        id: '4',
        name: 'Shaukat Khanum Memorial Cancer Hospital',
        city: 'Lahore',
        address: '7-A Block R-3, Johar Town, Lahore',
        phone: '042-35905000',
        type: 'Cancer Specialty',
        hasEmergency: true,
        distance: 4.2,
      ),
      Hospital(
        id: '5',
        name: 'Services Hospital',
        city: 'Lahore',
        address: 'Jail Road, Lahore',
        phone: '042-99213274',
        type: 'Government',
        hasEmergency: true,
        distance: 3.5,
      ),
      Hospital(
        id: '6',
        name: 'Hameed Latif Hospital',
        city: 'Lahore',
        address: '14 Abu Baker Block, Garden Town, Lahore',
        phone: '042-35713333',
        type: 'Multi-Specialty',
        hasEmergency: true,
        distance: 2.9,
      ),

      // Islamabad
      Hospital(
        id: '7',
        name: 'Shifa International Hospital',
        city: 'Islamabad',
        address: 'H-8/4, Islamabad',
        phone: '051-8463000',
        type: 'Multi-Specialty',
        hasEmergency: true,
        distance: 5.1,
      ),
      Hospital(
        id: '8',
        name: 'Pakistan Institute of Medical Sciences (PIMS)',
        city: 'Islamabad',
        address: 'G-8/3, Islamabad',
        phone: '051-9261170',
        type: 'Government',
        hasEmergency: true,
        distance: 4.6,
      ),
      Hospital(
        id: '9',
        name: 'Quaid-e-Azam International Hospital',
        city: 'Islamabad',
        address: 'G-10/4, Islamabad',
        phone: '051-9253901',
        type: 'Multi-Specialty',
        hasEmergency: true,
        distance: 3.8,
      ),

      // Rawalpindi
      Hospital(
        id: '10',
        name: 'Fauji Foundation Hospital',
        city: 'Rawalpindi',
        address: 'Peshawar Road, Rawalpindi',
        phone: '051-9271011',
        type: 'Multi-Specialty',
        hasEmergency: true,
        distance: 2.3,
      ),
      Hospital(
        id: '11',
        name: 'Combined Military Hospital (CMH)',
        city: 'Rawalpindi',
        address: 'Mall Road, Rawalpindi Cantt',
        phone: '051-9270614',
        type: 'Military Hospital',
        hasEmergency: true,
        distance: 3.2,
      ),

      // Multan
      Hospital(
        id: '12',
        name: 'Nishtar Medical University Hospital',
        city: 'Multan',
        address: 'Nishtar Road, Multan',
        phone: '061-9200260',
        type: 'Government',
        hasEmergency: true,
        distance: 1.8,
      ),

      // Faisalabad
      Hospital(
        id: '13',
        name: 'Allied Hospital',
        city: 'Faisalabad',
        address: 'Sargodha Road, Faisalabad',
        phone: '041-9201100',
        type: 'Government',
        hasEmergency: true,
        distance: 2.5,
      ),

      // Peshawar
      Hospital(
        id: '14',
        name: 'Hayatabad Medical Complex',
        city: 'Peshawar',
        address: 'Phase 5, Hayatabad, Peshawar',
        phone: '091-9217140',
        type: 'Government',
        hasEmergency: true,
        distance: 6.2,
      ),
      Hospital(
        id: '15',
        name: 'Khyber Teaching Hospital',
        city: 'Peshawar',
        address: 'Jamrud Road, Peshawar',
        phone: '091-9211463',
        type: 'Government',
        hasEmergency: true,
        distance: 3.9,
      ),

      // Quetta
      Hospital(
        id: '16',
        name: 'Bolan Medical Complex Hospital',
        city: 'Quetta',
        address: 'Brewery Road, Quetta',
        phone: '081-9202624',
        type: 'Government',
        hasEmergency: true,
        distance: 2.7,
      ),
      Hospital(
        id: '17',
        name: 'Civil Hospital Quetta',
        city: 'Quetta',
        address: 'Mission Road, Quetta',
        phone: '081-9201290',
        type: 'Government',
        hasEmergency: true,
        distance: 3.1,
        lat: 30.1857,
        lng: 66.9923,
      ),

      // Skardu
      Hospital(
        id: '18',
        name: 'CMH Skardu',
        city: 'Skardu',
        address: 'Airport Road, Skardu',
        phone: '058-9270255',
        type: 'Military Hospital',
        hasEmergency: true,
        distance: 1.4,
        lat: 35.2955,
        lng: 75.6324,
      ),
      Hospital(
        id: '19',
        name: 'DHQ Hospital Skardu',
        city: 'Skardu',
        address: 'Yadgar Chowk, Skardu',
        phone: '058-9270100',
        type: 'Government',
        hasEmergency: true,
        distance: 2.1,
        lat: 35.2941,
        lng: 75.6307,
      ),

      // Gilgit
      Hospital(
        id: '20',
        name: 'DHQ Hospital Gilgit',
        city: 'Gilgit',
        address: 'Hospital Road, Gilgit',
        phone: '058-1920100',
        type: 'Government',
        hasEmergency: true,
        distance: 1.2,
        lat: 35.9219,
        lng: 74.3099,
      ),
      Hospital(
        id: '21',
        name: 'Aga Khan Health Service Gilgit',
        city: 'Gilgit',
        address: 'Jutial, Gilgit',
        phone: '058-1920200',
        type: 'NGO / Specialist',
        hasEmergency: false,
        distance: 1.8,
        lat: 35.9201,
        lng: 74.3076,
      ),

      // Hunza
      Hospital(
        id: '22',
        name: 'Aga Khan Health Service Aliabad',
        city: 'Hunza',
        address: 'Aliabad, Hunza',
        phone: '05813-440077',
        type: 'NGO / Specialist',
        hasEmergency: true,
        distance: 1.5,
        lat: 36.2185,
        lng: 74.6513,
      ),
      Hospital(
        id: '23',
        name: 'DHQ Hospital Hunza (Karimabad)',
        city: 'Hunza',
        address: 'Karimabad, Hunza-Nagar',
        phone: '05813-457001',
        type: 'Government',
        hasEmergency: true,
        distance: 2.3,
        lat: 36.3168,
        lng: 74.6541,
      ),

      // Swat
      Hospital(
        id: '24',
        name: 'Saidu Group of Teaching Hospitals',
        city: 'Swat',
        address: 'Saidu Sharif, Swat',
        phone: '0946-9230007',
        type: 'Government',
        hasEmergency: true,
        distance: 2.0,
        lat: 34.7449,
        lng: 72.3560,
      ),
      Hospital(
        id: '25',
        name: 'DHQ Hospital Mingora',
        city: 'Swat',
        address: 'GT Road, Mingora',
        phone: '0946-9230100',
        type: 'Government',
        hasEmergency: true,
        distance: 3.2,
        lat: 34.7726,
        lng: 72.3600,
      ),

      // Abbottabad
      Hospital(
        id: '26',
        name: 'Ayub Teaching Hospital',
        city: 'Abbottabad',
        address: 'Mansehra Road, Abbottabad',
        phone: '0992-381166',
        type: 'Government',
        hasEmergency: true,
        distance: 1.8,
        lat: 34.1606,
        lng: 73.2180,
      ),
      Hospital(
        id: '27',
        name: 'CMH Abbottabad',
        city: 'Abbottabad',
        address: 'Cantt, Abbottabad',
        phone: '0992-9310401',
        type: 'Military Hospital',
        hasEmergency: true,
        distance: 2.6,
        lat: 34.1490,
        lng: 73.2135,
      ),

      // Chitral
      Hospital(
        id: '28',
        name: 'DHQ Hospital Chitral',
        city: 'Chitral',
        address: 'Ataliq Bazaar, Chitral',
        phone: '0943-412026',
        type: 'Government',
        hasEmergency: true,
        distance: 1.0,
        lat: 35.8508,
        lng: 71.7882,
      ),
      Hospital(
        id: '29',
        name: 'Aga Khan Health Service Chitral',
        city: 'Chitral',
        address: 'Mastuj Road, Chitral',
        phone: '0943-412200',
        type: 'NGO / Specialist',
        hasEmergency: false,
        distance: 1.9,
        lat: 35.8530,
        lng: 71.7910,
      ),

      // Naran
      Hospital(
        id: '30',
        name: 'Naran Emergency Health Centre',
        city: 'Naran',
        address: 'Main Bazaar, Naran',
        phone: '0997-415001',
        type: 'Government',
        hasEmergency: true,
        distance: 0.8,
        lat: 34.9065,
        lng: 73.6511,
      ),

      // Mansehra
      Hospital(
        id: '31',
        name: 'DHQ Hospital Mansehra',
        city: 'Mansehra',
        address: 'Shinkiari Road, Mansehra',
        phone: '0997-302401',
        type: 'Government',
        hasEmergency: true,
        distance: 1.3,
        lat: 34.3298,
        lng: 73.1974,
      ),

      // Murree
      Hospital(
        id: '32',
        name: 'DHQ Hospital Murree',
        city: 'Murree',
        address: 'The Mall, Murree',
        phone: '051-3410501',
        type: 'Government',
        hasEmergency: true,
        distance: 0.9,
        lat: 33.9072,
        lng: 73.3903,
      ),
      Hospital(
        id: '33',
        name: 'CMH Murree',
        city: 'Murree',
        address: 'GPO Road, Murree',
        phone: '051-3410601',
        type: 'Military Hospital',
        hasEmergency: true,
        distance: 1.5,
        lat: 33.9090,
        lng: 73.3940,
      ),

      // Nathiagali
      Hospital(
        id: '34',
        name: 'Nathiagali Health Centre',
        city: 'Nathiagali',
        address: 'Nathiagali Bazaar, KPK',
        phone: '0992-380050',
        type: 'Government',
        hasEmergency: false,
        distance: 0.5,
        lat: 34.0741,
        lng: 73.3778,
      ),

      // Muzaffarabad
      Hospital(
        id: '35',
        name: 'CMH Muzaffarabad',
        city: 'Muzaffarabad',
        address: 'AJK Road, Muzaffarabad',
        phone: '05822-42614',
        type: 'Military Hospital',
        hasEmergency: true,
        distance: 1.7,
        lat: 34.3596,
        lng: 73.4714,
      ),
      Hospital(
        id: '36',
        name: 'DHQ Hospital Muzaffarabad',
        city: 'Muzaffarabad',
        address: 'Chattar Domel, Muzaffarabad',
        phone: '05822-41041',
        type: 'Government',
        hasEmergency: true,
        distance: 2.4,
        lat: 34.3623,
        lng: 73.4698,
      ),

      // Rawalakot
      Hospital(
        id: '37',
        name: 'DHQ Hospital Rawalakot',
        city: 'Rawalakot',
        address: 'Bazar Road, Rawalakot, AJK',
        phone: '05824-440200',
        type: 'Government',
        hasEmergency: true,
        distance: 1.0,
        lat: 33.8575,
        lng: 73.7614,
      ),

      // Gujranwala
      Hospital(
        id: '38',
        name: 'DHQ Hospital Gujranwala',
        city: 'Gujranwala',
        address: 'Peoples Colony, Gujranwala',
        phone: '055-9200421',
        type: 'Government',
        hasEmergency: true,
        distance: 2.2,
        lat: 32.1601,
        lng: 74.1967,
      ),
      Hospital(
        id: '39',
        name: 'Govt. Victoria Hospital Gujranwala',
        city: 'Gujranwala',
        address: 'GT Road, Gujranwala',
        phone: '055-9200401',
        type: 'Government',
        hasEmergency: true,
        distance: 3.0,
        lat: 32.1877,
        lng: 74.1945,
      ),

      // Sialkot
      Hospital(
        id: '40',
        name: 'Allama Iqbal Memorial Hospital',
        city: 'Sialkot',
        address: 'Paris Road, Sialkot',
        phone: '052-9250101',
        type: 'Government',
        hasEmergency: true,
        distance: 1.9,
        lat: 32.4921,
        lng: 74.5400,
      ),

      // Bahawalpur
      Hospital(
        id: '41',
        name: 'Bahawal Victoria Hospital',
        city: 'Bahawalpur',
        address: 'Circular Road, Bahawalpur',
        phone: '062-9250201',
        type: 'Government',
        hasEmergency: true,
        distance: 1.6,
        lat: 29.3956,
        lng: 71.6836,
      ),

      // Hyderabad
      Hospital(
        id: '42',
        name: 'Liaquat University Hospital',
        city: 'Hyderabad',
        address: 'Jamshoro Road, Hyderabad',
        phone: '022-9200401',
        type: 'Government',
        hasEmergency: true,
        distance: 2.8,
        lat: 25.3813,
        lng: 68.3400,
      ),
      Hospital(
        id: '43',
        name: 'Civil Hospital Hyderabad',
        city: 'Hyderabad',
        address: 'Tilak Incline, Hyderabad',
        phone: '022-9200301',
        type: 'Government',
        hasEmergency: true,
        distance: 3.5,
        lat: 25.3960,
        lng: 68.3578,
      ),

      // Sukkur
      Hospital(
        id: '44',
        name: 'DHQ Hospital Sukkur',
        city: 'Sukkur',
        address: 'Military Road, Sukkur',
        phone: '071-9310101',
        type: 'Government',
        hasEmergency: true,
        distance: 1.2,
        lat: 27.7052,
        lng: 68.8574,
      ),

      // Larkana
      Hospital(
        id: '45',
        name: 'Chandka Medical College Hospital',
        city: 'Larkana',
        address: 'Dokri Road, Larkana',
        phone: '074-9310201',
        type: 'Government',
        hasEmergency: true,
        distance: 2.0,
        lat: 27.5580,
        lng: 68.2150,
      ),

      // Dera Ghazi Khan
      Hospital(
        id: '46',
        name: 'DHQ Hospital Dera Ghazi Khan',
        city: 'Dera Ghazi Khan',
        address: 'Hospital Road, DG Khan',
        phone: '064-9260101',
        type: 'Government',
        hasEmergency: true,
        distance: 1.5,
        lat: 30.0571,
        lng: 70.6350,
      ),

      // Gwadar
      Hospital(
        id: '47',
        name: 'DHQ Hospital Gwadar',
        city: 'Gwadar',
        address: 'Shaheed Square, Gwadar',
        phone: '0864-210101',
        type: 'Government',
        hasEmergency: true,
        distance: 1.0,
        lat: 25.1264,
        lng: 62.3225,
      ),

      // Ziarat
      Hospital(
        id: '48',
        name: 'DHQ Hospital Ziarat',
        city: 'Ziarat',
        address: 'Main Bazaar, Ziarat',
        phone: '081-9201801',
        type: 'Government',
        hasEmergency: false,
        distance: 0.8,
        lat: 30.3810,
        lng: 67.7285,
      ),

      // Mirpur
      Hospital(
        id: '49',
        name: 'DHQ Hospital Mirpur',
        city: 'Mirpur',
        address: 'New Mirpur City, AJK',
        phone: '05827-920001',
        type: 'Government',
        hasEmergency: true,
        distance: 1.3,
        lat: 33.1475,
        lng: 73.7511,
      ),

      // Fairy Meadows
      Hospital(
        id: '50',
        name: 'Tato Basic Health Unit',
        city: 'Fairy Meadows',
        address: 'Tato Village, Near Fairy Meadows',
        phone: '0346-5510001',
        type: 'Government',
        hasEmergency: false,
        distance: 4.0,
        lat: 35.3520,
        lng: 74.5800,
      ),

      // Kalash Valley
      Hospital(
        id: '51',
        name: 'Aga Khan Health Post Bumburet',
        city: 'Kalash Valley',
        address: 'Bumburet Valley, Chitral',
        phone: '0943-416100',
        type: 'NGO / Specialist',
        hasEmergency: false,
        distance: 1.5,
        lat: 35.7200,
        lng: 71.6500,
      ),
    ];
  }

  static List<String> getCities() {
    return getAllHospitals().map((h) => h.city).toSet().toList()..sort();
  }

  static List<Hospital> getEmergencyHospitals() {
    return getAllHospitals().where((h) => h.hasEmergency).toList();
  }
}

class EmergencyContact {
  final String service;
  final String number;
  final IconData icon;

  EmergencyContact({
    required this.service,
    required this.number,
    required this.icon,
  });

  static List<EmergencyContact> getContacts() {
    return [
      EmergencyContact(
        service: 'Emergency (Rescue 1122)',
        number: '1122',
        icon: Icons.emergency,
      ),
      EmergencyContact(
        service: 'Police',
        number: '15',
        icon: Icons.local_police,
      ),
      EmergencyContact(
        service: 'Ambulance (Edhi)',
        number: '115',
        icon: Icons.local_hospital,
      ),
      EmergencyContact(
        service: 'Fire Brigade',
        number: '16',
        icon: Icons.fire_truck,
      ),
    ];
  }
}
