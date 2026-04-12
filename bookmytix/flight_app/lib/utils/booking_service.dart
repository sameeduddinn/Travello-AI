import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Professional Booking Management Service
/// Handles storage and retrieval of both Train and Flight bookings
class BookingService {
  static const String _bookingsKey = 'user_bookings';

  /// Save a new booking (both train and flight)
  static Future<bool> saveBooking(Map<String, dynamic> bookingData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing bookings
      List<Map<String, dynamic>> bookings = await getAllBookings();

      // Add timestamp if not present
      if (!bookingData.containsKey('bookingDate')) {
        bookingData['bookingDate'] = DateTime.now().toIso8601String();
      }

      // Add unique ID if not present
      if (!bookingData.containsKey('bookingId')) {
        bookingData['bookingId'] = 'BK${DateTime.now().millisecondsSinceEpoch}';
      }

      // Add status if not present
      if (!bookingData.containsKey('status')) {
        bookingData['status'] = 'confirmed';
      }

      // Deep-sanitize: convert any non-JSON-serializable values (DateTime,
      // custom objects) to strings so jsonEncode never throws silently.
      final sanitized = _sanitize(bookingData) as Map<String, dynamic>;

      // Add to list
      bookings.insert(0, sanitized); // Insert at beginning (most recent first)

      // Save to storage
      String jsonString = jsonEncode(bookings);
      return await prefs.setString(_bookingsKey, jsonString);
    } catch (e) {
      // ignore: avoid_print
      debugPrint('BookingService.saveBooking error: $e');
      return false;
    }
  }

  /// Recursively converts any non-primitive value to a JSON-safe equivalent.
  static dynamic _sanitize(dynamic value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is List) return value.map(_sanitize).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitize(v)));
    }
    // Fallback: toString() for any custom Dart object (FlightResult, Airport…)
    return value.toString();
  }

  /// Get all bookings
  static Future<List<Map<String, dynamic>>> getAllBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonString = prefs.getString(_bookingsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting bookings: $e');
      return [];
    }
  }

  /// Get bookings filtered by type (train or flight)
  static Future<List<Map<String, dynamic>>> getBookingsByType(
      String type) async {
    List<Map<String, dynamic>> allBookings = await getAllBookings();
    return allBookings
        .where((booking) => booking['bookingType'] == type)
        .toList();
  }

  /// Get bookings filtered by status
  static Future<List<Map<String, dynamic>>> getBookingsByStatus(
      String status) async {
    List<Map<String, dynamic>> allBookings = await getAllBookings();
    return allBookings.where((booking) => booking['status'] == status).toList();
  }

  /// Get a specific booking by ID
  static Future<Map<String, dynamic>?> getBookingById(String bookingId) async {
    List<Map<String, dynamic>> allBookings = await getAllBookings();
    try {
      return allBookings
          .firstWhere((booking) => booking['bookingId'] == bookingId);
    } catch (e) {
      return null;
    }
  }

  /// Update booking status (e.g., confirmed, canceled, completed)
  static Future<bool> updateBookingStatus(
      String bookingId, String newStatus) async {
    try {
      List<Map<String, dynamic>> bookings = await getAllBookings();

      int index = bookings.indexWhere((b) => b['bookingId'] == bookingId);
      if (index == -1) return false;

      bookings[index]['status'] = newStatus;
      bookings[index]['lastUpdated'] = DateTime.now().toIso8601String();

      final prefs = await SharedPreferences.getInstance();
      String jsonString = jsonEncode(bookings);
      return await prefs.setString(_bookingsKey, jsonString);
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      return false;
    }
  }

  /// Update a specific field in a booking
  static Future<bool> updateBookingField(
      String bookingId, String field, dynamic value) async {
    try {
      List<Map<String, dynamic>> bookings = await getAllBookings();
      int index = bookings.indexWhere((b) => b['bookingId'] == bookingId);
      if (index == -1) return false;
      bookings[index][field] = _sanitize(value);
      bookings[index]['lastUpdated'] = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_bookingsKey, jsonEncode(bookings));
    } catch (e) {
      debugPrint('Error updating booking field: $e');
      return false;
    }
  }

  /// Delete a booking
  static Future<bool> deleteBooking(String bookingId) async {
    try {
      List<Map<String, dynamic>> bookings = await getAllBookings();
      bookings.removeWhere((b) => b['bookingId'] == bookingId);

      final prefs = await SharedPreferences.getInstance();
      String jsonString = jsonEncode(bookings);
      return await prefs.setString(_bookingsKey, jsonString);
    } catch (e) {
      debugPrint('Error deleting booking: $e');
      return false;
    }
  }

  /// Clear all bookings (for testing or logout)
  static Future<bool> clearAllBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_bookingsKey);
    } catch (e) {
      debugPrint('Error clearing bookings: $e');
      return false;
    }
  }

  /// Get booking count
  static Future<int> getBookingCount() async {
    List<Map<String, dynamic>> bookings = await getAllBookings();
    return bookings.length;
  }

  /// Get upcoming bookings (for dashboard)
  static Future<List<Map<String, dynamic>>> getUpcomingBookings() async {
    List<Map<String, dynamic>> allBookings = await getAllBookings();
    DateTime now = DateTime.now();

    return allBookings.where((booking) {
      if (booking['status'] != 'confirmed') return false;

      // Check departure date
      String? departureStr = booking['departure'];
      if (departureStr == null) return false;

      try {
        DateTime departure = DateTime.parse(departureStr);
        return departure.isAfter(now);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  /// Get past bookings (completed or canceled)
  static Future<List<Map<String, dynamic>>> getPastBookings() async {
    List<Map<String, dynamic>> allBookings = await getAllBookings();
    DateTime now = DateTime.now();

    return allBookings.where((booking) {
      // Check if status is completed or canceled
      if (booking['status'] == 'completed' || booking['status'] == 'canceled') {
        return true;
      }

      // Check if departure date has passed
      String? departureStr = booking['departure'];
      if (departureStr == null) return false;

      try {
        DateTime departure = DateTime.parse(departureStr);
        return departure.isBefore(now);
      } catch (e) {
        return false;
      }
    }).toList();
  }
}
