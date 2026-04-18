class Train {
  final String id;
  final String name;
  final String trainNumber;
  final String fromStation;
  final String toStation;
  final String departureTime;
  final String arrivalTime;
  final String duration;
  final String trainClass;
  final double price;
  final int availableSeats;
  final String operatedBy;

  Train({
    required this.id,
    required this.name,
    required this.trainNumber,
    required this.fromStation,
    required this.toStation,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    required this.trainClass,
    required this.price,
    required this.availableSeats,
    this.operatedBy = 'Pakistan Railways',
  });

  factory Train.fromJson(Map<String, dynamic> json) {
    return Train(
      id: json['id'] as String,
      name: json['name'] as String,
      trainNumber: json['trainNumber'] as String,
      fromStation: json['fromStation'] as String,
      toStation: json['toStation'] as String,
      departureTime: json['departureTime'] as String,
      arrivalTime: json['arrivalTime'] as String,
      duration: json['duration'] as String,
      trainClass: json['trainClass'] as String,
      price: (json['price'] as num).toDouble(),
      availableSeats: json['availableSeats'] as int,
      operatedBy: json['operatedBy'] as String? ?? 'Pakistan Railways',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trainNumber': trainNumber,
      'fromStation': fromStation,
      'toStation': toStation,
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'duration': duration,
      'trainClass': trainClass,
      'price': price,
      'availableSeats': availableSeats,
      'operatedBy': operatedBy,
    };
  }
}

// Dummy Train Data for Pakistan Railways
class PakistanTrains {
  static List<Train> getDummyTrains({
    String? fromStation,
    String? toStation,
    String? trainClass,
  }) {
    final allTrains = [
      // Karachi to Lahore
      Train(
        id: '1',
        name: 'Tezgam Express',
        trainNumber: '1UP',
        fromStation: 'Karachi Cantt',
        toStation: 'Lahore Junction',
        departureTime: '06:00 AM',
        arrivalTime: '07:30 PM',
        duration: '13h 30m',
        trainClass: 'AC Business',
        price: 3500,
        availableSeats: 45,
      ),
      Train(
        id: '2',
        name: 'Green Line Express',
        trainNumber: '5UP',
        fromStation: 'Karachi Cantt',
        toStation: 'Lahore Junction',
        departureTime: '11:00 PM',
        arrivalTime: '12:30 PM',
        duration: '13h 30m',
        trainClass: 'AC Sleeper',
        price: 4200,
        availableSeats: 28,
      ),

      // Karachi to Rawalpindi
      Train(
        id: '3',
        name: 'Pakistan Express',
        trainNumber: '8UP',
        fromStation: 'Karachi Cantt',
        toStation: 'Rawalpindi',
        departureTime: '07:30 AM',
        arrivalTime: '10:00 PM',
        duration: '14h 30m',
        trainClass: 'AC Standard',
        price: 2800,
        availableSeats: 62,
      ),
      Train(
        id: '4',
        name: 'Karachi Express',
        trainNumber: '16UP',
        fromStation: 'Karachi Cantt',
        toStation: 'Rawalpindi',
        departureTime: '05:00 PM',
        arrivalTime: '07:30 AM',
        duration: '14h 30m',
        trainClass: 'Economy',
        price: 1500,
        availableSeats: 120,
      ),

      // Lahore to Karachi
      Train(
        id: '5',
        name: 'Tezgam Express',
        trainNumber: '2DN',
        fromStation: 'Lahore Junction',
        toStation: 'Karachi Cantt',
        departureTime: '08:00 AM',
        arrivalTime: '09:30 PM',
        duration: '13h 30m',
        trainClass: 'AC Business',
        price: 3500,
        availableSeats: 38,
      ),

      // Lahore to Rawalpindi
      Train(
        id: '6',
        name: 'Subak Raftar',
        trainNumber: '20UP',
        fromStation: 'Lahore Junction',
        toStation: 'Rawalpindi',
        departureTime: '06:30 AM',
        arrivalTime: '10:30 AM',
        duration: '4h 00m',
        trainClass: 'AC Business',
        price: 1800,
        availableSeats: 52,
      ),
      Train(
        id: '7',
        name: 'Islamabad Express',
        trainNumber: '24UP',
        fromStation: 'Lahore Junction',
        toStation: 'Rawalpindi',
        departureTime: '02:00 PM',
        arrivalTime: '06:15 PM',
        duration: '4h 15m',
        trainClass: 'Economy',
        price: 800,
        availableSeats: 95,
      ),

      // Karachi to Quetta
      Train(
        id: '8',
        name: 'Bolan Mail',
        trainNumber: '3UP',
        fromStation: 'Karachi Cantt',
        toStation: 'Quetta',
        departureTime: '09:00 PM',
        arrivalTime: '03:00 PM',
        duration: '18h 00m',
        trainClass: 'AC Sleeper',
        price: 3200,
        availableSeats: 30,
      ),

      // Karachi to Peshawar
      Train(
        id: '9',
        name: 'Khyber Mail',
        trainNumber: '9UP',
        fromStation: 'Karachi Cantt',
        toStation: 'Peshawar Cantt',
        departureTime: '05:30 PM',
        arrivalTime: '09:00 AM',
        duration: '15h 30m',
        trainClass: 'AC Standard',
        price: 3000,
        availableSeats: 48,
      ),

      // Lahore to Multan
      Train(
        id: '10',
        name: 'Business Express',
        trainNumber: '12UP',
        fromStation: 'Lahore Junction',
        toStation: 'Multan Cantt',
        departureTime: '08:00 AM',
        arrivalTime: '01:00 PM',
        duration: '5h 00m',
        trainClass: 'AC Business',
        price: 1200,
        availableSeats: 40,
      ),
    ];

    // Filter trains based on search criteria
    var filteredTrains = allTrains;

    if (fromStation != null && fromStation.isNotEmpty) {
      filteredTrains = filteredTrains
          .where((train) => train.fromStation
              .toLowerCase()
              .contains(fromStation.toLowerCase()))
          .toList();
    }

    if (toStation != null && toStation.isNotEmpty) {
      filteredTrains = filteredTrains
          .where((train) =>
              train.toStation.toLowerCase().contains(toStation.toLowerCase()))
          .toList();
    }

    if (trainClass != null && trainClass.isNotEmpty && trainClass != 'All') {
      filteredTrains = filteredTrains
          .where((train) => train.trainClass == trainClass)
          .toList();
    }

    return filteredTrains;
  }

  static List<String> getTrainClasses() {
    return ['All', 'Economy', 'AC Standard', 'AC Business', 'AC Sleeper'];
  }
}
