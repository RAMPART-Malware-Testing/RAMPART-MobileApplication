import 'package:flutter/foundation.dart';

class TabRefreshBus {
  TabRefreshBus._();

  static const int dashboardTab = 0;
  static const int submitTab = 1;
  static const int reportsTab = 2;
  static const int publicTab = 3;
  static const int settingsTab = 4;

  static const Duration autoRefreshInterval = Duration(minutes: 1);

  static int _currentIndex = dashboardTab;
  static int get currentIndex => _currentIndex;

  static final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  static void select(int index) {
    _currentIndex = index;
    _tick.value++;
  }

  static void addListener(VoidCallback listener) => _tick.addListener(listener);

  static void removeListener(VoidCallback listener) =>
      _tick.removeListener(listener);
}
