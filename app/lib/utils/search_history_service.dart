import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _flightHistoryKey = 'flight_search_history';
  static const String _trainHistoryKey = 'train_search_history';
  static const int _maxHistoryItems = 5;

  // Save flight search
  static Future<void> saveFlightSearch(String cityName) async {
    await _saveSearch(_flightHistoryKey, cityName);
  }

  // Save train search
  static Future<void> saveTrainSearch(String cityName) async {
    await _saveSearch(_trainHistoryKey, cityName);
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
