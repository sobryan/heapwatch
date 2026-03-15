import 'package:flutter/foundation.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void setDark(bool dark) {
    if (_isDark != dark) {
      _isDark = dark;
      notifyListeners();
    }
  }
}
