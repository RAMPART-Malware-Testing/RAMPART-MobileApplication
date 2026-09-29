import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../services/analysis_service.dart';
import '../services/profile_service.dart';

/// ความคืบหน้าการดาวน์โหลด
///
/// [total] เป็น -1 เมื่อเซิร์ฟเวอร์ไม่ส่ง `Content-Length` มา — ในกรณีนั้น
/// [percent] เป็น null และ UI ต้องแสดงแถบแบบไม่รู้ขนาดแทนตัวเลข
class DownloadProgress {
  const DownloadProgress({required this.received, required this.total});

  static const DownloadProgress zero =
      DownloadProgress(received: 0, total: -1);

  final int received;
  final int total;

  bool get isTotalKnown => total > 0;

  int? get percent =>
      isTotalKnown ? (received * 100 ~/ total).clamp(0, 100) : null;

  /// ขนาดไบต์เป็น KB/MB — โครงสร้างเดียวกับหน้าอื่น
  String get receivedLabel => formatBytes(received);
  String? get totalLabel => isTotalKnown ? formatBytes(total) : null;
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// ผลการดาวน์โหลด
class DownloadOutcome {
  const DownloadOutcome({
    required this.success,
    this.path,
    this.fileName,
    this.sizeBytes,
    required this.message,
  });

  final bool success;
  final String? path;
  final String? fileName;
  final int? sizeBytes;
  final String message;
}

/// Service สำหรับดาวน์โหลดรายงาน JSON ของแต่ละเครื่องมือ
class ReportDownloadService {
  static final ReportDownloadService _instance =
      ReportDownloadService._internal();
  static ReportDownloadService get instance => _instance;

  factory ReportDownloadService() => _instance;

  ReportDownloadService._internal() {
    _http = Dio(
      BaseOptions(
        receiveTimeout: const Duration(minutes: 2),
        connectTimeout: const Duration(seconds: 30),
      ),
    );
  }

  late final Dio _http;

  /// ดาวน์โหลดรายงาน JSON แล้วบันทึกลงเครื่อง + แจ้ง backend ว่าดาวน์โหลดแล้ว
  ///
  /// [onProgress] เรียกทุกครั้งที่รับข้อมูลเข้ามา เพื่อให้ UI รายงานเปอร์เซ็นต์ได้
  /// ถ้าเซิร์ฟเวอร์ไม่บอกขนาดไฟล์ [DownloadProgress.percent] จะเป็น null
  Future<DownloadOutcome> download({
    required String tool,
    required String md5,
    String? fileName,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    try {
      // สร้าง URL ด้วย helper ที่เติม token ให้
      final url = await AnalysisService().buildDownloadUrl(
        tool: tool,
        md5: md5,
      );

      onProgress?.call(DownloadProgress.zero);

      final response = await _http.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          onProgress?.call(DownloadProgress(received: received, total: total));
        },
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        return DownloadOutcome(
          success: false,
          fileName: fileName,
          message: 'ไม่พบรายงานนี้ในเซิร์ฟเวอร์ (HTTP $statusCode)',
        );
      }

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return DownloadOutcome(
          success: false,
          fileName: fileName,
          message: 'ไฟล์รายงานว่างเปล่า',
        );
      }

      // หาที่เก็บไฟล์ — ลอง external ก่อน (accessible จาก file manager)
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {
        // ถ้าไม่ได้ fallback เป็น app documents
      }
      dir ??= await getApplicationDocumentsDirectory();

      final targetDir = Directory('${dir.path}/rampart_reports');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // สร้างชื่อไฟล์ แล้ว sanitise
      final baseName = fileName?.isNotEmpty == true
          ? '$tool-$fileName-$md5.json'
          : '$tool-$md5.json';
      final sanitised = _sanitiseFileName(baseName);
      final file = File('${targetDir.path}/$sanitised');

      await file.writeAsBytes(bytes);

      // แจ้ง backend ว่าดาวน์โหลดแล้ว (fire-and-forget, ไม่ await)
      _registerDownload(fileName: fileName, tool: tool, md5: md5);

      return DownloadOutcome(
        success: true,
        path: file.path,
        fileName: sanitised,
        sizeBytes: bytes.length,
        message: 'ดาวน์โหลดสำเร็จ',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status >= 400 && status < 500) {
        return DownloadOutcome(
          success: false,
          fileName: fileName,
          message: 'ไม่พบรายงานนี้ในเซิร์ฟเวอร์ (HTTP $status)',
        );
      }
      return DownloadOutcome(
        success: false,
        fileName: fileName,
        message: 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ (HTTP $status)',
      );
    } catch (e) {
      return DownloadOutcome(
        success: false,
        fileName: fileName,
        message: 'เกิดข้อผิดพลาด: ${e.toString()}',
      );
    }
  }

  /// ตัดอักขระที่ผิดกฎ + จำกัดความยาว
  String _sanitiseFileName(String name) {
    // ตัด path separator และอักขระที่ห้ามบน Android/iOS
    var clean = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    // จำกัดความยาวไว้ 200 ตัวอักษร
    if (clean.length > 200) {
      final ext = clean.endsWith('.json') ? '.json' : '';
      clean = clean.substring(0, 200 - ext.length) + ext;
    }
    return clean;
  }

  /// แจ้ง backend ว่าดาวน์โหลดแล้ว — fire-and-forget ห้าม await
  /// ประวัติการดาวน์โหลดเป็นข้อมูลประกอบ ไม่ควรทำให้การดาวน์โหลดที่สำเร็จแล้วดูเหมือนล้มเหลว
  void _registerDownload({
    String? fileName,
    required String tool,
    required String md5,
  }) {
    unawaited(
      ProfileService.instance
          .registerDownload(fileName: fileName, tool: tool, md5: md5),
    );
  }
}
