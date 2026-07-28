import 'package:geolocator/geolocator.dart';

/// Best-effort device location for "near me" chat queries.
///
/// This NEVER throws and NEVER blocks the chat. It returns `null` whenever
/// location is unavailable — services off, permission denied, or a slow/absent
/// fix — in which case the backend simply falls back to city-based answers.
/// A recent fix is cached so we don't hit the GPS (or re-prompt) on every send.
class LocationService {
  static ({double lat, double lng})? _cached;
  static DateTime? _cachedAt;
  // Once the user denies, stop re-prompting for the rest of the session.
  static bool _denied = false;
  static const Duration _freshness = Duration(minutes: 5);

  /// Returns the device coordinates, or null if location can't be obtained.
  static Future<({double lat, double lng})?> getCoords() async {
    // Serve a recent fix without re-hitting the GPS or the permission dialog.
    if (_cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _freshness) {
      return _cached;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _cached;
      if (_denied) return _cached;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _denied = true;
        return _cached;
      }

      // A cached OS fix is instant; only fall back to a fresh (slower) read.
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );

      final coords = (lat: pos.latitude, lng: pos.longitude);
      _cached = coords;
      _cachedAt = DateTime.now();
      return coords;
    } catch (_) {
      // Timeout, no fix, or plugin error — degrade silently to city-based.
      return _cached;
    }
  }
}
