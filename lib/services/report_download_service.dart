import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../services/analysis_service.dart';
import '../services/profile_service.dart';

class DownloadProgress {
  const DownloadProgress({required this.received, required this.total});

  static const DownloadProgress zero =
      DownloadProgress(received: 0, total: -1);

  final int received;
  final int total;

  bool get isTotalKnown => total > 0;

  int? get percent =>
      isTotalKnown ? (received * 100 ~/ total).clamp(0, 100) : null;

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

  Future<DownloadOutcome> download({
    required String tool,
    required String md5,
    String? fileName,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    try {
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

      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {
      }
      dir ??= await getApplicationDocumentsDirectory();

      final targetDir = Directory('${dir.path}/rampart_reports');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final baseName = fileName?.isNotEmpty == true
          ? '$tool-$fileName-$md5.json'
          : '$tool-$md5.json';
      final sanitised = _sanitiseFileName(baseName);
      final file = File('${targetDir.path}/$sanitised');

      await file.writeAsBytes(bytes);

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

  String _sanitiseFileName(String name) {
    var clean = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    if (clean.length > 200) {
      final ext = clean.endsWith('.json') ? '.json' : '';
      clean = clean.substring(0, 200 - ext.length) + ext;
    }
    return clean;
  }

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
