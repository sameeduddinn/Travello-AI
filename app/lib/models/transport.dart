class Transport {
  final String id;
  final String type; // 'Taxi', 'Rental Car', 'Bus', 'Rickshaw'
  final String name;
  final String vehicleModel;
  final int seatingCapacity;
  final double pricePerKm;
  final double basePrice;
  final String driverName;
  final double driverRating;
  final int totalRides;
  final List<String> features;
  final String imageUrl;
  final bool isAC;
  final bool isAvailable;

  Transport({
    required this.id,
    required this.type,
    required this.name,
    required this.vehicleModel,
    required this.seatingCapacity,
    required this.pricePerKm,
    required this.basePrice,
    required this.driverName,
    required this.driverRating,
    required this.totalRides,
    required this.features,
    required this.imageUrl,
    required this.isAC,
    required this.isAvailable,
  });

  double calculatePrice(double distanceKm) {
    return basePrice + (pricePerKm * distanceKm);
  }
}

class PakistanTransport {
  static List<Transport> getTransportsByCity(String city) {
    // All available transport options in Pakistan cities
    return [
      // Taxis
      Transport(
        id: 'tx1',
        type: 'Taxi',
        name: 'Careem GO',
        vehicleModel: 'Suzuki Cultus',
        seatingCapacity: 4,
        pricePerKm: 25,
        basePrice: 100,
        driverName: 'Ali Khan',
        driverRating: 4.7,
        totalRides: 1250,
        features: ['AC', 'GPS Tracking', 'Cashless Payment', 'Verified Driver'],
        imageUrl:
            'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=400',
        isAC: true,
        isAvailable: true,
      ),
      Transport(
        id: 'tx2',
        type: 'Taxi',
        name: 'Uber GO',
        vehicleModel: 'Honda City',
        seatingCapacity: 4,
        pricePerKm: 28,
        basePrice: 120,
        driverName: 'Hassan Ahmed',
        driverRating: 4.8,
        totalRides: 2100,
        features: ['AC', 'GPS Tracking', 'Cashless', 'Music System'],
        imageUrl:
            'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=400',
        isAC: true,
        isAvailable: true,
      ),
      Transport(
        id: 'tx3',
        type: 'Taxi',
        name: 'InDrive',
        vehicleModel: 'Toyota Corolla',
        seatingCapacity: 4,
        pricePerKm: 30,
        basePrice: 150,
        driverName: 'Imran Malik',
        driverRating: 4.6,
        totalRides: 980,
        features: ['AC', 'GPS', 'Negotiable Fare', 'Comfortable'],
        imageUrl:
            'https://images.unsplash.com/photo-1590362891991-f776e747a588?w=400',
        isAC: true,
        isAvailable: true,
      ),

      // Rental Cars
      Transport(
        id: 'rc1',
        type: 'Rental Car',
        name: 'Self Drive Sedan',
        vehicleModel: 'Honda Civic',
        seatingCapacity: 5,
        pricePerKm: 0, // Flat daily rate
        basePrice: 8000, // Per day
        driverName: 'Self Drive',
        driverRating: 0,
        totalRides: 0,
        features: ['AC', 'Fuel', 'Insurance', 'Unlimited KM (City)'],
        imageUrl:
            'https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?w=400',
        isAC: true,
        isAvailable: true,
      ),
      Transport(
        id: 'rc2',
        type: 'Rental Car',
        name: 'SUV with Driver',
        vehicleModel: 'Toyota Fortuner',
        seatingCapacity: 7,
        pricePerKm: 40,
        basePrice: 5000, // Base for 8 hours
        driverName: 'Professional Driver',
        driverRating: 4.9,
        totalRides: 450,
        features: ['AC', 'Spacious', 'Driver Included', 'GPS'],
        imageUrl:
            'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=400',
        isAC: true,
        isAvailable: true,
      ),

      // Rickshaws
      Transport(
        id: 'rk1',
        type: 'Rickshaw',
        name: 'Auto Rickshaw',
        vehicleModel: 'CNG Rickshaw',
        seatingCapacity: 3,
        pricePerKm: 15,
        basePrice: 50,
        driverName: 'Local Driver',
        driverRating: 4.2,
        totalRides: 3500,
        features: ['Cheap', 'Quick', 'Narrow Streets', 'Local Experience'],
        imageUrl:
            'https://images.unsplash.com/photo-1585328810645-aabbe8d202db?w=400',
        isAC: false,
        isAvailable: true,
      ),

      // Buses
      Transport(
        id: 'bs1',
        type: 'Bus',
        name: 'Metro Bus',
        vehicleModel: 'BRT Bus',
        seatingCapacity: 50,
        pricePerKm: 2,
        basePrice: 30, // Fixed route fare
        driverName: 'Metro Service',
        driverRating: 4.4,
        totalRides: 0,
        features: ['AC', 'Fixed Route', 'Economical', 'Safe'],
        imageUrl:
            'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=400',
        isAC: true,
        isAvailable: true,
      ),
      Transport(
        id: 'bs2',
        type: 'Bus',
        name: 'Daewoo Express',
        vehicleModel: 'Luxury Coach',
        seatingCapacity: 45,
        pricePerKm: 5,
        basePrice: 500, // Intercity
        driverName: 'Professional',
        driverRating: 4.7,
        totalRides: 0,
        features: ['AC', 'WiFi', 'Refreshments', 'Comfortable Seats'],
        imageUrl:
            'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400',
        isAC: true,
        isAvailable: true,
      ),
    ];
  }

  static List<Transport> searchTransport({
    required String type,
    int? minSeats,
    bool? requireAC,
    double? maxPricePerKm,
  }) {
    var transports = getTransportsByCity('');

    if (type.isNotEmpty) {
      transports = transports.where((t) => t.type == type).toList();
    }

    if (minSeats != null) {
      transports =
          transports.where((t) => t.seatingCapacity >= minSeats).toList();
    }

    if (requireAC == true) {
      transports = transports.where((t) => t.isAC).toList();
    }

    if (maxPricePerKm != null) {
      transports =
          transports.where((t) => t.pricePerKm <= maxPricePerKm).toList();
    }

    // Sort by rating
    transports.sort((a, b) => b.driverRating.compareTo(a.driverRating));

    return transports;
  }

  static List<String> getTransportTypes() {
    return ['Taxi', 'Rental Car', 'Rickshaw', 'Bus'];
  }

  static List<String> getCities() {
    return [
      'Karachi',
      'Lahore',
      'Islamabad',
      'Rawalpindi',
      'Peshawar',
      'Quetta',
      'Multan',
      'Faisalabad',
    ];
  }
}
