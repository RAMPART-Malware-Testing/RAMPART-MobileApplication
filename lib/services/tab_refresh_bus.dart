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

  static final ValueNotifier<int> _refreshSignal = ValueNotifier<int>(0);
  static int _requestedTabs = 0;

  static void select(int index) {
    _currentIndex = index;
    _tick.value++;
  }

  static void addListener(VoidCallback listener) => _tick.addListener(listener);

  static void removeListener(VoidCallback listener) =>
      _tick.removeListener(listener);

  /// ขอให้แท็บที่ระบุดึงข้อมูลใหม่ทันที (one-shot ต่อการสั่ง เช่น หลังแก้ privacy)
  static void requestRefresh(Set<int> tabs) {
    if (tabs.isEmpty) return;
    for (final tab in tabs) {
      _requestedTabs |= 1 << tab;
    }
    _refreshSignal.value++;
  }

  static bool consumeRefreshRequest(int tab) {
    final mask = 1 << tab;
    if ((_requestedTabs & mask) == 0) return false;
    _requestedTabs &= ~mask;
    return true;
  }

  static void addRefreshListener(VoidCallback listener) =>
      _refreshSignal.addListener(listener);

  static void removeRefreshListener(VoidCallback listener) =>
      _refreshSignal.removeListener(listener);
}
