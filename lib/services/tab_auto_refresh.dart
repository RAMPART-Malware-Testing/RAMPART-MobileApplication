import 'dart:async';

import 'package:flutter/widgets.dart';

import 'tab_refresh_bus.dart';

class TabAutoRefresh {
  TabAutoRefresh({
    required this.tabIndex,
    required this.onRefresh,
    required this.isVisible,
    this.interval = TabRefreshBus.autoRefreshInterval,
  }) {
    TabRefreshBus.addListener(_sync);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleState);
    _appInForeground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
    _sync();
  }

  final int tabIndex;

  final VoidCallback onRefresh;

  final bool Function() isVisible;

  final Duration interval;

  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  bool _appInForeground = true;

  void _onLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final shouldRun = _appInForeground && TabRefreshBus.currentIndex == tabIndex;
    if (shouldRun == (_timer != null)) return;
    if (shouldRun) {
      _timer = Timer.periodic(interval, (_) => _tick());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _tick() {
    if (!_appInForeground ||
        TabRefreshBus.currentIndex != tabIndex ||
        !isVisible()) {
      return;
    }
    debugPrint('[auto-refresh] แท็บ $tabIndex ครบ $interval — ดึงข้อมูลใหม่');
    onRefresh();
  }

  void dispose() {
    TabRefreshBus.removeListener(_sync);
    _lifecycle.dispose();
    _timer?.cancel();
    _timer = null;
  }
}
