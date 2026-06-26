import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // Secara default, kita set ke mode sistem HP, tapi bisa juga di-set ke ThemeMode.light
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // Cek tema sistem HP saat ini
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // Memperbarui semua widget yang mendengarkan provider ini
  }
}