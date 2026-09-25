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
    // ล็อกเฉพาะตอนแอปถูกซ่อนจริง (paused) — ไม่ล็อกตอน inactive เพราะเกิดบ่อย
    // เช่น มี dialog หรือ permission เด้งทับ หรือตอนกำลังเปิด Activity อื่น
    // ซึ่งทำให้แอปล็อกกลางคันโดยที่ผู้ใช้ไม่ได้ออกจากแอป
    if (state == AppLifecycleState.paused) {
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
