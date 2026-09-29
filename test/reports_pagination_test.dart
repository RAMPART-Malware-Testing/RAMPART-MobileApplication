import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rampart/models/analysis.dart';
import 'package:rampart/screens/reports_screen.dart';
import 'package:rampart/theme/app_theme.dart';

/// ยืนยันว่าหน้า Reports แบ่งหน้าจากเซิร์ฟเวอร์จริง ทีละ 5 รายการ
/// และบอกผู้ใช้ได้ว่าดูมาแล้วกี่รายการจากทั้งหมดกี่
void main() {
  AnalysisHistoryItem item(String name) => AnalysisHistoryItem.fromJson({
        'aid': 'a-$name',
        'task_id': 'task-$name',
        'file_name': '$name.apk',
        'file_size': 1048576,
        'file_type': 'apk',
        'status': 'success',
        'created_at': '2026-09-26T02:00:00Z',
        'report': {'score': 42},
      });

  AnalysisHistoryPage pageOf(
    List<String> names, {
    required int page,
    required int total,
    required bool hasNext,
  }) {
    return AnalysisHistoryPage(
      success: true,
      items: names.map(item).toList(growable: false),
      pagination: Pagination(
        page: page,
        limit: 5,
        total: total,
        totalPages: (total / 5).ceil(),
        hasNext: hasNext,
        hasPrev: page > 1,
      ),
    );
  }

  /// ตัวโหลดปลอมที่บันทึกทุกคำขอไว้ให้เทสต์ตรวจ
  HistoryLoader loaderFor(
    List<({int page, int limit, String s})> calls, {
    int total = 12,
  }) {
    return ({
      required int page,
      required int limit,
      required String s,
      required String status,
      required String fileType,
      required String sortField,
      required int sortDirection,
      required bool force,
    }) async {
      calls.add((page: page, limit: limit, s: s));
      final start = (page - 1) * limit;
      final names = [
        for (var i = start; i < start + limit && i < total; i++) 'file-$i',
      ];
      return pageOf(
        names,
        page: page,
        total: total,
        hasNext: start + limit < total,
      );
    };
  }

  Future<void> pumpReports(WidgetTester tester, HistoryLoader loader) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ReportsScreen(loadHistory: loader),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// จอสูงพอให้การ์ด 5 ใบพร้อมท้ายรายการอยู่ในหน้าจอเดียว — ไม่ต้องเลื่อน
  /// จึงไม่ถูก auto-load ของ infinite scroll แย่งไปก่อน
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// เลื่อนลงจนสุด — `ListView.builder` สร้างเฉพาะที่มองเห็น และการเลื่อน
  /// เกือบถึงท้ายรายการจะดึงหน้าถัดไปมาเอง (infinite scroll)
  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('ขอหน้าแรกมาทีละ 5 รายการ และบอกจำนวนรายการที่ดูแล้ว', (
    tester,
  ) async {
    useTallViewport(tester);
    final calls = <({int page, int limit, String s})>[];
    await pumpReports(tester, loaderFor(calls));

    expect(calls.single.page, 1);
    expect(calls.single.limit, 5);
    expect(find.text('file-0.apk'), findsOneWidget);
    // ไม่มีรายการหน้าถัดไปทั้งที่ยังมีข้อมูล — ต้องไม่ถูกสร้างล่วงหน้า
    expect(find.text('file-5.apk'), findsNothing);

    expect(find.text('แสดง 5 จาก 12 รายการ • หน้า 1/3'), findsOneWidget);
    expect(find.byKey(const Key('reports-load-more')), findsOneWidget);
  });

  testWidgets('กดโหลดเพิ่มเติมแล้วต่อหน้า 2 ต่อท้าย ไม่ตัดของเดิมทิ้ง', (
    tester,
  ) async {
    useTallViewport(tester);
    final calls = <({int page, int limit, String s})>[];
    await pumpReports(tester, loaderFor(calls));

    final button = find.byKey(const Key('reports-load-more'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(calls.last.page, 2);
    expect(calls.last.limit, 5);
    // ของหน้าแรกยังอยู่ครบ ไม่ถูกแทนที่ด้วยหน้าสอง
    expect(find.text('file-0.apk'), findsOneWidget);
    expect(find.text('file-5.apk'), findsOneWidget);
    expect(find.text('แสดง 10 จาก 12 รายการ • หน้า 2/3'), findsOneWidget);
  });

  testWidgets('เลื่อนใกล้ท้ายรายการแล้วดึงหน้าถัดไปเอง (infinite scroll)', (
    tester,
  ) async {
    final calls = <({int page, int limit, String s})>[];
    await pumpReports(tester, loaderFor(calls));
    expect(calls, hasLength(1));

    await scrollToEnd(tester);

    // เลื่อนไปเรื่อย ๆ ต้องดึงหน้าถัดไปจนถึงรายการสุดท้าย (12 รายการ = 3 หน้า)
    expect(calls.map((c) => c.page), [1, 2, 3]);
    expect(calls.every((c) => c.limit == 5), isTrue);
    expect(find.text('แสดง 12 จาก 12 รายการ • หน้า 3/3'), findsOneWidget);
    // ถึงท้ายสุดแล้ว ปุ่มโหลดเพิ่มต้องหายไป
    expect(find.byKey(const Key('reports-load-more')), findsNothing);
  });

  testWidgets('หน้าสุดท้ายซ่อนปุ่มโหลดเพิ่มเติมและนับว่าดูครบทุกรายการ', (
    tester,
  ) async {
    final calls = <({int page, int limit, String s})>[];
    await pumpReports(tester, loaderFor(calls, total: 3));

    expect(find.text('file-0.apk'), findsOneWidget);
    expect(find.text('file-2.apk'), findsOneWidget);

    await scrollToEnd(tester);
    expect(find.text('แสดง 3 จาก 3 รายการ'), findsOneWidget);
    expect(find.byKey(const Key('reports-load-more')), findsNothing);
  });

  testWidgets('ค้นหาแล้วกลับไปเริ่มที่หน้า 1 เสมอ', (tester) async {
    final calls = <({int page, int limit, String s})>[];
    await pumpReports(tester, loaderFor(calls));

    await tester.enterText(find.byType(TextField).first, 'invoice');
    // เดโบาวน์ชื่อไฟล์ 350 มิลลิวินาที — pumpAndSettle ไม่รอ timer ที่ยังไม่ยิงเฟรม
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(calls.last.page, 1);
    expect(calls.last.s, 'invoice');
  });
}
