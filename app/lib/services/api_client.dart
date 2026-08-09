import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Override in build commands:
// flutter run --dart-define=BACKEND_BASE_URL=https://travello-ai.onrender.com
const String _backendFromDartDefine =
    String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
const String _defaultAndroidBackendUrl = 'https://travello-ai.onrender.com';
const String _defaultDesktopBackendUrl = 'https://travello-ai.onrender.com';
const String _defaultWebBackendUrl = 'https://travello-ai.onrender.com';

class ApiClient {
  static String get resolvedBaseUrl => _baseUrl;

  static void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[ApiClient] $message');
    }
  }

  static String get _baseUrl {
    final configured = _backendFromDartDefine.trim();
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return _defaultWebBackendUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _defaultAndroidBackendUrl;
    }
    return _defaultDesktopBackendUrl;
  }

  static const Map<String, List<double>> _cityCoords = {
    'karachi': [24.8607, 67.0011],
    'lahore': [31.5204, 74.3587],
    'islamabad': [33.6844, 73.0479],
    'rawalpindi': [33.5651, 73.0169],
    'multan': [30.1575, 71.5249],
    'faisalabad': [31.4504, 73.1350],
    'peshawar': [34.0151, 71.5249],
    'quetta': [30.1798, 66.9750],
    'skardu': [35.2971, 75.6338],
    'gilgit': [35.9208, 74.3149],
    'swat': [34.7462, 72.3578],
    'muzaffarabad': [34.3700, 73.4711],
    'abbottabad': [34.1463, 73.2117],
  };

  /// Returns the current Supabase session JWT, or null if not logged in.
  static String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  /// True when there is a valid logged-in session. Callers should check this
  /// before hitting authenticated endpoints (e.g. the AI agent) so the user
  /// gets a clear "please log in" message instead of a generic backend error.
  static bool get isLoggedIn => _token != null;

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
    _logDebug('POST $_baseUrl/flights/search');
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

    _logDebug('Flight search response: HTTP ${res.statusCode}');
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
    _logDebug('POST $_baseUrl/hotels/search city=$city');
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

    _logDebug('Hotel search response: HTTP ${res.statusCode}');
    _throwIfError(res, 'Hotel search');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['hotels'] ?? []);
  }

  /// Fetch real-time room availability for a specific hotel and date range.
  /// Returns list of room offer maps with `rooms_available` counts.
  static Future<List<Map<String, dynamic>>> fetchHotelRooms({
    required String hotelId,
    required DateTime checkIn,
    required DateTime checkOut,
    int guests = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl/hotels/$hotelId/rooms').replace(
      queryParameters: {
        'check_in': _fmtDate(checkIn),
        'check_out': _fmtDate(checkOut),
        'guests': guests.toString(),
      },
    );
    _logDebug('GET $uri');
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    _logDebug('Hotel rooms response: HTTP ${res.statusCode}');
    if (res.statusCode == 404) return [];
    _throwIfError(res, 'Hotel rooms');
    final data = jsonDecode(res.body);
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  // ── FLIGHT BOOKING ────────────────────────────────────────────────────────

  /// Create a flight booking. Returns map with `booking_id`, `pnr`, `status`, `total_amount`.
  static Future<Map<String, dynamic>> bookFlight({
    required String offerId,
    required String contactEmail,
    String? contactPhone,
    // Fallback fields for featured packages (no prior /flights/search needed)
    String? origin,
    String? destination,
    String? departureDate,
    String? departureTime,
    String? arrivalTime,
    String? airlineName,
    String? airlineCode,
    String? cabinClass,
    double? totalPricePkr,
    bool isRefundable = false,
    String? duration,
    Map<String, dynamic>? facilities,
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
            if (origin != null) 'origin': origin,
            if (destination != null) 'destination': destination,
            if (departureDate != null) 'departure_date': departureDate,
            if (departureTime != null) 'departure_time': departureTime,
            if (arrivalTime != null) 'arrival_time': arrivalTime,
            if (airlineName != null) 'airline_name': airlineName,
            if (airlineCode != null) 'airline_code': airlineCode,
            if (cabinClass != null) 'cabin_class': cabinClass,
            if (totalPricePkr != null) 'total_price_pkr': totalPricePkr,
            'is_refundable': isRefundable,
            if (duration != null) 'duration': duration,
            if (facilities != null && facilities.isNotEmpty)
              'facilities': facilities,
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
    // Fallback fields for featured packages not in backend cache
    String? trainName,
    String? trainNumber,
    String? origin,
    String? destination,
    String? departureAt,
    String? arrivalAt,
    String? className,
    double? totalPricePkr,
    Map<String, dynamic>? facilities,
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
            if (trainName != null) 'train_name': trainName,
            if (trainNumber != null) 'train_number': trainNumber,
            if (origin != null) 'origin': origin,
            if (destination != null) 'destination': destination,
            if (departureAt != null) 'departure_at': departureAt,
            if (arrivalAt != null) 'arrival_at': arrivalAt,
            if (className != null) 'class_name': className,
            if (totalPricePkr != null) 'total_price_pkr': totalPricePkr,
            if (facilities != null && facilities.isNotEmpty)
              'facilities': facilities,
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
    String? city,
    String roomId = 'standard',
    int guests = 1,
    int rooms = 1,
    String? contactPhone,
    // Fallback fields for featured packages (no prior /hotels/search needed)
    String? hotelName,
    double? starRating,
    double? pricePerNightPkr,
    String? roomType,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/hotels/book'),
          headers: _headers,
          body: jsonEncode({
            'hotel_id': hotelId,
            'room_id': roomId,
            if (city != null && city.isNotEmpty) 'city': city,
            'check_in': checkIn,
            'check_out': checkOut,
            'contact_email': contactEmail,
            'guests': guests,
            'rooms': rooms,
            if (contactPhone != null && contactPhone.isNotEmpty)
              'contact_phone': contactPhone,
            if (hotelName != null) 'hotel_name': hotelName,
            if (starRating != null) 'star_rating': starRating,
            if (pricePerNightPkr != null) 'price_per_night_pkr': pricePerNightPkr,
            if (roomType != null) 'room_type': roomType,
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
    final normalizedPassengers = _normalizePassengersForApi(passengers);
    final res = await http
        .post(
          Uri.parse('$_baseUrl/passengers'),
          headers: _headers,
          body: jsonEncode({
            'booking_id': bookingId,
            'passengers': normalizedPassengers,
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
    // When set, this ONE call pays for every component of the package and the
    // server verifies `amount` against the component rows before charging.
    String? packageId,
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
            if (packageId != null) 'package_id': packageId,
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
    _logDebug('GET $_baseUrl/bookings  token=${_token != null ? "present" : "NULL"}');
    final res = await http
        .get(
          Uri.parse('$_baseUrl/bookings').replace(queryParameters: params),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _logDebug('GET /bookings → HTTP ${res.statusCode}');
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

  /// Submit a review for a completed booking.
  static Future<Map<String, dynamic>> submitReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/reviews'),
          headers: _headers,
          body: jsonEncode({
            'booking_id': bookingId,
            'rating': rating,
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Submit review');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Save a search to the backend.
  static Future<void> saveSearch({
    required String searchType,
    required Map<String, dynamic> searchParams,
  }) async {
    if (_token == null) return;
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/saved-searches/'),
            headers: _headers,
            body: jsonEncode({
              'search_type': searchType,
              'search_params': searchParams,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Non-fatal — local history still works
    }
  }

  /// Get saved searches from backend.
  static Future<List<Map<String, dynamic>>> getSavedSearches() async {
    if (_token == null) return [];
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/saved-searches/'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = jsonDecode(res.body);
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Delete a saved search by ID.
  static Future<void> deleteSavedSearch(String id) async {
    if (_token == null) return;
    try {
      await http
          .delete(
            Uri.parse('$_baseUrl/saved-searches/$id'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ── WISHLIST ──────────────────────────────────────────────────────────────

  /// Fetch all wishlist items for the current user.
  static Future<List<Map<String, dynamic>>> getWishlist() async {
    if (_token == null) return [];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/wishlist'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = jsonDecode(res.body);
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Add an item to the wishlist. Returns the backend UUID, or null on failure.
  static Future<String?> addToWishlist({
    required String itemType,
    required Map<String, dynamic> itemData,
  }) async {
    if (_token == null) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/wishlist'),
            headers: _headers,
            body: jsonEncode({'item_type': itemType, 'item_data': itemData}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Remove a wishlist item by its backend UUID.
  static Future<void> removeFromWishlist(String backendItemId) async {
    if (_token == null) return;
    try {
      await http
          .delete(
            Uri.parse('$_baseUrl/wishlist/$backendItemId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
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

  /// Permanently delete a cancelled booking from history.
  static Future<void> deleteBooking(String bookingId) async {
    final res = await http
        .delete(
          Uri.parse('$_baseUrl/bookings/$bookingId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 15));
    _throwIfError(res, 'Delete booking');
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
    double? lng,
    double radiusKm = 20,
  }) async {
    double? resolvedLat = lat;
    double? resolvedLng = lng;

    if ((resolvedLat == null || resolvedLng == null) && city != null) {
      final coords = _cityCoords[city.trim().toLowerCase()];
      if (coords != null) {
        resolvedLat = coords[0];
        resolvedLng = coords[1];
      }
    }

    if (resolvedLat == null || resolvedLng == null) return [];

    final params = <String, String>{
      'lat': '$resolvedLat',
      'lng': '$resolvedLng',
      'radius': '$radiusKm',
      if (city != null && city.trim().isNotEmpty) 'city': city,
    };
    try {
      _logDebug('GET $_baseUrl/healthcare/nearby params=$params');
      final res = await http
          .get(
            Uri.parse('$_baseUrl/healthcare/nearby')
                .replace(queryParameters: params),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      _logDebug('Healthcare nearby response: HTTP ${res.statusCode}');
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = jsonDecode(res.body);
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map && data['results'] is List) {
        return List<Map<String, dynamic>>.from(data['results'] as List);
      }
      return [];
    } catch (e) {
      _logDebug('Healthcare nearby request failed: $e');
      return [];
    }
  }

  /// Get emergency contact numbers for a city/country.
  static Future<Map<String, dynamic>?> getEmergencyNumbers() async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/healthcare/emergency-numbers'),
            headers: _headers,
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
      final res = await http.get(
        Uri.parse('$_baseUrl/weather/${Uri.encodeComponent(city)}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Fetch weather for all Pakistani cities in one call.
  static Future<List<Map<String, dynamic>>?> getAllCitiesWeather() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/weather/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 12));

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
    final lastSeg = segments.isNotEmpty
        ? segments[segments.length - 1]
        : <String, dynamic>{};

    final depTime = _parseTime(firstSeg['departure_time']?.toString());
    final arrTime = _parseTime(lastSeg['arrival_time']?.toString());
    final carrierCode = firstSeg['carrier_code']?.toString() ?? 'XX';
    // The backend's flight_number already carries the carrier prefix (e.g.
    // "PA420", or AviationStack's own IATA designator) — don't prepend it
    // again here, or it renders as "PAPA420".
    final flightNum = firstSeg['flight_number']?.toString() ?? '';

    final stopCities = segments.length > 1
        ? segments
            .sublist(0, segments.length - 1)
            .map((s) => s['arrival_airport']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toList()
        : <String>[];

    return {
      'id': offer['offer_id']?.toString() ?? 'offer-$index',
      'airlineName': _airlineName(carrierCode),
      'airlineCode': carrierCode,
      'flightNumber': flightNum.isNotEmpty ? flightNum : null,
      'departureTime': depTime,
      'arrivalTime': arrTime,
      'duration': firstItin['duration']?.toString() ?? '',
      'stops': segments.length - 1,
      'stopCities': stopCities,
      'price': (offer['total_price_pkr'] as num?)?.toDouble() ?? 0.0,
      'badge': '',
      'isRefundable': offer['is_refundable'] == true,
      // Normalize backend ECONOMY → Flutter 'Economy' so cabin-class filter works
      'cabinClass': _mapBackendCabinClass(
          firstSeg['cabin_class']?.toString() ?? 'ECONOMY'),
      'seatsAvailable': (offer['seats_available'] as num?)?.toInt(),
      'baggage': offer['baggage_allowance']?.toString(),
    };
  }

  static String _mapTrainClassName(String backendName) {
    const map = {
      'Economy': 'Economy (Seat)',
      'AC Standard': 'AC Lower / Standard (Berth)',
      'Sleeper': 'Economy (Berth)',
    };
    return map[backendName] ?? backendName;
  }

  /// Map a backend TrainOffer JSON → the fields needed to construct TrainResult.
  static Map<String, dynamic> trainResultFromJson(
      Map<String, dynamic> train, int index) {
    final classes =
        (train['classes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final classSeats = <String, int?>{};
    final classPrices = <String, double>{};
    final classCodes = <String, String>{};
    final availableClasses = <String>[];

    for (final c in classes) {
      final rawName = c['class_name']?.toString() ?? '';
      final seats = (c['seats_available'] as num?)?.toInt();
      final price = (c['price_pkr'] as num?)?.toDouble() ?? 0.0;
      final code = c['class_code']?.toString() ?? '';
      if (rawName.isNotEmpty) {
        // Translate backend class names to the names Flutter's UI expects
        final name = _mapTrainClassName(rawName);
        classSeats[name] = seats;
        classPrices[name] = price;
        if (code.isNotEmpty) {
          classCodes[name] = code;
        }
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

    final arrivesNextDay = dep != null && arr != null && arr.day > dep.day;

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
      'classCodes': classCodes,
      'availableClasses': availableClasses,
      'isRefundable': true,
      // Keep raw IDs for the booking step
      'rawTrainId': train['train_id'],
    };
  }

  /// Map a backend HotelOffer JSON → fields for the Flutter Hotel model.
  static Map<String, dynamic> hotelFromJson(Map<String, dynamic> hotel) {
    final rooms = (hotel['rooms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
      'hasBreakfast': amenitySet
          .any((a) => a.contains('breakfast') || a.contains('restaurant')),
      'hasFreeWifi': amenitySet.any((a) => a.contains('wifi')),
      'hasParking': amenitySet.any((a) => a.contains('parking')),
      'hasPool': amenitySet.any((a) => a.contains('pool')),
      'description':
          '${hotel['name']} offers ${amenities.take(3).join(', ')} and more.',
      'distanceFromCenter': 0.0,
      'neighborhood': hotel['city'],
    };
  }

  static List<Map<String, dynamic>> _normalizePassengersForApi(
      List<Map<String, dynamic>> passengers) {
    String? clean(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    return passengers.map((rawPassenger) {
      final raw = Map<String, dynamic>.from(rawPassenger);
      final out = <String, dynamic>{};

      final firstName =
          clean(raw['first_name'] ?? raw['firstName'] ?? raw['fullName']);
      final lastName = clean(raw['last_name'] ?? raw['lastName']);
      if (firstName != null) out['first_name'] = firstName;
      out['last_name'] = (lastName != null && lastName.isNotEmpty)
          ? lastName
          : (firstName ?? 'Guest');

      final title = clean(raw['title']);
      const validTitles = {'Mr', 'Mrs', 'Ms', 'Dr', 'Prof'};
      if (title != null && validTitles.contains(title)) {
        out['title'] = title;
      }

      final dobRaw = clean(raw['date_of_birth'] ?? raw['dateOfBirth']);
      final normalizedDob = _normalizeDateForPassenger(dobRaw);
      if (normalizedDob != null) {
        out['date_of_birth'] = normalizedDob;
      }

      final genderRaw = clean(raw['gender'])?.toLowerCase();
      if (genderRaw == 'male' || genderRaw == 'female') {
        out['gender'] = genderRaw;
      }

      final nationality = clean(raw['nationality']);
      if (nationality != null) out['nationality'] = nationality;

      final cnic = clean(raw['cnic'] ?? raw['idNumber']);
      if (cnic != null) out['cnic'] = cnic;

      final passportNumber =
          clean(raw['passport_number'] ?? raw['passportNumber']);
      if (passportNumber != null) out['passport_number'] = passportNumber;

      final seatNumber = clean(raw['seat_number'] ?? raw['seatNumber']);
      if (seatNumber != null) out['seat_number'] = seatNumber;

      final passengerType = clean(
        raw['passenger_type'] ?? raw['passengerType'] ?? raw['type'],
      )?.toLowerCase();
      if (passengerType == 'adult' ||
          passengerType == 'child' ||
          passengerType == 'infant') {
        out['passenger_type'] = passengerType;
      } else {
        out['passenger_type'] = 'adult';
      }

      return out;
    }).toList();
  }

  static String? _normalizeDateForPassenger(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return null;
    final value = rawDate.trim();

    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return _fmtDate(parsed);
    }

    final dmy =
        RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(value);
    if (dmy != null) {
      final day = int.tryParse(dmy.group(1)!);
      final month = int.tryParse(dmy.group(2)!);
      final year = int.tryParse(dmy.group(3)!);
      if (day != null && month != null && year != null) {
        final dt = DateTime.tryParse(
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
        );
        if (dt != null) return _fmtDate(dt);
      }
    }

    return null;
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
      'ED': 'Airblue', // alternate Airblue code returned by AviationStack
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

  /// Send a contact-support message to travelloo.ai@gmail.com via backend SMTP.
  /// Also persists to DB when userId is provided. Fire-and-forget safe — never throws.
  static Future<bool> sendContactSupport({
    required String topic,
    required String subject,
    required String description,
    String senderEmail = '',
    String userId = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/email/contact-support'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'topic':        topic,
              'subject':      subject,
              'description':  description,
              'sender_email': senderEmail,
              'user_id':      userId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['sent'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Fetch authenticated user's support messages from backend.
  static Future<List<Map<String, dynamic>>?> getSupportMessages() async {
    try {
      if (_token == null) return null;
      final res = await http
          .get(
            Uri.parse('$_baseUrl/support/messages'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  /// Delete specific support messages by ID (only replied/closed are removed server-side).
  static Future<bool> deleteSupportMessages(List<String> ids) async {
    if (ids.isEmpty) return true;
    try {
      if (_token == null) return false;
      final res = await http
          .delete(
            Uri.parse('$_baseUrl/support/messages'),
            headers: _headers,
            body: jsonEncode({'ids': ids}),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// PUT /auth/profile — updates name and phone in the profiles table via FastAPI.
  static Future<bool> updateProfile({
    String? name,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['full_name'] = name;
    if (phone != null) body['phone'] = phone;
    if (body.isEmpty) return true;
    try {
      final res = await http
          .put(
            Uri.parse('$_baseUrl/auth/profile'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /auth/avatar — removes avatar from Supabase storage (via service role) and clears avatar_url.
  static Future<bool> removeAvatar() async {
    try {
      final res = await http
          .delete(
            Uri.parse('$_baseUrl/auth/avatar'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// POST /cars/book — book a standalone driver (Car tab on home screen).
  /// Returns booking confirmation with driver info and verification code.
  static Future<Map<String, dynamic>> bookCar({
    required String pickupLocation,
    required String dropoffLocation,
    required String vehicleType,
    required String pickupDatetime,
    String? contactEmail,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/cars/book'),
          headers: _headers,
          body: jsonEncode({
            'pickup_location': pickupLocation,
            'dropoff_location': dropoffLocation,
            'vehicle_type': vehicleType,
            'pickup_datetime': pickupDatetime,
            if (contactEmail != null) 'contact_email': contactEmail,
          }),
        )
        .timeout(const Duration(seconds: 30));
    _throwIfError(res, 'Book car');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /agent/proactive-alert — personalized trip alert if user has an
  /// upcoming booking within the next 7 days. Returns null if nothing upcoming.
  ///
  /// Returns the full payload (`alert`, plus `trip_key` / `title` / `category`)
  /// so the caller can both render the chat card and file the same alert in the
  /// notifications panel, deduped on `trip_key`.
  static Future<Map<String, dynamic>?> getProactiveAlert() async {
    if (_token == null) return null;
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/agent/proactive-alert'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final alert = data['alert'];
      return alert is String && alert.isNotEmpty ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// GET /cars/bookings — fetch all car bookings for the logged-in user.
  static Future<List<Map<String, dynamic>>> getCarBookings() async {
    if (_token == null) return [];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/cars/bookings'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = data['bookings'] as List<dynamic>? ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// DELETE /auth/account — permanently deletes the user account and all data.
  static Future<void> deleteAccount() async {
    final res = await http
        .delete(
          Uri.parse('$_baseUrl/auth/account'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    _throwIfError(res, 'Delete account');
  }

  // ── AI AGENT ───────────────────────────────────────────────────────────────

  /// POST /agent/book — create a booking from AI agent conversation context.
  /// Returns booking_id (UUID), pnr, total_amount, status.
  /// Flutter then calls initiatePayment() with the returned booking_id.
  static Future<Map<String, dynamic>> agentBook({
    required String bookingType,
    required String conversationId,
    // Trip Planner package: every component of one selected package sends the
    // SAME id, which is what links them into a single payment/confirmation.
    // Null for standalone bookings, which keeps package_id NULL server-side.
    String? packageId,
    String? origin,
    String? destination,
    String? travelDate,
    String? departureTime,
    String? arrivalTime,
    String? flightNumber,
    String? trainName,
    String? trainNumber,
    String? checkIn,
    String? checkOut,
    int travelers = 1,
    double totalAmount = 0.0,
    String? hotelName,
    String? passengerName,
    String? contactPhone,
    int? adults,
    int? children,
    int? infants,
    int? rooms,
    String? cabinClass,
    String? trainClass,
    String? roomType,
    int? hotelStars,
    String? hotelAddress,
    Map<String, dynamic>? facilities,
    String description = 'Agent-initiated booking',
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/agent/book'),
          headers: _headers,
          body: jsonEncode({
            'booking_type': bookingType,
            'conversation_id': conversationId,
            if (origin != null) 'origin': origin,
            if (destination != null) 'destination': destination,
            if (travelDate != null) 'travel_date': travelDate,
            if (departureTime != null) 'departure_time': departureTime,
            if (arrivalTime != null) 'arrival_time': arrivalTime,
            if (flightNumber != null) 'flight_number': flightNumber,
            if (trainName != null) 'train_name': trainName,
            if (trainNumber != null) 'train_number': trainNumber,
            if (checkIn != null) 'check_in': checkIn,
            if (checkOut != null) 'check_out': checkOut,
            'travelers': travelers,
            'total_amount': totalAmount,
            if (hotelName != null) 'hotel_name': hotelName,
            if (passengerName != null) 'passenger_name': passengerName,
            if (contactPhone != null) 'contact_phone': contactPhone,
            if (adults != null) 'adults': adults,
            if (children != null) 'children': children,
            if (infants != null) 'infants': infants,
            if (rooms != null) 'rooms': rooms,
            if (cabinClass != null) 'cabin_class': cabinClass,
            if (trainClass != null) 'train_class': trainClass,
            if (roomType != null) 'room_type': roomType,
            if (hotelStars != null) 'hotel_stars': hotelStars,
            if (hotelAddress != null) 'hotel_address': hotelAddress,
            if (facilities != null) 'facilities': facilities,
            if (packageId != null) 'package_id': packageId,
            'description': description,
          }),
        )
        .timeout(const Duration(seconds: 30));
    _throwIfError(res, 'Agent book');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Send a message to the multi-agent backend. Returns the assistant's reply
  /// and the conversation_id to pass on subsequent turns.
  static Future<Map<String, dynamic>> agentChat({
    required String message,
    String? conversationId,
    double? lat,
    double? lng,
  }) async {
    _logDebug('POST $_baseUrl/agent/chat');
    final res = await http
        .post(
          Uri.parse('$_baseUrl/agent/chat'),
          headers: _headers,
          body: jsonEncode({
            'message': message,
            if (conversationId != null) 'conversation_id': conversationId,
            // Optional live location — the backend uses it for "near me" /
            // "weather here" queries and ignores it when a city is named.
            if (lat != null && lng != null) 'lat': lat,
            if (lat != null && lng != null) 'lng': lng,
          }),
        )
        .timeout(const Duration(seconds: 60)); // agents can take a few seconds
    _throwIfError(res, 'Agent chat');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  // ── TRIP PACKAGES ─────────────────────────────────────────────────────────
  // The native Trip Package UI's two calls — thin wrappers around the SAME
  // backend engine (agents/trip_selection.py, the deterministic booking
  // engine) the AI Assistant chat flow drives. See routers/trip_packages.py.

  /// Trip Requirements -> Package Options. Returns `{conversation_id, options}`
  /// — `options` holds real, server-priced transport/hotel/transfer rows, no
  /// LLM involved. Pass `conversationId` back to refine (e.g. new dates)
  /// without losing the session; omit it to start a fresh one.
  static Future<Map<String, dynamic>> searchTripPackage({
    required String origin,
    required String destination,
    required String travelDate,
    String? returnDate,
    int? nights,
    required int travelers,
    required String preferredMode,   // 'flight' | 'train'
    String? cabinClass,
    int? minHotelStars,
    String? conversationId,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/trip-packages/search'),
          headers: _headers,
          body: jsonEncode({
            'origin': origin,
            'destination': destination,
            'travel_date': travelDate,
            if (returnDate != null) 'return_date': returnDate,
            if (nights != null) 'nights': nights,
            'travelers': travelers,
            'preferred_mode': preferredMode,
            if (cabinClass != null) 'cabin_class': cabinClass,
            if (minHotelStars != null) 'min_hotel_stars': minHotelStars,
            if (conversationId != null) 'conversation_id': conversationId,
          }),
        )
        .timeout(const Duration(seconds: 30));
    _throwIfError(res, 'Trip package search');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// The traveller's confirmed picks -> server verification, repricing and
  /// package assembly. Returns the same package_choice-shaped payload
  /// (`action`, `booking_data`, `summary`) the chat flow produces — feed
  /// `booking_data` straight into [CardPaymentSheet], unchanged.
  static Future<Map<String, dynamic>> confirmTripPackage({
    required String conversationId,
    required Map<String, int> picks,
    String? pickupLocation,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/trip-packages/confirm'),
          headers: _headers,
          body: jsonEncode({
            'conversation_id': conversationId,
            'picks': picks,
            if (pickupLocation != null) 'pickup_location': pickupLocation,
          }),
        )
        .timeout(const Duration(seconds: 30));
    _throwIfError(res, 'Trip package confirm');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// List all active conversations for the current user.
  static Future<List<Map<String, dynamic>>> getAgentConversations() async {
    if (_token == null) return [];
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/agent/conversations'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch all messages in a conversation (oldest first).
  static Future<List<Map<String, dynamic>>> getAgentMessages(
      String conversationId) async {
    if (_token == null) return [];
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/agent/conversations/$conversationId/messages'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Persist an assistant milestone note (e.g. "Booking Confirmed! PNR…") into
  /// the conversation so it survives reopening the chat. These cards are built
  /// client-side after a real success, and nothing else writes them to history.
  /// Best-effort: a failure here must never break the booking the user just
  /// completed, so errors are swallowed.
  static Future<void> saveAgentNote(
      String conversationId, String content) async {
    if (_token == null) return;
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/agent/conversations/$conversationId/notes'),
            headers: _headers,
            body: jsonEncode({'content': content}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Soft-delete a conversation (sets is_active = false on the backend).
  static Future<void> deleteAgentConversation(String conversationId) async {
    if (_token == null) return;
    try {
      await http
          .delete(
            Uri.parse('$_baseUrl/agent/conversations/$conversationId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static void _throwIfError(http.Response res, String context) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // utf8.decode(bodyBytes), not res.body: the server doesn't declare
      // charset=utf-8 on its JSON responses, so Dart's http package falls
      // back to a non-UTF-8 encoding for res.body and any non-ASCII
      // character (an em dash, a curly quote) comes out as mojibake
      // ("â€\"") in the exception text every caller of this surfaces to
      // the user. Every other successful response in this file already
      // decodes this way (see e.g. agentBook/agentChat) — only this error
      // path didn't.
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      _logDebug('$context failed with HTTP ${res.statusCode}: $body');
      throw ApiException(res.statusCode, '$context failed: HTTP ${res.statusCode} — $body');
    }
  }
}

/// Thrown by [ApiClient._throwIfError] instead of a plain [Exception] so callers
/// that care (e.g. the AI chat screen) can branch on the HTTP status code —
/// a 429 daily-limit response and a 504 timeout need different user-facing
/// messages, not the same generic "something went wrong".
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}
