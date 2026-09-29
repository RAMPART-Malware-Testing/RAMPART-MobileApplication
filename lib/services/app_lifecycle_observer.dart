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

    // ล็อกเฉพาะตอนแอปถูกซ่อนจริง (paused) — ไม่ล็อกตอน inactive เพราะเกิดบ่อย
    // เช่น มี dialog หรือ permission เด้งทับ หรือตอนกำลังเปิด Activity อื่น
    // ซึ่งทำให้แอปล็อกกลางคันโดยที่ผู้ใช้ไม่ได้ออกจากแอป
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
      // ยังไม่ได้ register — รอบถัดไปจะได้ทำต่อ
    }
  }

  /// หยุดวนตรวจเน็ตตอนแอปถูกพับ จะได้ไม่ตื่นมายิงเน็ททิ้งทุก 10 วินาทีทั้งที่ผู้ใช้ไม่ได้อยู่กับแอป
  void _syncNetworkMonitor(bool resumed) {
    try {
      final monitor = Get.find<NetworkMonitorService>();
      if (resumed) {
        monitor.resume();
      } else {
        monitor.pause();
      }
    } catch (_) {
      // ยังไม่ได้ register — รอบถัดไปจะได้ทำต่อ
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
