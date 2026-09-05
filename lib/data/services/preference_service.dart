import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  late final SharedPreferences _preferences;

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  bool getBool(String key, bool fallback) {
    return _preferences.getBool(key) ?? fallback;
  }

  Future<void> setBool(String key, bool value) {
    return _preferences.setBool(key, value);
  }

  double getDouble(String key, double fallback) {
    return _preferences.getDouble(key) ?? fallback;
  }

  Future<void> setDouble(String key, double value) {
    return _preferences.setDouble(key, value);
  }

  int getInt(String key, int fallback) {
    return _preferences.getInt(key) ?? fallback;
  }

  Future<void> setInt(String key, int value) {
    return _preferences.setInt(key, value);
  }

  Future<void> remove(String key) {
    return _preferences.remove(key);
  }

  Future<void> clearByPrefix(String prefix) async {
    final keys = _preferences.getKeys().where((key) => key.startsWith(prefix));
    for (final key in keys) {
      await _preferences.remove(key);
    }
  }
}
