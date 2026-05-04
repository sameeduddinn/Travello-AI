import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flight_app/services/api_client.dart';

/// Wishlist service with local SharedPreferences + backend sync.
///
/// Local storage is always the source of truth for [isLiked] / [getAll]
/// so the UI is instant and works offline.
/// Backend sync runs in the background — failures are silently ignored.
class WishlistService {
  static const _idsPrefix   = 'wishlist_';       // wishlist_{type} → List<String>
  static const _dataPrefix  = 'wl_data_';        // wl_data_{type}_{id} → JSON
  static const _bkidPrefix  = 'wl_bkid_';        // wl_bkid_{type}_{id} → backend UUID

  // ── Local ID set ─────────────────────────────────────────────────────────

  static Future<Set<String>> _getIds(String type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_idsPrefix$type')?.toSet() ?? {};
  }

  static Future<void> _setIds(String type, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_idsPrefix$type', ids.toList());
  }

  // ── Backend UUID cache ────────────────────────────────────────────────────

  static Future<String?> _getBackendId(String type, String appId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_bkidPrefix${type}_$appId');
  }

  static Future<void> _setBackendId(
      String type, String appId, String backendId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_bkidPrefix${type}_$appId', backendId);
  }

  static Future<void> _clearBackendId(String type, String appId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_bkidPrefix${type}_$appId');
  }

  // ── Item data cache ───────────────────────────────────────────────────────

  static Future<void> _setItemData(
      String type, String appId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_dataPrefix${type}_$appId', jsonEncode(data));
  }

  static Future<void> _clearItemData(String type, String appId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_dataPrefix${type}_$appId');
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns true if [id] is currently saved for [type].
  static Future<bool> isLiked(String type, String id) async {
    final ids = await _getIds(type);
    return ids.contains(id);
  }

  /// Toggles [id] in the wishlist for [type].
  /// Returns `true` if the item was **added**, `false` if **removed**.
  ///
  /// Pass [itemData] (must include `'id'` key) when available — it is sent
  /// to the backend and cached locally so [syncFromBackend] can restore it.
  static Future<bool> toggle(
    String type,
    String id, {
    Map<String, dynamic>? itemData,
  }) async {
    final ids = await _getIds(type);

    if (ids.contains(id)) {
      // ── Remove ──────────────────────────────────────────────────────────
      ids.remove(id);
      await _setIds(type, ids);
      await _clearItemData(type, id);

      final backendId = await _getBackendId(type, id);
      if (backendId != null) {
        ApiClient.removeFromWishlist(backendId).catchError((_) {});
        await _clearBackendId(type, id);
      }
      return false;
    } else {
      // ── Add ─────────────────────────────────────────────────────────────
      ids.add(id);
      await _setIds(type, ids);

      if (itemData != null) {
        await _setItemData(type, id, itemData);
        ApiClient.addToWishlist(itemType: type, itemData: itemData)
            .then((backendId) async {
          if (backendId != null) await _setBackendId(type, id, backendId);
        }).catchError((_) {});
      }
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
    await _clearItemData(type, id);

    final backendId = await _getBackendId(type, id);
    if (backendId != null) {
      ApiClient.removeFromWishlist(backendId).catchError((_) {});
      await _clearBackendId(type, id);
    }
  }

  /// Fetches the backend wishlist and merges any missing items into local state.
  /// Also stores backend UUIDs so future [remove] calls can DELETE correctly.
  /// Safe to call on every wishlist screen open — failures are silently ignored.
  static Future<void> syncFromBackend() async {
    try {
      final items = await ApiClient.getWishlist();
      if (items.isEmpty) return;

      // Group items by type
      final byType = <String, List<Map<String, dynamic>>>{};
      for (final item in items) {
        final t = item['item_type']?.toString() ?? '';
        if (t.isEmpty) continue;
        byType.putIfAbsent(t, () => []).add(item);
      }

      for (final entry in byType.entries) {
        final type = entry.key;
        final localIds = await _getIds(type);
        bool changed = false;

        for (final item in entry.value) {
          final backendId = item['id']?.toString() ?? '';
          final itemData = item['item_data'] as Map<String, dynamic>? ?? {};
          final appId = itemData['id']?.toString() ?? '';
          if (appId.isEmpty || backendId.isEmpty) continue;

          // Always store the backend UUID so deletes work
          await _setBackendId(type, appId, backendId);

          if (!localIds.contains(appId)) {
            localIds.add(appId);
            changed = true;
            await _setItemData(type, appId, itemData);
          }
        }

        if (changed) await _setIds(type, localIds);
      }
    } catch (_) {
      // Non-fatal — local state is unchanged
    }
  }
}
