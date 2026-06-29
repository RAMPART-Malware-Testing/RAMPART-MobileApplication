import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    PINService? ps;
    try {
      ps = Get.find<PINService>();
    } catch (_) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ps.evaluateLockOnBackground();
    } else if (state == AppLifecycleState.resumed) {
      ps.evaluateUnlockOnForeground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
