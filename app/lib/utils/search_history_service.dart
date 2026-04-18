import 'package:flight_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _flightHistoryKey = 'flight_search_history';
  static const String _trainHistoryKey = 'train_search_history';
  static const int _maxHistoryItems = 5;

  // Save flight search — also syncs to backend
  static Future<void> saveFlightSearch(
    String cityName, {
    Map<String, dynamic>? params,
  }) async {
    await _saveSearch(_flightHistoryKey, cityName);
    ApiClient.saveSearch(
      searchType: 'flight',
      searchParams: params ?? {'city': cityName},
    );
  }

  // Save train search — also syncs to backend
  static Future<void> saveTrainSearch(
    String cityName, {
    Map<String, dynamic>? params,
  }) async {
    await _saveSearch(_trainHistoryKey, cityName);
    ApiClient.saveSearch(
      searchType: 'train',
      searchParams: params ?? {'city': cityName},
    );
  }

  // Save hotel search — also syncs to backend
  static Future<void> saveHotelSearch(
    String cityName, {
    Map<String, dynamic>? params,
  }) async {
    await _saveSearch(_flightHistoryKey, cityName);
    ApiClient.saveSearch(
      searchType: 'hotel',
      searchParams: params ?? {'city': cityName},
    );
  }

  // Get flight search history
  static Future<List<String>> getFlightHistory() async {
    return await _getHistory(_flightHistoryKey);
  }

  // Get train search history
  static Future<List<String>> getTrainHistory() async {
    return await _getHistory(_trainHistoryKey);
  }

  // Get current travel mode
  static Future<String> getTravelMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('travel_mode') ?? 'flight';
  }

  // Get saved searches from backend (with local fallback)
  static Future<List<Map<String, dynamic>>> getBackendSavedSearches() async {
    try {
      return await ApiClient.getSavedSearches();
    } catch (_) {
      return [];
    }
  }

  // Delete a saved search from backend
  static Future<void> deleteBackendSearch(String id) async {
    await ApiClient.deleteSavedSearch(id);
  }

  // Private helper to save search
  static Future<void> _saveSearch(String key, String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(key) ?? [];

    // Remove if already exists to avoid duplicates
    history.remove(cityName);

    // Add to beginning
    history.insert(0, cityName);

    // Keep only last N items
    if (history.length > _maxHistoryItems) {
      history = history.sublist(0, _maxHistoryItems);
    }

    await prefs.setStringList(key, history);
  }

  // Private helper to get history
  static Future<List<String>> _getHistory(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  // Clear flight history
  static Future<void> clearFlightHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_flightHistoryKey);
  }

  // Clear train history
  static Future<void> clearTrainHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trainHistoryKey);
  }

  // Clear all history
  static Future<void> clearAllHistory() async {
    await clearFlightHistory();
    await clearTrainHistory();
  }
}
