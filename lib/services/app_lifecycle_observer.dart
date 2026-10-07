import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rampart/services/network_monitor_service.dart';
import 'package:rampart/services/pin_service.dart';

class AppLifecycleObserver extends StatefulWidget {
  final Widget child;
  const AppLifecycleObserver({super.key, required this.child});

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused || resumed) {
      _syncNetworkMonitor(resumed);
    }

    if (state == AppLifecycleState.paused) {
      _withPin((ps) => ps.evaluateLockOnBackground());
    } else if (resumed) {
      _withPin((ps) => ps.evaluateUnlockOnForeground());
    }
  }

  void _withPin(void Function(PINService service) action) {
    try {
      action(Get.find<PINService>());
    } catch (_) {
    }
  }

  void _syncNetworkMonitor(bool resumed) {
    try {
      final monitor = Get.find<NetworkMonitorService>();
      if (resumed) {
        monitor.resume();
      } else {
        monitor.pause();
      }
    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
