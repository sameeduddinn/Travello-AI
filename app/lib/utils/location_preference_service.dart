import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage user's origin city preference for personalized travel times
/// Used to show "from YOUR_CITY" durations instead of hardcoded Karachi
class LocationPreferenceService {
  static const String _originCityKey = 'user_origin_city';
  static const String _originCityCodeKey = 'user_origin_city_code';
  static const String _citySetupCompleted = 'city_setup_completed';

  /// Check if user has already selected their origin city
  /// Returns true if setup is complete, false if city selector should be shown
  static Future<bool> hasOriginCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_citySetupCompleted) ?? false;
  }

  /// Save user's origin city preference
  /// Called when user selects city from onboarding modal
  static Future<void> setOriginCity(String cityName, String cityCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_originCityKey, cityName);
    await prefs.setString(_originCityCodeKey, cityCode);
    await prefs.setBool(_citySetupCompleted, true);
  }

  /// Get user's origin city (defaults to Karachi if not set)
  /// Returns Map with 'cityName' and 'cityCode' keys
  static Future<Map<String, String>> getOriginCity() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'cityName': prefs.getString(_originCityKey) ?? 'Karachi',
      'cityCode': prefs.getString(_originCityCodeKey) ?? 'KHI',
    };
  }

  /// Clear origin city preference (for testing or when user wants to reset)
  static Future<void> clearOriginCity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_originCityKey);
    await prefs.remove(_originCityCodeKey);
    await prefs.remove(_citySetupCompleted);
  }

  /// Get just the city code (for quick access)
  static Future<String> getOriginCityCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_originCityCodeKey) ?? 'KHI';
  }

  /// Get just the city name (for display purposes)
  static Future<String> getOriginCityName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_originCityKey) ?? 'Karachi';
  }
}
