import 'package:shared_preferences/shared_preferences.dart';

/// Tiny key/value persistence boundary. The mock database stores one
/// versioned JSON blob here; datasets are small, so no database package.
abstract class LocalStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class MemoryLocalStore implements LocalStore {
  final Map<String, String> _data = {};
  @override
  String? read(String key) => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> remove(String key) async => _data.remove(key);
}

class PrefsLocalStore implements LocalStore {
  PrefsLocalStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<PrefsLocalStore> open() async =>
      PrefsLocalStore(await SharedPreferences.getInstance());

  @override
  String? read(String key) => _prefs.getString(key);
  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
