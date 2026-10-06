import 'package:flutter_test/flutter_test.dart';
import 'package:rampart/models/dashboard_stats.dart';

/// ล็อก contract ของ dashboard API ให้ตรงกับที่หน้าเว็บอ่านจริง
/// (ดู RAMPART-WebApplication/src/hooks/queries/useDashboard.ts)
///
/// payload ด้านล่างคัดลอกจาก response จริงของ
/// `POST /api/analy/v1/dashboard/summary` (ยิงที่ localhost:8006 ผ่าน token
/// จาก `/test/api/token`) — สำคัญ: ค่าเฉลี่ยรายเครื่องมืออยู่ใน `tools` ซ้อนกัน
/// ไม่ใช่คีย์แบน ถ้าเผลออ่านแต่คีย์แบน ชิปคะแนนจะไม่ขึ้นเลยทั้งที่ข้อมูลมา
void main() {
  group('DashboardSummary', () {
    // ตัวอย่างจริง (ตัดให้สั้น) — daily ว่าง ส่วน all กับ monthly มีข้อมูล
    Map<String, dynamic> realSummary() => {
      'totalFiles': {'total': 77, 'success': 77, 'pending': 0, 'failed': 0},
      'userFiles': {'total': 4, 'success': 4, 'pending': 0, 'failed': 0},
      'totalUsers': 2,
      'topMalwareTypes': {
        'daily': <dynamic>[],
        'monthly': [
          {'type': 'Trojan.Msil', 'count': 8},
          {'type': 'Trojan', 'count': 5},
        ],
        'all': [
          {'type': 'Trojan.Msil', 'count': 8},
          {'type': 'Trojan', 'count': 5},
        ],
      },
      'riskScores': [
        {
          'fileType': 'script',
          'label': 'Script',
          'riskScore': 92.86,
          'tools': {
            'virustotal': 100.0,
            'mobsf': null,
            'cape': null,
            'ai': null,
          },
          'sampleCount': 14,
          'scoredCount': 14,
        },
        {
          'fileType': 'windows-exe',
          'label': 'Windows Executable',
          'riskScore': 92.69,
          'tools': {
            'virustotal': 100.0,
            'mobsf': null,
            'cape': null,
            'ai': 95.0,
          },
          'sampleCount': 13,
          'scoredCount': 11,
        },
      ],
    };

    test('แปลง payload จริงของ summary ได้ครบทุก field', () {
      final summary = DashboardSummary.fromJson(realSummary());

      expect(summary.totalFiles.total, 77);
      expect(summary.totalFiles.success, 77);
      expect(summary.userFiles.total, 4);
      expect(summary.totalUsers, 2);

      expect(summary.topMalwareTypes.daily, isEmpty);
      expect(summary.topMalwareTypes.monthly.first.type, 'Trojan.Msil');
      expect(summary.topMalwareTypes.all.first.count, 8);

      final script = summary.riskScores.first;
      expect(script.fileType, 'script');
      expect(script.label, 'Script');
      expect(script.displayName, 'Script');
      expect(script.riskScore, closeTo(92.86, 0.001));
      expect(script.sampleCount, 14);
      expect(script.scoredCount, 14);

      // คะแนนรายเครื่องมืออยู่ในคีย์ซ้อน tools — และตัวที่เป็น null ต้องไม่ถูก
      // ตีความเป็น 0 แล้วโผล่เป็นชิปหลอก ๆ
      expect(script.virustotalScore, 100);
      expect(script.mobsfScore, isNull);
      expect(script.capeScore, isNull);
      expect(script.aiScore, isNull);
      expect(script.toolScores.length, 1);
      expect(script.toolScores.single.label, 'VT');

      final exe = summary.riskScores.last;
      expect(exe.aiScore, 95);
      expect(exe.toolScores.map((t) => t.label), ['VT', 'AI']);
      expect(exe.scoredCount, 11);
    });

    test('ไม่มีเครื่องมือไหนให้คะแนนเลย ต้องไม่มีชิปให้แสดง', () {
      final entry = RiskScoreEntry.fromJson({
        'fileType': 'apk',
        'label': 'Android APK',
        'riskScore': 40,
        'tools': {'virustotal': null, 'mobsf': null, 'cape': null, 'ai': null},
      });
      expect(entry.toolScores, isEmpty);
      expect(entry.displayName, 'Android APK');
    });

    test('ป้ายชื่อหมวดหายไป ใช้รหัสหมวดแทนได้', () {
      final entry = RiskScoreEntry.fromJson({'fileType': 'windows-exe'});
      expect(entry.displayName, 'windows-exe');
    });

    test('รองรับ payload คีย์แบนแบบเก่าเป็น fallback', () {
      final summary = DashboardSummary.fromJson({
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
            'riskScore': 82.5,
            'virustotalScore': 60,
            'mobsfScore': 91.2,
            'capeScore': 77,
            'rampart_ai_score': {'malware_probability': 0.83},
          },
        ],
      });

      expect(summary.totalFiles.total, 120);
      expect(summary.topMalwareTypes.forRange('monthly').first.type, 'Spyware');
      expect(summary.topMalwareTypes.forRange('daily').length, 2);

      final risk = summary.riskScores.single;
      expect(risk.fileType, 'apk');
      expect(risk.virustotalScore, 60);
      expect(risk.mobsfScore, 91.2);
      // backend ส่ง rampart_ai_score เป็น object {malware_probability: 0.83}
      // ต้องถูกคูณ 100 ให้เป็นสเกลเดียวกับเครื่องมืออื่น
      expect(risk.aiScore, 83);
      expect(risk.toolScores.length, 4);
    });

    test('forRange ที่ไม่รู้จักตกมาที่ชุดทั้งหมด ไม่ใช่ monthly', () {
      final types = TopMalwareTypes.fromJson({
        'daily': [
          {'type': 'D', 'count': 1},
        ],
        'monthly': [
          {'type': 'M', 'count': 1},
        ],
        'all': [
          {'type': 'A', 'count': 1},
        ],
      });

      expect(types.forRange('daily').single.type, 'D');
      expect(types.forRange('monthly').single.type, 'M');
      expect(types.forRange('all').single.type, 'A');
      expect(types.forRange('something-else').single.type, 'A');
    });

    test('payload ที่ไม่มีชุด all ต้องไม่ทำให้ throw', () {
      final types = TopMalwareTypes.fromJson({
        'daily': <dynamic>[],
        'monthly': <dynamic>[],
      });
      expect(types.all, isEmpty);
      expect(types.forRange('all'), isEmpty);
    });

    test('tryParse แตก envelope {success, data} ของหน้าเว็บได้', () {
      final parsed = DashboardSummary.tryParse({
        'success': true,
        'data': {
          'totalFiles': {'total': 5, 'success': 5, 'pending': 0, 'failed': 0},
          'userFiles': {'total': 1, 'success': 1, 'pending': 0, 'failed': 0},
          'totalUsers': 3,
          'topMalwareTypes': {'daily': [], 'monthly': []},
          'riskScores': <dynamic>[],
        },
      });

      expect(parsed, isNotNull);
      expect(parsed!.totalFiles.total, 5);
      expect(parsed.totalUsers, 3);
    });

    // บั๊กจริงที่เจอบนเครื่องจริง: endpoint summary ของ backend คืน dict
    // ตรง ๆ ไม่มี envelope เลย (ดู services/dashboard/dashboars_service.py
    // ที่ return dict ตรง ๆ) ถ้าเงื่อนไขเป็น "ต้องมี success == true"
    // หน้าจะว่างทั้งที่เซิร์ฟเวอร์ทำงานปกติ
    test('tryParse รับ payload ตรง ๆ ที่ไม่มี envelope ได้', () {
      final parsed = DashboardSummary.tryParse({
        'totalFiles': {'total': 9, 'success': 6, 'pending': 2, 'failed': 1},
        'userFiles': {'total': 3, 'success': 3, 'pending': 0, 'failed': 0},
        'totalUsers': 11,
        'topMalwareTypes': {
          'daily': [
            {'type': 'Trojan', 'count': 4},
          ],
          'monthly': <dynamic>[],
        },
        'riskScores': <dynamic>[],
      });

      expect(parsed, isNotNull);
      expect(parsed!.totalFiles.total, 9);
      expect(parsed.userFiles.total, 3);
      expect(parsed.totalUsers, 11);
      expect(parsed.topMalwareTypes.daily.single.type, 'Trojan');
    });

    test('tryParse คืน null เมื่อ backend บอกว่าล้มเหลว', () {
      expect(
        DashboardSummary.tryParse({'success': false, 'message': 'boom'}),
        isNull,
      );
      expect(
        DashboardSummary.tryParse({'detail': 'โทเค็นไม่ถูกต้อง'}),
        isNull,
      );
      expect(DashboardSummary.tryParse(<String, dynamic>{}), isNull);
    });

    test('เสียทุก field ที่หายหรือเป็น null ไม่ทำให้ throw', () {
      final summary = DashboardSummary.fromJson({
        'totalFiles': null,
        'userFiles': <String, dynamic>{},
        'topMalwareTypes': 'not-a-map',
        'riskScores': 'not-a-list',
      });

      expect(summary.totalFiles.resolvedTotal, 0);
      expect(summary.userFiles.success, 0);
      expect(summary.topMalwareTypes.daily, isEmpty);
      expect(summary.riskScores, isEmpty);
      expect(summary.totalUsers, 0);
    });

    test('total ที่ backend ไม่ส่ง ต้องคำนวณจากสามสถานะแทน', () {
      const counts = FileCounts(success: 3, pending: 2, failed: 1);
      expect(counts.resolvedTotal, 6);
      expect(counts.successRate, closeTo(50, 0.01));
    });

    test('successRate เป็น 0 เมื่อยังไม่มีไฟล์', () {
      expect(const FileCounts().successRate, 0);
    });
  });

  group('คะแนน ML', () {
    test('object {malware_probability} ถูกคูณ 100 เป็นสเกลเดียวกัน', () {
      final fromObject = RiskScoreEntry.fromJson({
        'fileType': 'apk',
        'riskScore': 10,
        'rampart_ai_score': {'malware_probability': 0.25},
      });
      expect(fromObject.aiScore, 25);
    });

    test('เลขล้วนถือเป็นสเกล 0-100 อยู่แล้ว ไม่คูณซ้ำ', () {
      // ตรงกับ aiChipValue() ใน useDashboard.ts ของหน้าเว็บ
      final fromPercent = RiskScoreEntry.fromJson({
        'fileType': 'apk',
        'riskScore': 10,
        'aiScore': 90,
      });
      expect(fromPercent.aiScore, 90);
    });

    test('rampart_ai_score แบบ object ต้องมี malware_probability', () {
      final missing = RiskScoreEntry.fromJson({
        'fileType': 'apk',
        'riskScore': 10,
        'rampart_ai_score': {'prediction': 'malware'},
      });
      expect(missing.aiScore, isNull);
      expect(missing.toolScores, isEmpty);
    });

    test('riskScore ถูก clamp ไว้ในช่วง 0-100', () {
      final high = RiskScoreEntry.fromJson({'riskScore': 150});
      expect(high.riskScore, 100);

      final low = RiskScoreEntry.fromJson({'riskScore': -20});
      expect(low.riskScore, 0);
    });

    test('ไม่มีคะแนนเครื่องมือเลย ต้องไม่มีชิปให้แสดง', () {
      final entry = RiskScoreEntry.fromJson({'fileType': 'exe', 'riskScore': 50});
      expect(entry.toolScores, isEmpty);
    });
  });

  group('RecentActivity', () {
    test('แปลง status เป็น enum ครบทุกค่าที่ backend ใช้', () {
      RecentActivity make(String status) => RecentActivity.fromJson({
        'id': '1',
        'fileName': 'a.apk',
        'status': status,
        'timestamp': '2026-09-26 10:00',
        'fileType': 'apk',
      });

      expect(make('success').status, ActivityStatus.success);
      // ระหว่างวิเคราะห์ status วิ่ง dispatching → queued → processing
      // ต้องไม่หล่นไป unknown
      expect(make('processing').status, ActivityStatus.processing);
      expect(make('dispatching').status, ActivityStatus.pending);
      expect(make('queued').status, ActivityStatus.pending);
      expect(make('pending').status, ActivityStatus.pending);
      expect(make('failed').status, ActivityStatus.failed);
      expect(make('weird').status, ActivityStatus.unknown);
    });

    test('รับ snake_case ได้ด้วย', () {
      final activity = RecentActivity.fromJson({
        'file_name': 'b.exe',
        'created_at': '2026-09-26 11:00',
        'file_type': 'exe',
      });
      expect(activity.fileName, 'b.exe');
      expect(activity.fileType, 'exe');
    });

    // backend ส่งเวลาเป็นสตริงที่ไม่มีโซน ("%Y-%m-%d %H:%M:%S") แต่ค่าในฐานข้อมูล
    // เป็น UTC ถ้าไม่บอกโซน เวลาจะเพี้ยนไปหลายชั่วโมง และจะไม่ตรงกับ
    // เวลาในรายงานสาธารณะที่ส่ง ISO 8601 มา
    test('เวลาที่ไม่มีโซน ต้องถูกอ่านเป็น UTC', () {
      final activity = RecentActivity.fromJson({
        'timestamp': '2026-09-25 16:16:41',
      });
      expect(activity.createdAt, isNotNull);
      expect(activity.createdAt!.isUtc, isTrue);
      expect(
        activity.createdAt!.toLocal(),
        DateTime.utc(2026, 9, 25, 16, 16, 41).toLocal(),
      );
    });

    test('เวลาที่มีโซนมาอยู่แล้วต้องไม่ถูกเลื่อนซ้ำ', () {
      final withZone = RecentActivity.fromJson({
        'timestamp': '2026-09-25T16:16:41Z',
      });
      final withoutZone = RecentActivity.fromJson({
        'timestamp': '2026-09-25 16:16:41',
      });
      expect(withZone.createdAt, withoutZone.createdAt);
    });

    test('เวลาที่ parse ไม่ได้ต้องไม่ทำให้ throw', () {
      final activity = RecentActivity.fromJson({'timestamp': 'not-a-date'});
      expect(activity.createdAt, isNull);
      expect(activity.timestamp, 'not-a-date');
    });
  });

  group('DashboardBundle.fromResponses', () {
    test('รวมข้อมูลทั้งสาม endpoint และรายงาน public', () {
      final bundle = DashboardBundle.fromResponses(
        summary: {
          'success': true,
          'data': {
            'totalFiles': {'total': 2, 'success': 2, 'pending': 0, 'failed': 0},
            'userFiles': {'total': 1, 'success': 1, 'pending': 0, 'failed': 0},
            'totalUsers': 1,
            'topMalwareTypes': {'daily': [], 'monthly': []},
            'riskScores': <dynamic>[],
          },
        },
        recentActivities: {
          'success': true,
          'data': [
            {'id': 'a', 'fileName': 'x.apk', 'status': 'success'},
          ],
        },
        publicReports: {
          'success': true,
          'data': [
            {
              'task_id': 'task-1',
              'file_name': 'x.apk',
              'file_size': 2048,
              'file_type': 'apk',
              'status': 'success',
              'created_at': '2026-09-26T09:00:00Z',
              'uploaded_by': {'username': 'analyst01'},
              'report': {
                'score': 91,
                'virustotal_score': 70,
                'rampart_ai_score': {'malware_probability': 0.95},
              },
            },
          ],
        },
      );

      expect(bundle.hasAnyData, isTrue);
      expect(bundle.summary!.totalFiles.total, 2);
      expect(bundle.recentActivities.single.fileName, 'x.apk');
      expect(bundle.publicReports.single.taskId, 'task-1');
      expect(bundle.publicReports.single.score, 91);
      expect(bundle.publicReports.single.uploadedByUsername, 'analyst01');
    });

    test('endpoint ที่ล้มเหลวไม่ทำให้ทั้ง bundle พัง', () {
      final bundle = DashboardBundle.fromResponses(
        summary: {'success': false, 'message': 'โทเค็นไม่ถูกต้อง'},
        recentActivities: null,
        publicReports: null,
      );

      expect(bundle.summary, isNull);
      expect(bundle.recentActivities, isEmpty);
      expect(bundle.publicReports, isEmpty);
      expect(bundle.hasAnyData, isFalse);
    });

    test('data ที่เป็น list เปล่าถือว่ายังมีข้อมูลอยู่', () {
      final bundle = DashboardBundle.fromResponses(
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
      expect(bundle.hasAnyData, isTrue);
    });

    // บั๊กจริงอีกอัน: recent-activities คืน array ตรง ๆ ไม่ใช่ object
    // ถ้าชั้น service บังคับแปลงทุก body ให้เป็น Map ข้อมูลจะหายทั้ง list
    // แล้วหน้าจะขึ้น "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้" ทั้งที่เซิร์ฟเวอร์ปกติ
    test('recent-activities ที่คืนเป็น list ตรง ๆ ต้องถูกอ่านได้', () {
      final bundle = DashboardBundle.fromResponses(
        recentActivities: [
          {
            'id': 'a1',
            'fileName': 'app.apk',
            'fileType': 'apk',
            'status': 'success',
            'timestamp': '2026-09-26 10:00:00',
          },
          {
            'id': 'a2',
            'fileName': 'setup.exe',
            'fileType': 'exe',
            'status': 'failed',
            'timestamp': '2026-09-26 09:00:00',
          },
        ],
      );

      expect(bundle.recentActivities.length, 2);
      expect(bundle.recentActivities.first.fileName, 'app.apk');
      expect(bundle.recentActivities.first.status, ActivityStatus.success);
      expect(bundle.recentActivities.last.status, ActivityStatus.failed);
      expect(bundle.hasAnyData, isTrue);
    });
  });
}
