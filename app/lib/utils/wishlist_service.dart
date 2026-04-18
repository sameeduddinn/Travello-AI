import 'package:shared_preferences/shared_preferences.dart';

/// Persistent wishlist service backed by SharedPreferences.
/// Supported [type] values: 'hotel', 'flight', 'train'
class WishlistService {
  static const _prefix = 'wishlist_';

  static Future<Set<String>> _getIds(String type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_prefix$type')?.toSet() ?? {};
  }

  static Future<void> _setIds(String type, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_prefix$type', ids.toList());
  }

  /// Returns true if [id] is currently in the wishlist for [type].
  static Future<bool> isLiked(String type, String id) async {
    final ids = await _getIds(type);
    return ids.contains(id);
  }

  /// Toggles [id] in the wishlist for [type].
  /// Returns `true` if the item was **added**, `false` if it was **removed**.
  static Future<bool> toggle(String type, String id) async {
    final ids = await _getIds(type);
    if (ids.contains(id)) {
      ids.remove(id);
      await _setIds(type, ids);
      return false;
    } else {
      ids.add(id);
      await _setIds(type, ids);
      return true;
    }
  }

  /// Returns all saved IDs for [type].
  static Future<Set<String>> getAll(String type) => _getIds(type);

  /// Removes [id] from the wishlist for [type].
  static Future<void> remove(String type, String id) async {
    final ids = await _getIds(type);
    ids.remove(id);
    await _setIds(type, ids);
  }
}
