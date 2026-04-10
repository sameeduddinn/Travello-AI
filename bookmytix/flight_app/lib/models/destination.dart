import 'package:flutter/material.dart';

/// Travel destination model for dynamic home screen sections
/// Supports dynamic travel times based on user's origin city
class Destination {
  final String id;
  final String name;
  final String code;
  final String description;
  final String imageUrl;
  final Color cardColor;
  final String travelTime; // Legacy - kept for backward compatibility
  final Map<String, String>? durationMatrix; // New - supports dynamic times
  final int popularityRank;

  Destination({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.imageUrl,
    required this.cardColor,
    required this.travelTime,
    this.durationMatrix,
    required this.popularityRank,
  });

  /// Get travel time from specific origin city
  /// Falls back to travelTime if matrix not available or city not found
  String getTravelTimeFrom(String originCityCode) {
    if (durationMatrix != null && durationMatrix!.containsKey(originCityCode)) {
      return durationMatrix![originCityCode]!;
    }
    return travelTime; // Fallback to legacy field
  }

  /// Get formatted travel time with "from CITY" suffix
  String getFormattedTravelTime(String originCityCode, String originCityName) {
    final duration = getTravelTimeFrom(originCityCode);
    // If duration already contains 'from', return as-is
    if (duration.toLowerCase().contains('from') ||
        duration.toLowerCase().contains('junction') ||
        duration.toLowerCase().contains('paradise') ||
        duration.toLowerCase().contains('favorite')) {
      return duration;
    }
    return '$duration from $originCityName';
  }
}

/// Top Flight Destinations in Pakistan
/// Based on Wego, Sastaticket, and Bookme popular routes
final List<Destination> flightDestinations = [
  Destination(
    id: 'f1',
    name: 'Skardu',
    code: 'SKZ',
    description: 'Gateway to K2 & Gilgit-Baltistan',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    cardColor: const Color(0xFFFF9800), // Orange
    travelTime: '1h 15m from ISB',
    durationMatrix: {
      'KHI': '2h 30m',
      'ISB': '1h 15m',
      'LHE': '1h 30m',
      'PEW': '1h 45m',
      'MUX': '2h',
      'LYP': '1h 50m',
      'SKT': '1h 35m',
      'UET': 'No direct'
    },
    popularityRank: 1,
  ),
  Destination(
    id: 'f2',
    name: 'Lahore',
    code: 'LHE',
    description: 'Cultural heart of Pakistan',
    imageUrl:
        'https://images.unsplash.com/photo-1584204687456-cbed5e3c1e82?w=800&q=80',
    cardColor: const Color(0xFF1A237E), // Dark Blue
    travelTime: '1h 25m from KHI',
    durationMatrix: {
      'KHI': '1h 25m',
      'ISB': '50m',
      'LHE': 'Local',
      'PEW': '1h',
      'MUX': '45m',
      'LYP': '30m',
      'SKT': '25m',
      'UET': '2h'
    },
    popularityRank: 2,
  ),
  Destination(
    id: 'f3',
    name: 'Karachi',
    code: 'KHI',
    description: 'Pakistan\'s largest metropolis',
    imageUrl:
        'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&q=80',
    cardColor: const Color(0xFF90CAF9), // Light Blue
    travelTime: '1h 25m from LHE',
    durationMatrix: {
      'KHI': 'Local',
      'ISB': '1h 30m',
      'LHE': '1h 25m',
      'PEW': '1h 55m',
      'MUX': '1h 10m',
      'LYP': '1h',
      'SKT': '1h 50m',
      'UET': '1h 40m'
    },
    popularityRank: 3,
  ),
  Destination(
    id: 'f4',
    name: 'Islamabad',
    code: 'ISB',
    description: 'Modern capital city',
    imageUrl:
        'https://images.unsplash.com/photo-1519452635265-7b1fbfd1e4e0?w=800&q=80',
    cardColor: const Color(0xFFFF9800), // Orange
    travelTime: '1h 30m from KHI',
    durationMatrix: {
      'KHI': '1h 30m',
      'ISB': 'Local',
      'LHE': '50m',
      'PEW': '40m',
      'MUX': '1h 5m',
      'LYP': '55m',
      'SKT': '1h 10m',
      'UET': '2h 20m'
    },
    popularityRank: 4,
  ),
  Destination(
    id: 'f5',
    name: 'Gilgit',
    code: 'GIL',
    description: 'Base for mountain adventures',
    imageUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    cardColor: const Color(0xFF17A2B8), // Teal
    travelTime: '50m from ISB',
    durationMatrix: {
      'KHI': '2h 20m',
      'ISB': '50m',
      'LHE': '1h 20m',
      'PEW': '1h 30m',
      'MUX': '1h 50m',
      'LYP': '1h 40m',
      'SKT': '1h 25m',
      'UET': 'No direct'
    },
    popularityRank: 5,
  ),
  Destination(
    id: 'f6',
    name: 'Multan',
    code: 'MUX',
    description: 'City of Saints',
    imageUrl:
        'https://images.unsplash.com/photo-1605649487212-47bdab064df7?w=800&q=80',
    cardColor: const Color(0xFFFFF59D), // Yellow
    travelTime: '1h 10m from KHI',
    durationMatrix: {
      'KHI': '1h 10m',
      'ISB': '1h 5m',
      'LHE': '45m',
      'PEW': '1h 20m',
      'MUX': 'Local',
      'LYP': '40m',
      'SKT': '55m',
      'UET': '1h 50m'
    },
    popularityRank: 6,
  ),
  Destination(
    id: 'f7',
    name: 'Peshawar',
    code: 'PEW',
    description: 'Ancient Gandhara heritage',
    imageUrl:
        'https://images.unsplash.com/photo-1564769610726-6649e8efb2e7?w=800&q=80',
    cardColor: const Color(0xFFB3E5FC), // Light Blue
    travelTime: '40m from ISB',
    durationMatrix: {
      'KHI': '1h 55m',
      'ISB': '40m',
      'LHE': '1h',
      'PEW': 'Local',
      'MUX': '1h 20m',
      'LYP': '1h 10m',
      'SKT': '1h 15m',
      'UET': '2h 30m'
    },
    popularityRank: 7,
  ),
  Destination(
    id: 'f8',
    name: 'Faisalabad',
    code: 'LYP',
    description: 'Industrial hub & textile city',
    imageUrl:
        'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=80',
    cardColor: const Color(0xFFC5E1A5), // Light Green
    travelTime: '1h from KHI',
    durationMatrix: {
      'KHI': '1h',
      'ISB': '55m',
      'LHE': '30m',
      'PEW': '1h 10m',
      'MUX': '40m',
      'LYP': 'Local',
      'SKT': '35m',
      'UET': '1h 45m'
    },
    popularityRank: 8,
  ),
  Destination(
    id: 'f9',
    name: 'Quetta',
    code: 'UET',
    description: 'Fruit garden of Pakistan',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    cardColor: const Color(0xFFEF5350), // Red
    travelTime: '1h 40m from KHI',
    durationMatrix: {
      'KHI': '1h 40m',
      'ISB': '2h 20m',
      'LHE': '2h',
      'PEW': '2h 30m',
      'MUX': '1h 50m',
      'LYP': '1h 45m',
      'SKT': '2h 10m',
      'UET': 'Local'
    },
    popularityRank: 9,
  ),
  Destination(
    id: 'f10',
    name: 'Gwadar',
    code: 'GWD',
    description: 'Coastal beauty & CPEC hub',
    imageUrl:
        'https://images.unsplash.com/photo-1505142468610-359e7d316be0?w=800&q=80',
    cardColor: const Color(0xFF00BCD4), // Cyan
    travelTime: '1h 30m from KHI',
    durationMatrix: {
      'KHI': '1h 30m',
      'ISB': '3h',
      'LHE': '2h 45m',
      'PEW': '3h 30m',
      'MUX': '2h 20m',
      'LYP': '2h 30m',
      'SKT': '2h 50m',
      'UET': '1h 50m'
    },
    popularityRank: 10,
  ),
  Destination(
    id: 'f11',
    name: 'Sialkot',
    code: 'SKT',
    description: 'Sports goods manufacturing hub',
    imageUrl:
        'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=800&q=80',
    cardColor: const Color(0xFF9C27B0), // Purple
    travelTime: '1h 50m from KHI',
    durationMatrix: {
      'KHI': '1h 50m',
      'ISB': '1h 10m',
      'LHE': '25m',
      'PEW': '1h 15m',
      'MUX': '55m',
      'LYP': '35m',
      'SKT': 'Local',
      'UET': '2h 10m'
    },
    popularityRank: 11,
  ),
];

/// Top Train Destinations in Pakistan
/// Based on Pakistan Railways ML-1 main line and popular routes
final List<Destination> trainDestinations = [
  Destination(
    id: 't1',
    name: 'Lahore',
    code: 'LHR',
    description: 'Most popular train destination',
    imageUrl:
        'https://images.unsplash.com/photo-1584204687456-cbed5e3c1e82?w=800&q=80',
    cardColor: const Color(0xFF1A237E), // Dark Blue
    travelTime: '10-12h from Karachi',
    durationMatrix: {
      'KHI': '10-12h',
      'ISB': '3-4h',
      'LHE': 'Local',
      'PEW': '4-5h',
      'MUX': '5-6h',
      'LYP': '2-3h',
      'SKT': '2h',
      'UET': '16-18h'
    },
    popularityRank: 1,
  ),
  Destination(
    id: 't2',
    name: 'Rawalpindi',
    code: 'RWP',
    description: 'Twin city gateway',
    imageUrl:
        'https://images.unsplash.com/photo-1519452635265-7b1fbfd1e4e0?w=800&q=80',
    cardColor: const Color(0xFF90CAF9), // Light Blue
    travelTime: '18-20h from Karachi',
    durationMatrix: {
      'KHI': '18-20h',
      'ISB': '30m',
      'LHE': '3-4h',
      'PEW': '2h',
      'MUX': '8-9h',
      'LYP': '5-6h',
      'SKT': '4h',
      'UET': '22-24h'
    },
    popularityRank: 2,
  ),
  Destination(
    id: 't3',
    name: 'Karachi',
    code: 'KRC',
    description: 'Southern terminus & busiest station',
    imageUrl:
        'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&q=80',
    cardColor: const Color(0xFFFF9800), // Orange
    travelTime: 'Major junction',
    durationMatrix: {
      'KHI': 'Major junction',
      'ISB': '18-20h',
      'LHE': '10-12h',
      'PEW': '22-24h',
      'MUX': '8-9h',
      'LYP': '13-14h',
      'SKT': '15-16h',
      'UET': '26-28h'
    },
    popularityRank: 3,
  ),
  Destination(
    id: 't4',
    name: 'Bahawalpur',
    code: 'BWP',
    description: 'Historical capital of Punjab',
    imageUrl:
        'https://images.unsplash.com/photo-1605649487212-47bdab064df7?w=800&q=80',
    cardColor: const Color(0xFF17A2B8), // Teal
    travelTime: '8-9h from Karachi',
    durationMatrix: {
      'KHI': '8-9h',
      'ISB': '10-11h',
      'LHE': '5-6h',
      'PEW': '12-13h',
      'MUX': '3-4h',
      'LYP': '4-5h',
      'SKT': '6-7h',
      'UET': '18-20h'
    },
    popularityRank: 4,
  ),
  Destination(
    id: 't5',
    name: 'Multan',
    code: 'MUX',
    description: 'City of Sufi shrines',
    imageUrl:
        'https://images.unsplash.com/photo-1605649487212-47bdab064df7?w=800&q=80',
    cardColor: const Color(0xFFFFF59D), // Yellow
    travelTime: '8-9h from Karachi',
    durationMatrix: {
      'KHI': '8-9h',
      'ISB': '8-9h',
      'LHE': '5-6h',
      'PEW': '10-11h',
      'MUX': 'Local',
      'LYP': '3-4h',
      'SKT': '6-7h',
      'UET': '16-17h'
    },
    popularityRank: 5,
  ),
  Destination(
    id: 't6',
    name: 'Rohri Junction',
    code: 'ROR',
    description: 'Critical railway junction',
    imageUrl:
        'https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=800&q=80',
    cardColor: const Color(0xFFFF6B6B), // Coral Red
    travelTime: '6-7h from Karachi',
    durationMatrix: {
      'KHI': '6-7h',
      'ISB': '14-15h',
      'LHE': '11-12h',
      'PEW': '16-17h',
      'MUX': '3-4h',
      'LYP': '9-10h',
      'SKT': '12-13h',
      'UET': '20-22h'
    },
    popularityRank: 6,
  ),
  Destination(
    id: 't7',
    name: 'Sukkur',
    code: 'SKR',
    description: 'Gateway to Mohenjo-Daro',
    imageUrl:
        'https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=800&q=80',
    cardColor: const Color(0xFFC5E1A5), // Light Green
    travelTime: '7-8h from Karachi',
    durationMatrix: {
      'KHI': '7-8h',
      'ISB': '13-14h',
      'LHE': '10-11h',
      'PEW': '15-16h',
      'MUX': '4-5h',
      'LYP': '8-9h',
      'SKT': '11-12h',
      'UET': '19-21h'
    },
    popularityRank: 7,
  ),
  Destination(
    id: 't8',
    name: 'Faisalabad',
    code: 'FSD',
    description: 'Manchester of Pakistan',
    imageUrl:
        'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=80',
    cardColor: const Color(0xFFB3E5FC), // Light Blue
    travelTime: '13-14h from Karachi',
    durationMatrix: {
      'KHI': '13-14h',
      'ISB': '5-6h',
      'LHE': '2-3h',
      'PEW': '6-7h',
      'MUX': '3-4h',
      'LYP': 'Local',
      'SKT': '2h',
      'UET': '18-19h'
    },
    popularityRank: 8,
  ),
  Destination(
    id: 't9',
    name: 'Quetta',
    code: 'QTA',
    description: 'Western terminus on Bolan Pass',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    cardColor: const Color(0xFFEF5350), // Red
    travelTime: '26-28h from Karachi',
    durationMatrix: {
      'KHI': '26-28h',
      'ISB': '22-24h',
      'LHE': '16-18h',
      'PEW': '20-22h',
      'MUX': '16-17h',
      'LYP': '18-19h',
      'SKT': '20-21h',
      'UET': 'Local'
    },
    popularityRank: 9,
  ),
  Destination(
    id: 't10',
    name: 'Hyderabad',
    code: 'HYD',
    description: 'Gateway to rural Sindh',
    imageUrl:
        'https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=800&q=80',
    cardColor: const Color(0xFFFFB74D), // Light Orange
    travelTime: '2h from Karachi',
    durationMatrix: {
      'KHI': '2h',
      'ISB': '16-17h',
      'LHE': '13-14h',
      'PEW': '18-19h',
      'MUX': '10-11h',
      'LYP': '15-16h',
      'SKT': '14-15h',
      'UET': '24-25h'
    },
    popularityRank: 10,
  ),
  Destination(
    id: 't11',
    name: 'Sargodha',
    code: 'SGD',
    description: 'Agricultural hub & citrus capital',
    imageUrl:
        'https://images.unsplash.com/photo-1560493676-04071c5f467b?w=800&q=80',
    cardColor: const Color(0xFF81C784), // Medium Green
    travelTime: '12-14h from Karachi',
    durationMatrix: {
      'KHI': '12-14h',
      'ISB': '4-5h',
      'LHE': '2-3h',
      'PEW': '5-6h',
      'MUX': '6-7h',
      'LYP': '2h',
      'SKT': '3h',
      'UET': '17-18h'
    },
    popularityRank: 11,
  ),
];

/// Top Hotel Destinations in Pakistan
/// Based on Booking.com and Bookme popular valleys and tourist spots
final List<Destination> hotelDestinations = [
  Destination(
    id: 'h1',
    name: 'Hunza Valley',
    code: 'HNZ',
    description: '#1 destination for tourists',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    cardColor: const Color(0xFF1A237E), // Dark Blue
    travelTime: 'Northern Paradise',
    popularityRank: 1,
  ),
  Destination(
    id: 'h2',
    name: 'Swat Valley',
    code: 'SWT',
    description: 'Switzerland of Pakistan',
    imageUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    cardColor: const Color(0xFF4CAF50), // Green
    travelTime: 'Family favorite',
    popularityRank: 2,
  ),
  Destination(
    id: 'h3',
    name: 'Murree',
    code: 'MRE',
    description: 'Hill station near Islamabad',
    imageUrl:
        'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&q=80',
    cardColor: const Color(0xFFFF9800), // Orange
    travelTime: '2h from ISB',
    popularityRank: 3,
  ),
  Destination(
    id: 'h4',
    name: 'Neelum Valley',
    code: 'NEL',
    description: 'Azad Kashmir gem',
    imageUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    cardColor: const Color(0xFF17A2B8), // Teal
    travelTime: 'Summer retreat',
    popularityRank: 4,
  ),
  Destination(
    id: 'h5',
    name: 'Naran Kaghan',
    code: 'NRN',
    description: 'Alpine lakes & mountains',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    cardColor: const Color(0xFFB3E5FC), // Light Blue
    travelTime: 'Nature lover\'s paradise',
    popularityRank: 5,
  ),
  Destination(
    id: 'h6',
    name: 'Skardu',
    code: 'SKZ',
    description: 'Base camp for K2 treks',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    cardColor: const Color(0xFF90CAF9), // Light Blue
    travelTime: 'Adventure capital',
    popularityRank: 6,
  ),
  Destination(
    id: 'h7',
    name: 'Kalam',
    code: 'KLM',
    description: 'Scenic valley in Swat',
    imageUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    cardColor: const Color(0xFFC5E1A5), // Light Green
    travelTime: 'Winter sports hub',
    popularityRank: 7,
  ),
  Destination(
    id: 'h8',
    name: 'Fairy Meadows',
    code: 'FRM',
    description: 'Nanga Parbat base',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80',
    cardColor: const Color(0xFFFFF59D), // Yellow
    travelTime: 'Trekkers dream',
    popularityRank: 8,
  ),
  Destination(
    id: 'h9',
    name: 'Chitral',
    code: 'CHT',
    description: 'Hindu Kush paradise',
    imageUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
    cardColor: const Color(0xFF9C27B0), // Purple
    travelTime: 'Adventure destination',
    popularityRank: 9,
  ),
  Destination(
    id: 'h10',
    name: 'Ziarat',
    code: 'ZRT',
    description: 'Juniper forests & Quaid residency',
    imageUrl:
        'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&q=80',
    cardColor: const Color(0xFF8D6E63), // Brown
    travelTime: 'Historical retreat',
    popularityRank: 10,
  ),
  Destination(
    id: 'h11',
    name: 'Malam Jabba',
    code: 'MLJ',
    description: 'Pakistan\'s premier ski resort',
    imageUrl:
        'https://images.unsplash.com/photo-1605649487212-47bdab064df7?w=800&q=80',
    cardColor: const Color(0xFF00BCD4), // Cyan
    travelTime: 'Winter sports hub',
    popularityRank: 11,
  ),
];
