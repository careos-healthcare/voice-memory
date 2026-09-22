import 'package:flutter/material.dart';

/// Light, dark, or system appearance chosen from the command palette.
class ThemePreference extends ChangeNotifier {
  ThemePreference._();

  static final ThemePreference instance = ThemePreference._();

  ThemeMode mode = ThemeMode.system;

  void toggle() {
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
