import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global city selection — single source of truth shared by Weather and
/// Healthcare screens. Persists the last-selected city across sessions.
class CityController extends GetxController {
  static CityController get to => Get.find();

  final RxString selectedCity = 'Karachi'.obs;
  static const _prefKey = 'travello_selected_city';

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      selectedCity.value = saved;
    } else {
      // Fall back to user's home city set in account settings
      final homeCity = prefs.getString('user_origin_city');
      if (homeCity != null && homeCity.isNotEmpty) {
        selectedCity.value = homeCity;
      }
    }
  }

  void setCity(String city) {
    if (city == selectedCity.value) return;
    selectedCity.value = city;
    // Fire-and-forget — we don't need to await the write
    SharedPreferences.getInstance()
        .then((p) => p.setString(_prefKey, city));
  }
}
