import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static const String _prefKeyDarkMode = 'admin_dark_mode';

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_prefKeyDarkMode) ?? false;
      themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      themeModeNotifier.value = ThemeMode.light;
    }
  }

  static Future<void> setDarkMode(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyDarkMode, isDark);
    } catch (_) {}
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}


