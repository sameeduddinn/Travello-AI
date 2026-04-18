// =============================================================================
// FILE: lib/services/api_client.dart
// PURPOSE: Centralized HTTP client for all Travello AI backend API calls.
//
// SETUP — change _baseUrl before running:
//   Android emulator → 'http://10.0.2.2:8000'   (maps to your PC's localhost)
//   iOS simulator    → 'http://127.0.0.1:8000'
//   Physical device  → 'http://192.168.X.X:8000' (your PC's LAN IP)
//   After deployment → 'https://travello-backend.onrender.com'
//
// Auth: every call sends the Supabase JWT from the current session.
//       If the user is not logged in the call is skipped and mock data is used.
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ── CHANGE THIS BEFORE RUNNING ────────────────────────────────────────────────
// Android emulator:  'http://10.0.2.2:8000'
// Physical device:   'http://192.168.1.X:8000'   (run `ipconfig` to find your IP)
// After deployment:  'https://travello-backend.onrender.com'
// const String kBackendBaseUrl = 'http://10.0.2.2:8000';
const String kBackendBaseUrl = 'http://192.168.0.102:8000';
// ─────────────────────────────────────────────────────────────────────────────

class ApiClient {
  static String get _baseUrl => kBackendBaseUrl;

  /// Returns the current Supabase session JWT, or null if not logged in.
  static String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── FLIGHTS ────────────────────────────────────────────────────────────────

  /// Search flights via Amadeus (or rich mock data if Amadeus not configured).
  /// Returns raw JSON offer maps — use [ApiClient.flightResultFromJson] to map.
  static Future<List<Map<String, dynamic>>> searchFlights({
    required String origin,
    required String destination,
    required DateTime date,
    DateTime? returnDate,
    int adults = 1,
    String cabinClass = 'Economy',
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/flights/search'),
          headers: _headers,
          body: jsonEncode({
            'origin': origin.toUpperCase(),
            'destination': destination.toUpperCase(),
            'date': _fmtDate(date),
            'adults': adults,
            'cabin_class': _mapCabinClass(cabinClass),
            if (returnDate != null) 'return_date': _fmtDate(returnDate),
          }),
        )
        .timeout(const Duration(seconds: 20));

    _throwIfError(res, 'Flight search');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['offers'] ?? []);
  }

  // ── TRAINS ─────────────────────────────────────────────────────────────────

  /// Search Pakistan Railways trains for the given city pair and date.
  /// Returns raw JSON train maps — use [ApiClient.trainResultFromJson] to map.
  static Future<List<Map<String, dynamic>>> searchTrains({
    required String originCity,
    required String destinationCity,
    required DateTime date,
    int passengers = 1,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/trains/search'),
          headers: _headers,
          body: jsonEncode({
            'origin': originCity,
            'destination': destinationCity,
            'date': _fmtDate(date),
            'passengers': passengers,
          }),
        )
        .timeout(const Duration(seconds: 15));

    _throwIfError(res, 'Train search');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['trains'] ?? []);
  }

  // ── HOTELS ─────────────────────────────────────────────────────────────────

  /// Search hotels via RapidAPI (or mock Pakistani hotels if not configured).
  /// Returns raw JSON hotel maps — use [ApiClient.hotelFromJson] to map.
  static Future<List<Map<String, dynamic>>> searchHotels({
    required String city,
    required DateTime checkIn,
    required DateTime checkOut,
    int guests = 1,
    int rooms = 1,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/hotels/search'),
          headers: _headers,
          body: jsonEncode({
            'city': city,
            'check_in': _fmtDate(checkIn),
            'check_out': _fmtDate(checkOut),
            'guests': guests,
            'rooms': rooms,
          }),
        )
        .timeout(const Duration(seconds: 20));

    _throwIfError(res, 'Hotel search');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['hotels'] ?? []);
  }

  // ── FLIGHT BOOKING ────────────────────────────────────────────────────────

  /// Create a flight booking. Returns map with `booking_id`, `pnr`, `status`, `total_amount`.
  static Future<Map<String, dynamic>> bookFlight({
    required String offerId,
    required String contactEmail,
    String? contactPhone,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/flights/book'),
          headers: _headers,
          body: jsonEncode({
            'offer_id': offerId,
            'contact_email': contactEmail,
            if (contactPhone != null && contactPhone.isNotEmpty)
              'contact_phone': contactPhone,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Flight booking');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── TRAIN BOOKING ─────────────────────────────────────────────────────────

  /// Create a train booking. Returns map with `booking_id`, `pnr`, `status`, `total_amount`.
  static Future<Map<String, dynamic>> bookTrain({
    required String trainId,
    required String classCode,
    required String contactEmail,
    int passengers = 1,
    String? contactPhone,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/trains/book'),
          headers: _headers,
          body: jsonEncode({
            'train_id': trainId,
            'class_code': classCode,
            'contact_email': contactEmail,
            'passengers': passengers,
            if (contactPhone != null && contactPhone.isNotEmpty)
              'contact_phone': contactPhone,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Train booking');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── HOTEL BOOKING ─────────────────────────────────────────────────────────

  /// Create a hotel booking. Returns map with `booking_id`, `pnr`, `status`, `total_amount`.
  static Future<Map<String, dynamic>> bookHotel({
    required String hotelId,
    required String checkIn,
    required String checkOut,
    required String contactEmail,
    String roomId = 'standard',
    int guests = 1,
    int rooms = 1,
    String? contactPhone,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/hotels/book'),
          headers: _headers,
          body: jsonEncode({
            'hotel_id': hotelId,
            'room_id': roomId,
            'check_in': checkIn,
            'check_out': checkOut,
            'contact_email': contactEmail,
            'guests': guests,
            'rooms': rooms,
            if (contactPhone != null && contactPhone.isNotEmpty)
              'contact_phone': contactPhone,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Hotel booking');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── PASSENGERS ────────────────────────────────────────────────────────────

  /// Add passengers to an existing booking. Returns list of created passenger records.
  static Future<List<Map<String, dynamic>>> addPassengers({
    required String bookingId,
    required List<Map<String, dynamic>> passengers,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/passengers'),
          headers: _headers,
          body: jsonEncode({
            'booking_id': bookingId,
            'passengers': passengers,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Add passengers');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  // ── PAYMENTS ──────────────────────────────────────────────────────────────

  /// Initiate payment for a booking. Returns `request_id` (for OTP) and `otp_required`.
  static Future<Map<String, dynamic>> initiatePayment({
    required String bookingId,
    required String method,
    required double amount,
    String? phone,
    String? email,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/payments/initiate'),
          headers: _headers,
          body: jsonEncode({
            'booking_id': bookingId,
            'method': method,
            'amount': amount,
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            if (email != null && email.isNotEmpty) 'email': email,
          }),
        )
        .timeout(const Duration(seconds: 20));
    _throwIfError(res, 'Payment initiation');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Verify OTP for wallet payment. Returns `success`, `booking_id`, `pnr`.
  static Future<Map<String, dynamic>> verifyPaymentOtp({
    required String requestId,
    required String otp,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/payments/verify-otp'),
          headers: _headers,
          body: jsonEncode({'request_id': requestId, 'otp': otp}),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'OTP verification');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── BOOKINGS ──────────────────────────────────────────────────────────────

  /// List the current user's bookings. Returns `{bookings: [...], total: N}`.
  static Future<Map<String, dynamic>> getBookings({
    int page = 1,
    int perPage = 50,
    String? status,
    String? bookingType,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      if (status != null) 'status': status,
      if (bookingType != null) 'booking_type': bookingType,
    };
    final res = await http
        .get(
          Uri.parse('$_baseUrl/bookings').replace(queryParameters: params),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Get bookings');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Get a single booking by UUID.
  static Future<Map<String, dynamic>> getBookingDetail(String bookingId) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/bookings/$bookingId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Get booking detail');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Cancel a booking. Returns updated booking map.
  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    final res = await http
        .put(
          Uri.parse('$_baseUrl/bookings/$bookingId/cancel'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Cancel booking');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Get e-ticket data for a booking.
  static Future<Map<String, dynamic>> getTicket(String bookingId) async {
    final res = await http
        .get(
          Uri.parse('$_baseUrl/bookings/$bookingId/ticket'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Get ticket');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── HEALTHCARE ────────────────────────────────────────────────────────────

  /// Find nearby hospitals. Pass [city] or [lat]/[lon].
  static Future<List<Map<String, dynamic>>> getNearbyHospitals({
    String? city,
    double? lat,
    double? lon,
    double radiusKm = 10,
  }) async {
    final params = <String, String>{
      if (city != null) 'city': city,
      if (lat != null) 'lat': '$lat',
      if (lon != null) 'lon': '$lon',
      'radius_km': '$radiusKm',
      'type': 'hospital',
    };
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/healthcare/nearby')
                .replace(queryParameters: params),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Get emergency contact numbers for a city/country.
  static Future<Map<String, dynamic>?> getEmergencyNumbers({
    String country = 'Pakistan',
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/healthcare/emergency-numbers')
                .replace(queryParameters: {'country': country}),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── WEATHER ────────────────────────────────────────────────────────────────

  /// Fetch current weather for a city from the backend (Open-Meteo, free).
  /// Returns null if the backend is unreachable — caller should use fallback.
  static Future<Map<String, dynamic>?> getWeather(String city) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/weather/${Uri.encodeComponent(city)}'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Fetch weather for all Pakistani cities in one call.
  static Future<List<Map<String, dynamic>>?> getAllCitiesWeather() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/weather/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final cities = data['cities'];
      if (cities is List) {
        return cities.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── RESPONSE → FLUTTER MODEL MAPPERS ───────────────────────────────────────

  /// Map a backend FlightOffer JSON → the fields needed to construct FlightResult.
  /// Returns a plain Map so flight_results_screen.dart can build its own model.
  static Map<String, dynamic> flightResultFromJson(
      Map<String, dynamic> offer, int index) {
    final itineraries = offer['itineraries'] as List? ?? [];
    final firstItin =
        itineraries.isNotEmpty ? itineraries[0] as Map<String, dynamic> : {};
    final segments =
        (firstItin['segments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final firstSeg = segments.isNotEmpty ? segments[0] : <String, dynamic>{};
    final lastSeg =
        segments.isNotEmpty ? segments[segments.length - 1] : <String, dynamic>{};

    final depTime = _parseTime(firstSeg['departure_time']?.toString());
    final arrTime = _parseTime(lastSeg['arrival_time']?.toString());
    final carrierCode = firstSeg['carrier_code']?.toString() ?? 'XX';
    final flightNum = firstSeg['flight_number']?.toString() ?? '';

    final stopCities = segments.length > 1
        ? segments
            .sublist(0, segments.length - 1)
            .map((s) => s['arrival_airport']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toList()
        : <String>[];

    // Assign badge: first = Fastest, cheapest index = Cheapest
    String badge = '';
    if (index == 0) badge = 'Fastest';

    return {
      'id': offer['offer_id']?.toString() ?? 'offer-$index',
      'airlineName': _airlineName(carrierCode),
      'airlineCode': carrierCode,
      'flightNumber': flightNum.isNotEmpty ? '$carrierCode$flightNum' : null,
      'departureTime': depTime,
      'arrivalTime': arrTime,
      'duration': firstItin['duration']?.toString() ?? '',
      'stops': segments.length - 1,
      'stopCities': stopCities,
      'price': (offer['total_price_pkr'] as num?)?.toDouble() ?? 0.0,
      'badge': badge,
      'isRefundable': offer['is_refundable'] == true,
      // Normalize backend ECONOMY → Flutter 'Economy' so cabin-class filter works
      'cabinClass': _mapBackendCabinClass(
          firstSeg['cabin_class']?.toString() ?? 'ECONOMY'),
      'seatsAvailable': (offer['seats_available'] as num?)?.toInt(),
      'baggage': offer['baggage_allowance']?.toString(),
    };
  }

  /// Map a backend TrainOffer JSON → the fields needed to construct TrainResult.
  static Map<String, dynamic> trainResultFromJson(
      Map<String, dynamic> train, int index) {
    final classes =
        (train['classes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final classSeats = <String, int?>{};
    final classPrices = <String, double>{};
    final availableClasses = <String>[];

    for (final c in classes) {
      final name = c['class_name']?.toString() ?? '';
      final seats = (c['seats_available'] as num?)?.toInt();
      final price = (c['price_pkr'] as num?)?.toDouble() ?? 0.0;
      if (name.isNotEmpty) {
        classSeats[name] = seats;
        classPrices[name] = price;
        availableClasses.add(name);
      }
    }

    final depStr = train['departure_at']?.toString() ?? '';
    final arrStr = train['arrival_at']?.toString() ?? '';
    DateTime? dep, arr;
    try {
      dep = DateTime.parse(depStr);
      arr = DateTime.parse(arrStr);
    } catch (_) {}

    final arrivesNextDay =
        dep != null && arr != null && arr.day > dep.day;

    return {
      'id': train['train_id']?.toString() ?? 'train-$index',
      'trainName': train['train_name']?.toString() ?? 'Train',
      'trainNumber': train['train_number']?.toString() ?? '',
      'departureTime': dep != null ? _fmtTimeFromDt(dep) : '',
      'arrivalTime': arr != null ? _fmtTimeFromDt(arr) : '',
      'arrivesNextDay': arrivesNextDay,
      'duration': train['duration']?.toString() ?? '',
      'classSeats': classSeats,
      'classPrices': classPrices,
      'availableClasses': availableClasses,
      'isRefundable': true,
      // Keep raw IDs for the booking step
      'rawTrainId': train['train_id'],
    };
  }

  /// Map a backend HotelOffer JSON → fields for the Flutter Hotel model.
  static Map<String, dynamic> hotelFromJson(Map<String, dynamic> hotel) {
    final rooms =
        (hotel['rooms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final amenities =
        (hotel['amenities'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final images =
        (hotel['images'] as List?)?.map((e) => e.toString()).toList() ?? [];

    double pricePerNight = 0;
    bool isRefundable = true;
    if (rooms.isNotEmpty) {
      pricePerNight =
          (rooms[0]['price_per_night_pkr'] as num?)?.toDouble() ?? 0;
      isRefundable = rooms[0]['is_refundable'] == true;
    }

    final starRating = (hotel['star_rating'] as num?)?.toDouble() ?? 3.0;
    String category;
    if (starRating >= 5) {
      category = '5-Star';
    } else if (starRating >= 4) {
      category = '4-Star';
    } else if (starRating >= 3) {
      category = '3-Star';
    } else {
      category = 'Budget';
    }

    final amenitySet = amenities.map((a) => a.toLowerCase()).toSet();

    return {
      'id': hotel['hotel_id']?.toString() ?? '',
      'name': hotel['name']?.toString() ?? 'Hotel',
      'address': hotel['address']?.toString() ?? '',
      'city': hotel['city']?.toString() ?? '',
      'rating': starRating,
      'totalReviews': (hotel['review_count'] as num?)?.toInt() ?? 0,
      'images': images,
      'amenities': amenities,
      'pricePerNight': pricePerNight,
      'category': category,
      'isRefundable': isRefundable,
      'hasBreakfast': amenitySet.any((a) =>
          a.contains('breakfast') || a.contains('restaurant')),
      'hasFreeWifi': amenitySet.any((a) => a.contains('wifi')),
      'hasParking': amenitySet.any((a) => a.contains('parking')),
      'hasPool': amenitySet.any((a) => a.contains('pool')),
      'description':
          '${hotel['name']} offers ${amenities.take(3).join(', ')} and more.',
      'distanceFromCenter': 0.0,
      'neighborhood': hotel['city'],
    };
  }

  // ── PRIVATE HELPERS ────────────────────────────────────────────────────────

  static String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _fmtTimeFromDt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// Parse an ISO datetime string and return "HH:mm".
  static String _parseTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(isoString);
      return _fmtTimeFromDt(dt);
    } catch (_) {
      // Try extracting time part directly "2024-05-15T08:00:00" → "08:00"
      if (isoString.contains('T')) {
        final timePart = isoString.split('T')[1];
        return timePart.substring(0, 5);
      }
      return '--:--';
    }
  }

  /// Map carrier code → full airline name.
  static String _airlineName(String code) {
    const airlines = {
      'PK': 'Pakistan International Airlines',
      'PA': 'Airblue',
      'ED': 'Airblue',   // alternate Airblue code returned by AviationStack
      'ER': 'SereneAir',
      'PF': 'AirSial',
      '9P': 'Fly Jinnah',
      'EK': 'Emirates',
      'QR': 'Qatar Airways',
      'TK': 'Turkish Airlines',
      'SV': 'Saudia',
      'EY': 'Etihad Airways',
      'FZ': 'flydubai',
      'G9': 'Air Arabia',
    };
    return airlines[code.toUpperCase()] ?? code.toUpperCase();
  }

  /// Map Flutter cabin class label → Amadeus backend format.
  static String _mapCabinClass(String flutterClass) {
    const map = {
      'Economy': 'ECONOMY',
      'Premium Economy': 'PREMIUM_ECONOMY',
      'Business': 'BUSINESS',
      'First Class': 'FIRST',
      'Economy (Seat)': 'ECONOMY',
    };
    return map[flutterClass] ?? 'ECONOMY';
  }

  /// Map backend cabin class (ECONOMY) → Flutter display format (Economy).
  /// Keeps the filter `flight.cabinClass == _selectedCabinClass` working.
  static String _mapBackendCabinClass(String backend) {
    const map = {
      'ECONOMY': 'Economy',
      'PREMIUM_ECONOMY': 'Premium Economy',
      'BUSINESS': 'Business',
      'FIRST': 'First Class',
    };
    return map[backend.toUpperCase()] ?? 'Economy';
  }

  static void _throwIfError(http.Response res, String context) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$context failed: HTTP ${res.statusCode} — ${res.body}');
    }
  }
}
