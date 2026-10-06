import 'dart:async';

import 'package:flutter/widgets.dart';

import 'tab_refresh_bus.dart';

/// ดึงข้อมูลซ้ำทุก [interval] ให้เฉพาะแท็บที่ผู้ใช้กำลังเปิดดูอยู่
///
/// ทำไมต้องมีด่านตัดสิน: แท็บทุกตัวถูกสร้างค้างไว้ใน `IndexedStack` (R6) จึงยัง
/// มีชีวิตอยู่แม้ผู้ใช้ไม่ได้ดูอยู่ ตัวจับเวลาแบบไม่คิดอะไรจะยิงเครือข่ายของทุกแท็บ
/// ไปเรื่อย ๆ ทั้งที่ไม่มีใครเห็นข้อมูล — เปล่าประโยชน์บนเครื่องสเปกต่ำ
///
/// [_sync] เริ่ม/หยุดตัวจับเวลาจากสองเหตุการณ์ที่รู้แน่ว่า "ตอนนี้มีคนดูแท็บนี้อยู่":
/// ผู้ใช้สลับแท็บ ([TabRefreshBus]) และแอปถูกพับ/กลับมาเบื้องหน้า
/// ส่วนเหตุการณ์ที่ไม่มีสัญญาณแจ้ง (มีหน้าอื่นถูก push ทับ) ตรวจซ้ำใน [_tick] อีกชั้น
/// — ตัวจับเวลาจะเดินต่อแต่ไม่ยิงคำขอ ขาดแค่การตื่นหนึ่งครั้งต่อนาที
///
/// ตัวนี้ไม่ตัดสินใจเรื่องแคชหรือกันคำขอซ้อน — เป็นหน้าที่ของหน้าจอเจ้าของ
class TabAutoRefresh {
  TabAutoRefresh({
    required this.tabIndex,
    required this.onRefresh,
    required this.isVisible,
    this.interval = TabRefreshBus.autoRefreshInterval,
  }) {
    TabRefreshBus.addListener(_sync);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycleState);
    // lifecycleState เป็น null ได้ตอน binding ยังไม่รู้สถานะ (เช่นในเทสต์) —
    // ถือว่าอยู่เบื้องหน้าไว้ก่อน แล้วรอเหตุการณ์จริงมาแก้
    _appInForeground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
    _sync();
  }

  /// ดัชนีแท็บของหน้าจอเจ้าของ — ค่าคงที่ตัวใดตัวหนึ่งใน [TabRefreshBus]
  final int tabIndex;

  /// เรียกเมื่อถึงรอบและหน้าจอกำลังถูกแสดงอยู่จริง
  final VoidCallback onRefresh;

  /// หน้าจอยังอยู่บนสุดของสแตกหรือไม่ — หน้าที่ถูก push ทับไม่ต้องยิงข้อมูล
  final bool Function() isVisible;

  final Duration interval;

  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  bool _appInForeground = true;

  void _onLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    _sync();
  }

  /// เปิดตัวจับเวลาเมื่อแท็บนี้ถูกเลือกและแอปอยู่เบื้องหน้า — นอกนั้นปิดทิ้ง
  /// ไม่ให้มี timer ค้างทำงานตอนว่าง (R2/R9)
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

  /// ต้องเรียกก่อน [State.dispose] ทุกครั้ง ไม่งั้น timer จะยังยิง callback ของ
  /// หน้าที่ถูกทำลายไปแล้ว
  void dispose() {
    TabRefreshBus.removeListener(_sync);
    _lifecycle.dispose();
    _timer?.cancel();
    _timer = null;
  }
}
