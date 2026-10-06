import 'package:flutter/foundation.dart';

/// บอกหน้าจอของแท็บที่เพิ่งถูกเลือกว่า "ถึงตาคุณแล้ว"
///
/// แท็บทั้งหมดถูกสร้างค้างไว้ใน `IndexedStack` (R6) จึงไม่มี `initState` ใหม่ตอนสลับแท็บ
/// หน้าจอที่ต้องดึงข้อมูลจึงต้องฟังบัสนี้ แต่ตัวมันเองไม่ตัดสินใจว่าจะยิงเซิร์ฟเวอร์หรือไม่ —
/// ปล่อยให้ [TabCache] เป็นคนบอกว่าของเดิมยังสดพอใช้ซ้ำหรือต้องยิงใหม่
class TabRefreshBus {
  TabRefreshBus._();

  static const int dashboardTab = 0;
  static const int submitTab = 1;
  static const int reportsTab = 2;
  static const int publicTab = 3;
  static const int settingsTab = 4;

  /// คาบที่แท็บซึ่งเปิดค้างอยู่จะดึงข้อมูลใหม่เอง — ใช้ร่วมกันทั้งสามแท็บที่มีข้อมูล
  /// จากเซิร์ฟเวอร์ (dashboard / รายงานของฉัน / รายงานสาธารณะ) ดู [TabAutoRefresh]
  static const Duration autoRefreshInterval = Duration(minutes: 1);

  static int _currentIndex = dashboardTab;
  static int get currentIndex => _currentIndex;

  /// นับขึ้นทุกครั้งที่กด เพื่อให้ listener ทำงานแม้ผู้ใช้กดแท็บเดิมซ้ำ
  /// (`ValueNotifier` ไม่ยิงเมื่อค่าไม่เปลี่ยน)
  static final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  /// เรียกจากปุ่มแท็บ — ตั้งค่า index ใหม่แล้วแจ้งทุกหน้าจอที่ฟังอยู่
  static void select(int index) {
    _currentIndex = index;
    _tick.value++;
  }

  static void addListener(VoidCallback listener) => _tick.addListener(listener);

  static void removeListener(VoidCallback listener) =>
      _tick.removeListener(listener);
}
