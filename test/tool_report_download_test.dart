import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rampart/models/analysis.dart';
import 'package:rampart/screens/reports_screen.dart';
import 'package:rampart/services/report_download_service.dart';
import 'package:rampart/widgets/download_progress_dialog.dart';
import 'package:rampart/screens/tool_report_screen.dart';

/// ปุ่มดาวน์โหลด JSON อยู่ได้เฉพาะหน้ารายละเอียดของ VirusTotal / MobSF / CAPE
/// ส่วนหน้ารายงานรวม (Reports) ถูกถอดปุ่มออกแล้ว
void main() {
  tearDown(Get.reset);

  group('รองรับการดาวน์โหลด JSON', () {
    test('เครื่องมือสามตัวที่เก็บรายงานเป็นไฟล์แยกถูกรองรับ', () {
      expect(ToolReportScreen.supportsJsonDownload('virustotal'), isTrue);
      expect(ToolReportScreen.supportsJsonDownload('mobsf'), isTrue);
      expect(ToolReportScreen.supportsJsonDownload('cape'), isTrue);
    });

    test('เครื่องมือที่ไม่มีไฟล์ของตัวเองถูกปฏิเสธ', () {
      expect(ToolReportScreen.supportsJsonDownload('rampart_ai'), isFalse);
      expect(ToolReportScreen.supportsJsonDownload('rampartai'), isFalse);
      expect(ToolReportScreen.supportsJsonDownload('gemini'), isFalse);
      expect(ToolReportScreen.supportsJsonDownload(''), isFalse);
    });

    test('ช่องว่างรอบ ๆ ถูกตัดทิ้ง', () {
      expect(ToolReportScreen.supportsJsonDownload(' cape '), isTrue);
      expect(ToolReportScreen.supportsJsonDownload(' gemini '), isFalse);
    });
  });

  group('กล่องความคืบหน้า', () {
    test('เปอร์เซ็นต์มาจากขนาดไฟล์ที่เซิร์ฟเวอร์บอก', () {
      final p = DownloadProgress(received: 512, total: 2048);
      expect(p.isTotalKnown, isTrue);
      expect(p.percent, 25);
      expect(p.receivedLabel, '512 B');
      expect(p.totalLabel, '2.0 KB');
    });

    test('เซิร์ฟเวอร์ไม่บอกขนาดไฟล์ — เปอร์เซ็นต์เป็น null ไม่ใช่ 0', () {
      final p = DownloadProgress(received: 4096, total: -1);
      expect(p.isTotalKnown, isFalse);
      expect(p.percent, isNull);
      expect(p.totalLabel, isNull);
      expect(p.receivedLabel, '4.0 KB');
    });

    test('เปอร์เซ็นต์ถูกจำกัดไว้ที่ 100 ไม่ล้นเพราะไบต์เกิน', () {
      expect(
        DownloadProgress(received: 5000, total: 2048).percent,
        100,
      );
    });

    testWidgets('ขนาดไฟล์ขนาดใหญ่ใช้ MB/GB', (tester) async {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2.00 GB');
      expect(formatBytes(0), '0 B');
      expect(formatBytes(null), '0 B');
    });

    testWidgets('กล่องความคืบหน้าแสดงเปอร์เซ็นต์และอัปเดตตามค่า',
        (tester) async {
      final progress = ValueNotifier<DownloadProgress?>(null);
      addTearDown(progress.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadProgressDialog(
              title: 'กำลังดาวน์โหลดรายงาน VirusTotal',
              progress: progress,
            ),
          ),
        ),
      );

      expect(find.textContaining('กำลังรับข้อมูล'), findsOneWidget);

      progress.value = const DownloadProgress(received: 768, total: 1024);
      await tester.pump();

      expect(find.textContaining('75%'), findsOneWidget);
    });

    testWidgets('กล่องผลลัพธ์บอกว่าสำเร็จพร้อมชื่อไฟล์และขนาด',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadResultDialog(
              outcome: const DownloadOutcome(
                success: true,
                fileName: 'virustotal-sample.json',
                sizeBytes: 2048,
                path: '/storage/emulated/0/rampart/virustotal-sample.json',
                message: 'ดาวน์โหลดสำเร็จ',
              ),
            ),
          ),
        ),
      );

      expect(find.text('ดาวน์โหลดสำเร็จ'), findsOneWidget);
      expect(
        find.textContaining('บันทึกไฟล์ virustotal-sample.json (2.0 KB)'),
        findsOneWidget,
      );
      expect(
        find.text('/storage/emulated/0/rampart/virustotal-sample.json'),
        findsOneWidget,
      );
    });

    testWidgets('กล่องผลลัพธ์แบบล้มเหลวมีปุ่มลองใหม่', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadResultDialog(
              outcome: const DownloadOutcome(
                success: false,
                message: 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ (HTTP 0)',
              ),
              onRetry: () => retried++,
            ),
          ),
        ),
      );

      expect(find.text('ดาวน์โหลดไม่สำเร็จ'), findsOneWidget);
      expect(find.textContaining('HTTP 0'), findsOneWidget);

      await tester.tap(find.text('ลองใหม่'));
      await tester.pump();
      expect(retried, 1);
    });
  });

  group('หน้ารายละเอียดรายงาน', () {
    Future<void> pumpToolReport(
      WidgetTester tester, {
      required String tool,
      String? md5 = 'abc123',
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        GetMaterialApp(
          home: const SizedBox.shrink(),
          getPages: [
            GetPage(
              name: '/tool-report',
              page: () => const ToolReportScreen(),
              transition: Transition.noTransition,
            ),
          ],
        ),
      );

      Get.toNamed(
        '/tool-report',
        arguments: {
          'taskId': 'task-1',
          'tool': tool,
          'md5': md5,
          'fileName': 'sample.apk',
          'report': <String, dynamic>{'prediction': 'Malware'},
        },
      );
      await tester.pumpAndSettle();
    }

    testWidgets('RAMPART AI ไม่มีปุ่มดาวน์โหลด', (tester) async {
      await pumpToolReport(tester, tool: 'rampart_ai');

      expect(find.byIcon(Icons.download), findsNothing);
      expect(find.byTooltip('ดาวน์โหลดรายงาน'), findsNothing);
    });

    testWidgets('Gemini ไม่มีปุ่มดาวน์โหลด', (tester) async {
      await pumpToolReport(tester, tool: 'gemini');

      expect(find.byIcon(Icons.download), findsNothing);
    });

    testWidgets('CAPE มีปุ่มดาวน์โหลด', (tester) async {
      await pumpToolReport(tester, tool: 'cape');

      expect(find.byTooltip('ดาวน์โหลดรายงาน'), findsOneWidget);
    });

    testWidgets('ไม่มี md5 ก็ไม่มีปุ่มดาวน์โหลดแม้เป็นเครื่องมือที่รองรับ',
        (tester) async {
      await pumpToolReport(tester, tool: 'virustotal', md5: null);

      expect(find.byTooltip('ดาวน์โหลดรายงาน'), findsNothing);
    });
  });

  group('หน้ารายงานรวม', () {
    testWidgets('การ์ดรายงานไม่มีปุ่มดาวน์โหลดแล้ว', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        GetMaterialApp(
          home: ReportsScreen(
            loadHistory: ({
              required int page,
              required int limit,
              required String s,
              required String status,
              required String fileType,
              required String sortField,
              required int sortDirection,
              required bool force,
            }) async {
              return AnalysisHistoryPage(
                success: true,
                items: [
                  AnalysisHistoryItem.fromJson({
                    'aid': 'a1',
                    'task_id': 'task-1',
                    'file_name': 'sample.apk',
                    'file_type': 'apk',
                    'status': 'success',
                    'md5': 'abc123',
                    'tools': 'virustotal,mobsf,cape',
                  }),
                ],
                pagination: Pagination(
                  page: 1,
                  limit: 5,
                  total: 1,
                  totalPages: 1,
                  hasNext: false,
                  hasPrev: false,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('sample.apk'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });
  });
}
