import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _prefKey = 'ui_style_neo';

  // Default to Neo (true) as it's the current fresh look
  bool _isNeo = true;

  bool get isNeo => _isNeo;

  ThemeService() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isNeo = prefs.getBool(_prefKey) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isNeo = !_isNeo;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _isNeo);
  }
}
