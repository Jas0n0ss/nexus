import 'package:flutter/foundation.dart';

/// Simple tab navigator so any screen can jump to Import / Nodes / Settings.
class ShellNav extends ChangeNotifier {
  int index = 0;

  void goTo(int i) {
    if (i < 0 || i > 4) return;
    if (i == index) {
      // Still notify so listeners can re-focus / scroll import UI.
      notifyListeners();
      return;
    }
    index = i;
    notifyListeners();
  }

  void openImport() => goTo(2);
  void openNodes() => goTo(1);
  void openDashboard() => goTo(0);
  void openSettings() => goTo(4);
}
