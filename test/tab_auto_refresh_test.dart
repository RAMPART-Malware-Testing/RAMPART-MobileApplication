import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rampart/services/tab_auto_refresh.dart';
import 'package:rampart/services/tab_refresh_bus.dart';

/// ยืนยันว่าการรีเฟรชอัตโนมัติทำงาน "เฉพาะแท็บที่ผู้ใช้กำลังเปิดดูอยู่"
/// ตัวจับเวลาต้องไม่ยิงข้อมูลของแท็บที่ถูกทิ้งไว้ข้างหลัง และต้องหยุดจริงเมื่อ
/// สลับออกหรือทิ้งหน้าจอ (ไม่มี timer ค้าง — R9)

/// หน้าจอจำลองที่ผูก [TabAutoRefresh] แบบเดียวกับแท็บจริงในแอป
class _TabHarness extends StatefulWidget {
  const _TabHarness({
    required this.tabIndex,
    required this.onTick,
    this.visible = true,
  });

  final int tabIndex;
  final VoidCallback onTick;

  /// สมมติว่ามีหน้าอื่นถูก push ทับอยู่หรือไม่ (เทสต์ส่ง callback คงที่)
  final bool visible;

  @override
  State<_TabHarness> createState() => _TabHarnessState();
}

class _TabHarnessState extends State<_TabHarness> {
  late final TabAutoRefresh _autoRefresh;

  @override
  void initState() {
    super.initState();
    _autoRefresh = TabAutoRefresh(
      tabIndex: widget.tabIndex,
      onRefresh: widget.onTick,
      isVisible: () => widget.visible,
    );
  }

  @override
  void dispose() {
    _autoRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  // แท็บที่เลือกอยู่เป็นสถานะ static — ต้องเริ่มแต่ละเทสต์ที่แท็บ dashboard เสมอ
  setUp(() => TabRefreshBus.select(TabRefreshBus.dashboardTab));

  Future<void> pumpHarness(
    WidgetTester tester, {
    required int tabIndex,
    required VoidCallback onTick,
    bool visible = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _TabHarness(
          tabIndex: tabIndex,
          onTick: onTick,
          visible: visible,
        ),
      ),
    );
  }

  testWidgets('แท็บที่เปิดดูอยู่ดึงข้อมูลใหม่ทุก 1 นาที', (tester) async {
    var ticks = 0;
    await pumpHarness(
      tester,
      tabIndex: TabRefreshBus.dashboardTab,
      onTick: () => ticks++,
    );

    await tester.pump(const Duration(minutes: 1));
    expect(ticks, 1);
    await tester.pump(const Duration(minutes: 1));
    expect(ticks, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('แท็บที่ไม่ได้ถูกเลือกไม่ยิงข้อมูลเลย', (tester) async {
    var ticks = 0;
    TabRefreshBus.select(TabRefreshBus.reportsTab);
    await pumpHarness(
      tester,
      tabIndex: TabRefreshBus.dashboardTab,
      onTick: () => ticks++,
    );

    await tester.pump(const Duration(minutes: 5));
    expect(ticks, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('สลับออกจากแท็บแล้วหยุด กลับเข้ามาแล้วนับรอบใหม่', (tester) async {
    var ticks = 0;
    await pumpHarness(
      tester,
      tabIndex: TabRefreshBus.dashboardTab,
      onTick: () => ticks++,
    );

    await tester.pump(const Duration(minutes: 1));
    expect(ticks, 1);

    TabRefreshBus.select(TabRefreshBus.reportsTab);
    await tester.pump(const Duration(minutes: 3));
    expect(ticks, 1, reason: 'แท็บอื่นถูกเลือกอยู่ ต้องไม่ยิงข้อมูลของแท็บนี้');

    // ตอนถูกเลือกกลับมา เวลานับหนึ่งรอบใหม่ (ไม่ตกค้างเวลาจากรอบก่อน)
    TabRefreshBus.select(TabRefreshBus.dashboardTab);
    await tester.pump(const Duration(seconds: 30));
    expect(ticks, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(ticks, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('มีหน้าอื่นทับอยู่ (มองไม่เห็น) ไม่ยิงข้อมูล', (tester) async {
    var ticks = 0;
    await pumpHarness(
      tester,
      tabIndex: TabRefreshBus.dashboardTab,
      onTick: () => ticks++,
      visible: false,
    );

    await tester.pump(const Duration(minutes: 3));
    expect(ticks, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('แอปถูกพับอยู่ ไม่ยิงข้อมูล', (tester) async {
    var ticks = 0;
    await pumpHarness(
      tester,
      tabIndex: TabRefreshBus.dashboardTab,
      onTick: () => ticks++,
    );

    // ลำดับที่ระบบส่งจริงตอนพับแอป (ส่งข้ามขั้นไม่ได้ — AppLifecycleListener
    // ตรวจลำดับในโหมด debug)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 3));
    expect(ticks, 0);

    // กลับมาเบื้องหน้าตามลำดับย้อนกลับ แล้วตัวจับเวลาต้องเริ่มนับใหม่
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(minutes: 1));
    expect(ticks, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ทิ้งหน้าจอแล้วตัวจับเวลาต้องถูกยกเลิก ไม่ยิงต่อ', (tester) async {
    var ticks = 0;
    await pumpHarness(
      tester,
      tabIndex: TabRefreshBus.dashboardTab,
      onTick: () => ticks++,
    );

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));

    expect(ticks, 0);
  });
}
