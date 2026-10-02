import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application appearance, with optional persistence for the app entry point.
final class ThemeController extends ChangeNotifier {
  ThemeController({SharedPreferences? preferences})
    : _preferences = preferences,
      _mode = switch (preferences?.getString(_preferenceKey)) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };

  static const _preferenceKey = 'appearance.themeMode';
  final SharedPreferences? _preferences;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final saved = await _preferences?.setString(_preferenceKey, mode.name);
    if (saved == false) {
      throw StateError('Could not save appearance preference.');
    }
  }
}
