import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:rampart/models/dashboard_stats.dart';
import 'package:rampart/screens/dashboard_screen.dart';
import 'package:rampart/services/tab_refresh_bus.dart';
import 'package:rampart/theme/app_theme.dart';

/// ยืนยันว่าหน้า dashboard แสดงข้อมูลที่เซิร์ฟเวอร์ส่งมาจริง
/// โดยเติมข้อมูลผ่านช่อง [DashboardScreen.load] แทนการยิงเครือข่าย
void main() {
  // แท็บที่เลือกอยู่เป็นสถานะ static ของทั้งโปรเซส — เริ่มทุกเทสต์ที่ dashboard
  setUp(() => TabRefreshBus.select(TabRefreshBus.dashboardTab));

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
          // ชุดที่สามที่ backend ส่งมา — หน้าเว็บเริ่มที่ชุดนี้
          'all': [
            {'type': 'Ransomware', 'count': 44},
          ],
        },
        // โครงจริงจากเซิร์ฟเวอร์: คะแนนรายเครื่องมือซ้อนใน `tools` และมี
        // label + จำนวนตัวอย่างติดมาด้วย
        'riskScores': [
          {
            'fileType': 'windows-exe',
            'label': 'Windows Executable',
            'riskScore': 85,
            'tools': {
              'virustotal': 60.0,
              'mobsf': null,
              'cape': null,
              'ai': 90.0,
            },
            'sampleCount': 13,
            'scoredCount': 13,
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
    // บรรทัดรองแบบเดียวกับ StatCard ของหน้าเว็บ — ดึงจาก field ที่มีอยู่แล้ว
    // ใน response เดียวกัน
    expect(find.text('สำเร็จ 90 รายการ'), findsOneWidget);
    expect(find.text('รอวิเคราะห์ 2 รายการ'), findsOneWidget);
    expect(find.text('สมาชิกที่ลงทะเบียน'), findsOneWidget);
  });

  testWidgets('แสดงรายงานสาธารณะพร้อมชิปคะแนนรายเครื่องมือ', (tester) async {
    await pumpDashboard(tester, bundle);

    expect(find.text('ไฟล์สาธารณะ (Public)'), findsOneWidget);
    expect(find.text('bank.apk'), findsOneWidget);
    expect(find.text('92/100'), findsOneWidget);
    // 85 และ 92 ตกในช่วง >= 80 -> อันตรายร้ายแรง
    expect(find.text('อันตรายร้ายแรง'), findsNWidgets(2));
    // ขนาดไฟล์ 4 MB
    expect(find.textContaining('4.00 MB'), findsOneWidget);
    // ผู้อัปโหลดมีบรรทัดของตัวเอง (วงกลมตัวอักษรแรก + ชื่อ) เหมือนการ์ดในหน้าเว็บ
    expect(find.text('analyst01'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    // สถานะใช้ข้อความไทยชุดเดียวกับแท็บอื่น ไม่ใช่ค่าดิบ 'success'
    expect(find.text('success'), findsNothing);
  });

  testWidgets('แสดงกิจกรรมล่าสุดพร้อมป้ายสถานะ', (tester) async {
    await pumpDashboard(tester, bundle);

    expect(find.text('กิจกรรมล่าสุด'), findsOneWidget);
    expect(find.text('invoice.pdf'), findsOneWidget);
    expect(find.text('update.apk'), findsOneWidget);
    // 2 ที่คือป้ายของกิจกรรม ('สำเร็จ') และป้ายของรายงานสาธารณะ ('สำเร็จ')
    expect(find.text('สำเร็จ'), findsNWidgets(2));
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

  testWidgets('แสดงคะแนนความอันตรายตามประเภทไฟล์ พร้อมค่าเฉลี่ยรายเครื่องมือ', (
    tester,
  ) async {
    await pumpDashboard(tester, bundle);

    expect(find.text('คะแนนความอันตราย'), findsOneWidget);
    // ป้ายชื่อหมวดจาก backend ไม่ใช่รหัสดิบ และต้องบอกจำนวนตัวอย่าง
    expect(find.textContaining('Windows Executable'), findsOneWidget);
    expect(find.textContaining('13/13 ไฟล์'), findsOneWidget);
    expect(find.text('85/100'), findsOneWidget);
    // คะแนนเฉลี่ยรายเครื่องมือมาจากคีย์ซ้อน `tools` ของ response จริง
    expect(find.text('VT 60'), findsOneWidget);
    expect(find.text('AI 90'), findsOneWidget);
    // ค่าเฉลี่ยคือ 85 -> ป้ายอันตรายร้ายแรง
    expect(find.text('คะแนนเฉลี่ยทั้งระบบ'), findsOneWidget);
  });

  testWidgets('สลับรายวัน/รายเดือน/ทั้งหมดเปลี่ยนรายการมัลแวร์โดยไม่ยิงซ้ำ', (
    tester,
  ) async {
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

    // เริ่มที่ชุด 'ทั้งหมด' เหมือนหน้าเว็บ — ชุดรายวันมักว่างจนดูเหมือนไม่มีข้อมูล
    expect(find.text('Ransomware'), findsWidgets);
    expect(find.text('Trojan'), findsNothing);
    expect(find.text('Spyware'), findsNothing);

    await tester.ensureVisible(find.text('รายเดือน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายเดือน'));
    await tester.pumpAndSettle();

    expect(find.text('Spyware'), findsWidgets);
    expect(find.text('Ransomware'), findsNothing);

    await tester.tap(find.text('รายวัน'));
    await tester.pumpAndSettle();

    expect(find.text('Trojan'), findsWidgets);
    expect(find.text('Adware'), findsWidgets);
    expect(find.text('Spyware'), findsNothing);

    // ข้อมูลทั้งสามชุดมาพร้อมกันแล้ว จึงต้องไม่ยิงเครือข่ายซ้ำ
    expect(callCount, 1);
  });

  testWidgets('อันดับหนึ่งของมัลแวร์ติดป้าย "พบมากที่สุด" เหมือนหน้าเว็บ', (
    tester,
  ) async {
    await pumpDashboard(tester, bundle);

    expect(find.text('พบมากที่สุด'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('ช่วงที่ไม่มีข้อมูลต้องบอกทางไปช่วงที่มีข้อมูล', (tester) async {
    final dailyEmpty = DashboardBundle.fromResponses(
      summary: {
        'success': true,
        'data': {
          'totalFiles': {'total': 0, 'success': 0, 'pending': 0, 'failed': 0},
          'userFiles': {'total': 0, 'success': 0, 'pending': 0, 'failed': 0},
          'totalUsers': 0,
          // ชุดรายวันว่างจริงเหมือนบนเซิร์ฟเวอร์ (ไม่มีสแกนวันนี้)
          'topMalwareTypes': {
            'daily': <dynamic>[],
            'monthly': [
              {'type': 'Spyware', 'count': 30},
            ],
            'all': [
              {'type': 'Ransomware', 'count': 44},
            ],
          },
          'riskScores': <dynamic>[],
        },
      },
    );
    await pumpDashboard(tester, dailyEmpty);

    // เริ่มที่ 'ทั้งหมด' ซึ่งมีข้อมูล
    expect(find.text('Ransomware'), findsWidgets);

    await tester.ensureVisible(find.text('รายวัน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายวัน'));
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบมัลแวร์จากการสแกนในวันนี้'), findsOneWidget);
    // ทั้งสองช่วงที่เหลือมีข้อมูลอย่างละ 1 ประเภท จึงต้องเสนอทั้งคู่
    expect(find.text('ดูผลรายเดือน (1 ประเภท)'), findsOneWidget);
    expect(find.text('ดูผลทั้งหมด (1 ประเภท)'), findsOneWidget);

    // กดปุ่มที่แนะนำแล้วต้องพาไปช่วงนั้นจริง (ปุ่มอยู่ท้ายหน้า ต้องเลื่อนให้เห็นก่อน)
    final hint = find.byKey(const Key('malware-range-monthly'));
    await tester.ensureVisible(hint);
    await tester.pumpAndSettle();
    await tester.tap(hint);
    await tester.pumpAndSettle();
    expect(find.text('Spyware'), findsWidgets);
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

  testWidgets('ไฟล์สาธารณะแสดงแค่หน้าละ 5 แล้วให้ดูต่อที่หน้า Public Reports', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      DashboardBundle.fromResponses(
        publicReports: fiveItemBundleResponse(),
      ),
    );

    for (var i = 0; i < 5; i++) {
      expect(find.text('public-$i.apk'), findsOneWidget);
    }
    // รายการที่ 6 อยู่หน้าสอง — ต้องไม่ถูกยัดลง dashboard
    expect(find.text('public-5.apk'), findsNothing);
    expect(find.textContaining('ทั้งหมด 12 รายการ'), findsOneWidget);

    final button = find.byKey(const Key('public-view-more'));
    await tester.ensureVisible(button);
    expect(button, findsOneWidget);
    expect(find.text('ดูทั้งหมด'), findsOneWidget);
  });

  testWidgets('กิจกรรมล่าสุดแสดงแค่ 5 รายการแรก', (tester) async {
    await pumpDashboard(
      tester,
      DashboardBundle.fromResponses(
        summary: summaryResponse(),
        recentActivities: manyActivitiesResponse(),
      ),
    );

    for (var i = 0; i < 5; i++) {
      expect(find.text('activity-$i.apk'), findsOneWidget);
    }
    expect(find.text('activity-5.apk'), findsNothing);

    // ยังมีกิจกรรมที่ไม่ได้แสดง ปุ่มพาไปแท็บ Reports ที่มีประวัติครบต้องอยู่
    final button = find.byKey(const Key('activities-view-more'));
    await tester.scrollUntilVisible(button, 300);
    expect(button, findsOneWidget);
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

  testWidgets('ปุ่มดูทั้งหมดของไฟล์สาธารณะพาไปแท็บ Public', (tester) async {
    await pumpDashboard(
      tester,
      DashboardBundle.fromResponses(publicReports: fiveItemBundleResponse()),
    );

    final button = find.byKey(const Key('public-view-more'));
    await tester.scrollUntilVisible(button, 300);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();

    expect(TabRefreshBus.currentIndex, TabRefreshBus.publicTab);
    TabRefreshBus.select(TabRefreshBus.dashboardTab);
    await tester.pumpAndSettle();
  });

  testWidgets('เปิดแท็บ dashboard ค้างไว้ 1 นาที ดึงข้อมูลใหม่เอง', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DashboardScreen(
          load: () async {
            callCount++;
            return bundle;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(callCount, 1);

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(callCount, 2, reason: 'เปิดค้างไว้ต้องรีเฟรชเองทุก 1 นาที');

    // ออกจากแท็บแล้วตัวจับเวลาต้องหยุด ไม่ยิงข้อมูลของแท็บที่ไม่ได้ดูอยู่
    TabRefreshBus.select(TabRefreshBus.reportsTab);
    await tester.pump(const Duration(minutes: 3));
    await tester.pumpAndSettle();
    expect(callCount, 2);

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
    // ข้อความว่างของ TOP 10 เปลี่ยนตามช่วงเวลาที่เลือก (เริ่มที่ 'ทั้งหมด')
    expect(find.text('ยังไม่พบมัลแวร์จากการสแกนเลย'), findsOneWidget);
    expect(find.text('ยังไม่มีไฟล์ในระบบ'), findsOneWidget);
    expect(find.text('เกิดข้อผิดพลาด'), findsNothing);

    // ตัวเลือกช่วงเวลาต้องกดได้แม้ไม่เหลือข้อมูลเลย
    await tester.ensureVisible(find.text('รายวัน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('รายวัน'));
    await tester.pumpAndSettle();
    expect(find.text('ไม่พบมัลแวร์จากการสแกนในวันนี้'), findsOneWidget);
  });
}

Map<String, dynamic> bundleResponse() => {
  'success': true,
  'data': [historyItemJson()],
};

/// payload แบบที่ endpoint `dashboard/reports` คืนจริง — หน้าแรก 5 รายการ
/// ของทั้งหมด 12 (backend จำกัด limit สูงสุด 100)
Map<String, dynamic> fiveItemBundleResponse() => {
  'success': true,
  'data': [
    for (var i = 0; i < 5; i++)
      historyItemJson(fileName: 'public-$i.apk', taskId: 'task-$i'),
  ],
  'pagination': {
    'page': 1,
    'limit': 5,
    'total': 12,
    'total_pages': 3,
    'has_next': true,
    'has_prev': false,
  },
};

/// summary ขั้นต่ำพอให้หน้า dashboard วาดส่วนกิจกรรมล่าสุดได้
Map<String, dynamic> summaryResponse() => {
  'success': true,
  'data': {
    'totalFiles': {'total': 3, 'success': 3, 'pending': 0, 'failed': 0},
    'userFiles': {'total': 1, 'success': 1, 'pending': 0, 'failed': 0},
    'totalUsers': 2,
    'topMalwareTypes': {'daily': [], 'monthly': []},
    'riskScores': <dynamic>[],
  },
};

/// backend คืนกิจกรรมล่าสุดได้ถึง 10 รายการ แต่ dashboard โชว์แค่ 5
Map<String, dynamic> manyActivitiesResponse() => {
  'success': true,
  'data': [
    for (var i = 0; i < 8; i++)
      {
        'id': '$i',
        'fileName': 'activity-$i.apk',
        'status': 'success',
        'timestamp': '2026-09-26 09:0$i',
      },
  ],
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
