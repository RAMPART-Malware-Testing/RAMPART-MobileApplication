import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:rampart/models/analysis.dart';
import 'package:rampart/models/dashboard_stats.dart';
import 'package:rampart/screens/dashboard_screen.dart';
import 'package:rampart/services/tab_refresh_bus.dart';
import 'package:rampart/theme/app_theme.dart';

/// ยืนยันว่าหน้า dashboard แสดงข้อมูลที่เซิร์ฟเวอร์ส่งมาจริง
/// โดยเติมข้อมูลผ่านช่อง [DashboardScreen.load] แทนการยิงเครือข่าย
void main() {
  // payload เดียวกับที่ backend ส่งมา ตัดขาดความกำกวมเรื่องชื่อ field
  final bundle = DashboardBundle.fromResponses(
    summary: {
      'success': true,
      'data': {
        'totalFiles': {'total': 120, 'success': 90, 'pending': 20, 'failed': 10},
        'userFiles': {'total': 7, 'success': 4, 'pending': 2, 'failed': 1},
        'totalUsers': 42,
        'topMalwareTypes': {
          'daily': [
            {'type': 'Trojan', 'count': 12},
            {'type': 'Adware', 'count': 5},
          ],
          'monthly': [
            {'type': 'Spyware', 'count': 30},
          ],
        },
        'riskScores': [
          {
            'fileType': 'apk',
            'riskScore': 85,
            'virustotalScore': 60,
            'rampart_ai_score': {'malware_probability': 0.9},
          },
        ],
      },
    },
    recentActivities: {
      'success': true,
      'data': [
        {'id': '1', 'fileName': 'invoice.pdf', 'status': 'success', 'timestamp': '2026-09-26 09:00'},
        {'id': '2', 'fileName': 'update.apk', 'status': 'pending', 'timestamp': '2026-09-26 10:00'},
      ],
    },
    publicReports: {
      'success': true,
      'data': [
        {
          'task_id': 'task-1',
          'file_name': 'bank.apk',
          'file_size': 4194304,
          'file_type': 'apk',
          'status': 'success',
          'created_at': '2026-09-26T02:00:00Z',
          'uploaded_by': {'username': 'analyst01'},
          'report': {
            'score': 92,
            'virustotal_score': 70,
            'mobsf_score': 88,
            'rampart_ai_score': {'malware_probability': 0.95},
          },
        },
      ],
    },
  );

  Future<void> pumpDashboard(WidgetTester tester, DashboardBundle data) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardScreen(load: () async => data),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('แสดงการ์ดสรุปทั้งสี่ใบจากข้อมูลจริง', (tester) async {
    await pumpDashboard(tester, bundle);

    expect(find.text('ไฟล์ทั้งหมด'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('ไฟล์ของฉัน'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('ผู้ใช้งานทั้งหมด'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    // 90/120 = 75.0%
    expect(find.text('อัตราความสำเร็จ'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
  });

  testWidgets('แสดงรายงานสาธารณะพร้อมชิปคะแนนรายเครื่องมือ', (tester) async {
    await pumpDashboard(tester, bundle);

    expect(find.text('ไฟล์สาธารณะ (Public)'), findsOneWidget);
    expect(find.text('bank.apk'), findsOneWidget);
    expect(find.text('92/100'), findsOneWidget);
    // 85 และ 92 ตกในช่วง >= 80 -> อันตรายร้ายแรง
    expect(find.text('อันตรายร้ายแรง'), findsNWidgets(2));
    // ขนาดไฟล์ 4 MB และผู้อัปโหลด
    expect(find.textContaining('4.00 MB'), findsOneWidget);
    expect(find.textContaining('analyst01'), findsOneWidget);
  });

  testWidgets('แสดงกิจกรรมล่าสุดพร้อมป้ายสถานะ', (tester) async {
    await pumpDashboard(tester, bundle);

    expect(find.text('กิจกรรมล่าสุด'), findsOneWidget);
    expect(find.text('invoice.pdf'), findsOneWidget);
    expect(find.text('update.apk'), findsOneWidget);
    expect(find.text('สำเร็จ'), findsOneWidget);
    expect(find.text('รอวิเคราะห์'), findsOneWidget);
  });

  testWidgets('กิจกรรมที่กำลังวิเคราะห์แสดงป้าย กำลังวิเคราะห์ ไม่ใช่ unknown', (
    tester,
  ) async {
    // ระหว่างวิเคราะห์ backend ส่ง status = processing ซึ่งเดิมหล่นไป unknown
    final runningBundle = DashboardBundle.fromResponses(
      summary: {
        'success': true,
        'data': {
          'totalFiles': {'total': 1, 'success': 0, 'pending': 0, 'failed': 0},
          'userFiles': {'total': 1, 'success': 0, 'pending': 0, 'failed': 0},
          'totalUsers': 0,
          'topMalwareTypes': {'daily': [], 'monthly': []},
          'riskScores': <dynamic>[],
        },
      },
      recentActivities: {
        'success': true,
        'data': [
          {
            'id': '1',
            'fileName': 'sample.exe',
            'status': 'processing',
            'timestamp': '2026-09-26 09:00',
          },
        ],
      },
    );
    await pumpDashboard(tester, runningBundle);

    expect(find.text('กำลังวิเคราะห์'), findsOneWidget);
    expect(find.text('sample.exe'), findsOneWidget);
    expect(find.text('unknown'), findsNothing);
  });

  testWidgets('เวลากิจกรรมต้องแปลงเป็นเวลาท้องถิ่น ไม่ใช่สตริงดิบ', (
    tester,
  ) async {
    await pumpDashboard(tester, bundle);

    // ข้อมูลตั้งต้นส่ง '2026-09-26 10:00' ซึ่งไม่มีโซนเวลา ตาม contract ต้องอ่านเป็น UTC
    expect(find.text('2026-09-26 10:00'), findsNothing);

    final expected = DateFormat(
      'd MMM HH:mm',
    ).format(DateTime.utc(2026, 9, 26, 10, 0).toLocal());
    expect(find.text(expected), findsWidgets);
  });

  testWidgets('แสดงคะแนนความอันตรายตามประเภทไฟล์', (tester) async {
    await pumpDashboard(tester, bundle);

    expect(find.text('คะแนนความอันตราย'), findsOneWidget);
    expect(find.text('apk'), findsOneWidget);
    expect(find.text('85/100'), findsOneWidget);
    // ค่าเฉลี่ยคือ 85 -> ป้ายอันตรายร้ายแรง
    expect(find.text('คะแนนเฉลี่ยทั้งระบบ'), findsOneWidget);
  });

  testWidgets('สลับรายวัน/รายเดือนเปลี่ยนรายการมัลแวร์โดยไม่ยิงซ้ำ', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardScreen(load: () async {
          callCount++;
          return bundle;
        }),
      ),
    );
    await tester.pumpAndSettle();

    // ชื่อมัลแวร์โผล่ได้ทั้งในป้ายใต้กราฟและแถวในลิสต์ (นับแค่ว่ามี ไม่นับจำนวน
    // เพราะป้ายใต้กราฟถูกสร้างเฉพาะแท่งที่ยังอยู่ใน viewport)
    expect(find.text('Trojan'), findsWidgets);
    expect(find.text('Spyware'), findsNothing);

    await tester.ensureVisible(find.text('รายเดือน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายเดือน'));
    await tester.pumpAndSettle();

    expect(find.text('Spyware'), findsWidgets);
    expect(find.text('Trojan'), findsNothing);
    // ข้อมูลทั้งสองชุดมาพร้อมกันแล้ว จึงต้องไม่ยิงเครือข่ายซ้ำ
    expect(callCount, 1);
  });

  testWidgets('แสดง error พร้อมปุ่มลองอีกครั้งเมื่อทุก endpoint ล้ม', (tester) async {
    await pumpDashboard(
      tester,
      const DashboardBundle.empty(error: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'),
    );

    expect(find.text('เกิดข้อผิดพลาด'), findsOneWidget);
    expect(find.text('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
  });

  testWidgets('เมื่อ summary ล้ม แต่รายงานสาธารณะยังมี ต้องยังแสดงรายงานได้', (tester) async {
    final partial = DashboardBundle.fromResponses(
      publicReports: bundleResponse(),
    );
    await pumpDashboard(tester, partial);

    expect(find.text('เกิดข้อผิดพลาด'), findsOneWidget);
    expect(find.text('bank.apk'), findsOneWidget);
  });

  testWidgets('ปุ่มดูเพิ่มเติมของไฟล์สาธารณะโหลดหน้าถัดไปต่อท้าย', (tester) async {
    var requestedPage = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardScreen(
          load: () async => DashboardBundle.fromResponses(
            publicReports: paginatedBundleResponse(),
          ),
          loadMoreReports: (page) async {
            requestedPage = page;
            return PublicReportsPage(
              items: [historyItem('trojan-sample.exe')],
              hasMore: false,
              total: 2,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // หน้าแรกมี 1 รายการ + รู้ว่ายังมีหน้า 2 (has_next: true)
    expect(find.text('bank.apk'), findsOneWidget);
    expect(find.textContaining('ทั้งหมด 2 รายการ'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('public-view-more')));
    await tester.tap(find.byKey(const Key('public-view-more')));
    await tester.pumpAndSettle();

    expect(requestedPage, 2);
    expect(find.text('bank.apk'), findsOneWidget);
    expect(find.text('trojan-sample.exe'), findsOneWidget);
    // หน้าใหม่บอกว่าหมดแล้ว (hasMore: false) — ปุ่มต้องหายไป
    expect(find.byKey(const Key('public-view-more')), findsNothing);
  });

  testWidgets('กดดูเพิ่มเติมแล้วยิงไม่สำเร็จ ต้องคงรายการเดิมและขึ้น SnackBar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardScreen(
          load: () async => DashboardBundle.fromResponses(
            publicReports: paginatedBundleResponse(),
          ),
          loadMoreReports: (page) async =>
              const PublicReportsPage(error: 'เซิร์ฟเวอร์ใช้เวลานานเกินกำหนด'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('public-view-more')));
    await tester.tap(find.byKey(const Key('public-view-more')));
    await tester.pumpAndSettle();

    expect(find.text('เซิร์ฟเวอร์ใช้เวลานานเกินกำหนด'), findsOneWidget);
    // รายการเดิมยังอยู่ครบ และปุ่มยังกดซ้ำได้เพราะยังมีหน้าถัดไป
    expect(find.text('bank.apk'), findsOneWidget);
    expect(find.byKey(const Key('public-view-more')), findsOneWidget);
  });

  testWidgets('ปุ่มดูเพิ่มเติมของกิจกรรมล่าสุดพาไปแท็บรายงาน', (tester) async {
    await pumpDashboard(tester, bundle);
    TabRefreshBus.select(TabRefreshBus.dashboardTab);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('activities-view-more')),
      300,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activities-view-more')));
    await tester.pump();

    expect(TabRefreshBus.currentIndex, TabRefreshBus.reportsTab);
    TabRefreshBus.select(TabRefreshBus.dashboardTab);
    await tester.pumpAndSettle();
  });

  testWidgets('แถวไฟล์สาธารณะไม่ล้นจอแคบแม้มีชิปคะแนนครบทุกเครื่องมือ', (tester) async {
    // จอเป้าหมายคือมือถือระดับเริ่มต้นกว้าง ~360dp — ชิป 4 เครื่องมือวางใน
    // Row เดียวกับคะแนนเดิมล้นแน่นอน ต้องตัดบรรทัดด้วย Wrap แทน
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardScreen(load: () async => bundle),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('bank.apk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ถ้าไม่มีข้อมูลเลย ต้องขึ้น empty state ไม่ใช่ error', (tester) async {
    final empty = DashboardBundle.fromResponses(
      summary: {
        'success': true,
        'data': {
          'totalFiles': {'total': 0, 'success': 0, 'pending': 0, 'failed': 0},
          'userFiles': {'total': 0, 'success': 0, 'pending': 0, 'failed': 0},
          'totalUsers': 0,
          'topMalwareTypes': {'daily': [], 'monthly': []},
          'riskScores': <dynamic>[],
        },
      },
    );
    await pumpDashboard(tester, empty);

    expect(find.text('ไม่มีไฟล์'), findsOneWidget);
    expect(find.text('ยังไม่มีกิจกรรม'), findsOneWidget);
    expect(find.text('ไม่มีข้อมูลความเสี่ยง'), findsOneWidget);
    expect(find.text('ไม่มีข้อมูลในขณะนี้'), findsOneWidget);
    expect(find.text('ยังไม่มีไฟล์ในระบบ'), findsOneWidget);
    expect(find.text('เกิดข้อผิดพลาด'), findsNothing);
  });
}

Map<String, dynamic> bundleResponse() => {
  'success': true,
  'data': [historyItemJson()],
};

/// payload แบบที่ endpoint `dashboard/reports` คืนจริง — มี `pagination` ต่อท้าย
Map<String, dynamic> paginatedBundleResponse({bool hasNext = true}) => {
  'success': true,
  'data': [historyItemJson()],
  'pagination': {
    'page': 1,
    'limit': 10,
    'total': 2,
    'total_pages': 2,
    'has_next': hasNext,
    'has_prev': false,
  },
};

Map<String, dynamic> historyItemJson({
  String fileName = 'bank.apk',
  String taskId = 'task-1',
}) => {
  'task_id': taskId,
  'file_name': fileName,
  'file_size': 4194304,
  'file_type': 'apk',
  'status': 'success',
  'created_at': '2026-09-26T02:00:00Z',
  'uploaded_by': {'username': 'analyst01'},
  'report': {
    'score': 92,
    'virustotal_score': 70,
    'mobsf_score': 88,
    'rampart_ai_score': {'malware_probability': 0.95},
  },
};

/// หน้าถัดไปจากปุ่ม "ดูเพิ่มเติม" — service แปลง response แล้วคืน [PublicReportsPage]
AnalysisHistoryItem historyItem(String fileName) => AnalysisHistoryItem.fromJson(
  historyItemJson(fileName: fileName, taskId: 'task-2'),
);
