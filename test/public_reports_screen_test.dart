import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rampart/models/analysis.dart';
import 'package:rampart/models/dashboard_stats.dart';
import 'package:rampart/screens/public_reports_screen.dart';
import 'package:rampart/theme/app_theme.dart';

/// ยืนยันว่าหน้า Public Reports แบ่งหน้าโดยเซิร์ฟเวอร์ ทีละ 5 รายการ
/// และไม่ปนรายการซ้ำตอนต่อหน้า
void main() {
  AnalysisHistoryItem item(String name) => AnalysisHistoryItem.fromJson({
        'task_id': 'task-$name',
        'file_name': '$name.apk',
        'file_size': 1048576,
        'file_type': 'apk',
        'status': 'success',
        'created_at': '2026-09-26T02:00:00Z',
        'uploaded_by': {'username': 'analyst01'},
        'report': {'score': 42},
      });

  /// ตัวโหลดปลอมที่บันทึกทุกคำขอ — คืนหน้าละ `limit` รายการตามที่ถาม
  PublicReportsLoader loaderFor(
    List<PublicReportsQuery> calls, {
    int total = 12,
    String error = '',
  }) {
    return (query) async {
      calls.add(query);
      if (error.isNotEmpty) return PublicReportsPage(error: error);
      final start = (query.page - 1) * query.limit;
      final names = [
        for (var i = start; i < start + query.limit && i < total; i++)
          'public-$i',
      ];
      return PublicReportsPage(
        items: names.map(item).toList(growable: false),
        hasMore: start + query.limit < total,
        total: total,
      );
    };
  }

  Future<void> pumpScreen(WidgetTester tester, PublicReportsLoader loader) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: PublicReportsScreen(loadPage: loader),
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

  testWidgets('ขอหน้าแรกมาทีละ 5 รายการ และบอกจำนวนรายการที่ดูแล้ว', (
    tester,
  ) async {
    useTallViewport(tester);
    final calls = <PublicReportsQuery>[];
    await pumpScreen(tester, loaderFor(calls));

    expect(calls.single.page, 1);
    expect(calls.single.limit, 5);
    expect(find.text('public-0.apk'), findsOneWidget);
    expect(find.text('public-4.apk'), findsOneWidget);
    expect(find.text('public-5.apk'), findsNothing);

    expect(find.text('Public Reports'), findsOneWidget);
    expect(find.textContaining('ทั้งหมด 12 รายการ'), findsOneWidget);
    expect(find.text('แสดง 5 จาก 12 รายการ • หน้า 1/3'), findsOneWidget);
    expect(find.byKey(const Key('public-reports-load-more')), findsOneWidget);
  });

  testWidgets('กดโหลดเพิ่มเติมแล้วต่อหน้า 2 ต่อท้าย ไม่ตัดของเดิมทิ้ง', (
    tester,
  ) async {
    useTallViewport(tester);
    final calls = <PublicReportsQuery>[];
    await pumpScreen(tester, loaderFor(calls));

    final button = find.byKey(const Key('public-reports-load-more'));
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(calls.last.page, 2);
    expect(calls.last.limit, 5);
    expect(find.text('public-0.apk'), findsOneWidget);
    expect(find.text('public-5.apk'), findsOneWidget);
    expect(find.text('แสดง 10 จาก 12 รายการ • หน้า 2/3'), findsOneWidget);
  });

  testWidgets('ตัดรายการที่ซ้ำก่อนต่อท้าย เพราะเซิร์ฟเวอร์แคชผลไว้ 5 วินาที', (
    tester,
  ) async {
    useTallViewport(tester);
    var call = 0;
    await pumpScreen(
      tester,
      (query) async {
        call++;
        if (call == 1) {
          return PublicReportsPage(
            items: [item('public-0'), item('public-1')],
            hasMore: true,
            total: 3,
          );
        }
        // หน้าสองตอบกลับมาซ้ำรายการเดิมหนึ่งตัว
        return PublicReportsPage(
          items: [item('public-1'), item('public-2')],
          hasMore: false,
          total: 3,
        );
      },
    );

    await tester.tap(find.byKey(const Key('public-reports-load-more')));
    await tester.pumpAndSettle();

    expect(find.text('public-1.apk'), findsOneWidget);
    expect(find.text('public-2.apk'), findsOneWidget);
    expect(find.text('แสดง 3 จาก 3 รายการ'), findsOneWidget);
  });

  testWidgets('หน้าสุดท้ายซ่อนปุ่มโหลดเพิ่มเติม', (tester) async {
    useTallViewport(tester);
    await pumpScreen(tester, loaderFor(<PublicReportsQuery>[], total: 3));

    expect(find.text('แสดง 3 จาก 3 รายการ'), findsOneWidget);
    expect(find.byKey(const Key('public-reports-load-more')), findsNothing);
  });

  testWidgets('ดึงหน้าถัดไปไม่สำเร็จ ต้องคงรายการเดิมและแจ้งเหตุผล', (
    tester,
  ) async {
    useTallViewport(tester);
    var call = 0;
    await pumpScreen(
      tester,
      (query) async {
        call++;
        if (call == 1) {
          return PublicReportsPage(
            items: [item('public-0')],
            hasMore: true,
            total: 9,
          );
        }
        return const PublicReportsPage(error: 'เซิร์ฟเวอร์ใช้เวลานานเกินกำหนด');
      },
    );

    await tester.tap(find.byKey(const Key('public-reports-load-more')));
    await tester.pumpAndSettle();

    expect(find.text('เซิร์ฟเวอร์ใช้เวลานานเกินกำหนด'), findsOneWidget);
    expect(find.text('public-0.apk'), findsOneWidget);
    // ยังมีหน้าถัดไป ปุ่มต้องกดซ้ำได้
    expect(find.byKey(const Key('public-reports-load-more')), findsOneWidget);
  });

  testWidgets('เปลี่ยนตัวกรองแล้วกลับไปเริ่มที่หน้า 1 พร้อมส่งค่าไปเซิร์ฟเวอร์', (
    tester,
  ) async {
    useTallViewport(tester);
    final calls = <PublicReportsQuery>[];
    await pumpScreen(tester, loaderFor(calls));

    // เปิดเมนูประเภทไฟล์แล้วเลือก APK
    await tester.tap(find.byTooltip('กรองตามประเภทไฟล์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('APK').last);
    await tester.pumpAndSettle();

    expect(calls.last.page, 1);
    expect(calls.last.fileType, 'apk');
    expect(find.textContaining('ประเภท: APK'), findsOneWidget);
  });

  testWidgets('เลือกสถานะแล้วส่ง status ไปกรอง และเรียงตามคะแนนได้', (
    tester,
  ) async {
    useTallViewport(tester);
    final calls = <PublicReportsQuery>[];
    await pumpScreen(tester, loaderFor(calls));

    await tester.tap(find.byTooltip('กรองตามสถานะ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('สำเร็จ').last);
    await tester.pumpAndSettle();

    expect(calls.last.page, 1);
    expect(calls.last.status, 'success');
    expect(find.textContaining('สถานะ: สำเร็จ'), findsOneWidget);

    await tester.tap(find.byTooltip('เรียงลำดับ'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ความเสี่ยง').last);
    await tester.pumpAndSettle();

    expect(calls.last.sortField, 'score');
    expect(calls.last.page, 1);
  });

  testWidgets('ค้นหาแล้วส่งคำค้นไปกับคำขอเดียวกับตัวกรองอื่น', (tester) async {
    useTallViewport(tester);
    final calls = <PublicReportsQuery>[];
    await pumpScreen(tester, loaderFor(calls));

    await tester.enterText(find.byType(TextField).first, 'invoice');
    // เดโบาวน์ชื่อไฟล์ 350 มิลลิวินาที — pumpAndSettle ไม่รอ timer ที่ยังไม่ยิงเฟรม
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(calls.last.search, 'invoice');
    expect(calls.last.page, 1);
  });

  testWidgets('ไม่มีรายงานสาธารณะต้องขึ้น empty state ไม่ใช่ error', (
    tester,
  ) async {
    await pumpScreen(tester, loaderFor(<PublicReportsQuery>[], total: 0));

    expect(find.text('ยังไม่มีรายงานสาธารณะ'), findsOneWidget);
    expect(find.byKey(const Key('public-reports-load-more')), findsNothing);
  });
}
