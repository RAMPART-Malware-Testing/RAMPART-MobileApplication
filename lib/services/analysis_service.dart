import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/core/config.dart';
import 'package:rampart/models/analysis.dart';

/// ชั้นเชื่อมต่อระบบวิเคราะห์ไฟล์ของ RAMPART
///
/// กฎสำคัญของ API นี้:
/// - access token (JWT) ส่งเป็น field `token` ใน JSON body ทุก endpoint
///   ยกเว้น upload ที่ส่งเป็น query param `?token=` และต้องใช้ upload token
///   ที่ออกโดย generate-token (อายุ 15 นาที)
/// - response ใช้ envelope {success, status, message, data}
/// - ไม่ throw ออกไปให้คนเรียก จับ error แล้วคืนผลลัพธ์ที่ success = false
///   โดยใช้ status = 0 เมื่อคำขอไปไม่ถึงเซิร์ฟเวอร์ (แนวเดียวกับ authService)
class AnalysisService {
  static final AnalysisService _instance = AnalysisService._internal();
  factory AnalysisService() => _instance;

  AnalysisService._internal() {
    _http = Dio(
      BaseOptions(
        baseUrl: Config.url_server,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  late final Dio _http;
  final _storage = const FlutterSecureStorage();

  static const String _msgNetwork = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
  static const String _msgNoSession = 'กรุณาเข้าสู่ระบบใหม่';

  /// backend จำกัดไฟล์อัปโหลดไว้ 1GB
  static const int maxUploadBytes = 1024 * 1024 * 1024;

  Future<String?> _accessToken() async {
    final token = await _storage.read(key: 'session_token');
    if (token == null || token.isEmpty || token == 'null') return null;
    return token;
  }

  /// แยก network error (ไปไม่ถึงเซิร์ฟเวอร์ -> 0) จาก error ที่เซิร์ฟเวอร์ตอบกลับ
  int _failureStatus(Object error) {
    if (error is DioException) {
      final response = error.response;
      if (response != null) return response.statusCode ?? 0;
    }
    return 0;
  }

  /// ดึงข้อความจากเซิร์ฟเวอร์ก่อน ถ้าไม่มีจึงใช้ข้อความไทยที่เตรียมไว้
  String _messageFrom(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
      }
    }
    return fallback;
  }

  /// ขอ upload token สำหรับอัปโหลดไฟล์ (อายุ 15 นาที)
  Future<UploadTokenResult> generateUploadToken() async {
    final token = await _accessToken();
    if (token == null) {
      return UploadTokenResult.failure(_msgNoSession, status: 401);
    }

    try {
      final res = await _http.post(
        '/api/analy/v1/generate-token',
        data: {'token': token},
      );

      final data = res.data;
      if (data is Map) {
        final result = UploadTokenResult.fromJson(
          Map<String, dynamic>.from(data),
        );
        if (!result.success) {
          return UploadTokenResult.failure(
            result.message.isEmpty
                ? 'ไม่สามารถสร้าง upload token ได้'
                : result.message,
            status: 400,
          );
        }
        if (result.uploadToken == null || result.uploadToken!.isEmpty) {
          return UploadTokenResult.failure(
            'ไม่สามารถสร้าง upload token ได้',
            status: 400,
          );
        }
        return result;
      }
      return UploadTokenResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      return UploadTokenResult.failure(
        status == 0
            ? _msgNetwork
            : _messageFrom(e, 'ไม่สามารถสร้าง upload token ได้'),
        status: status,
      );
    }
  }

  /// อัปโหลดไฟล์เพื่อเริ่มวิเคราะห์
  ///
  /// [onProgress] รายงานความคืบหน้าการส่งจริงเป็น byte (sent, total)
  Future<UploadResult> uploadFile({
    required File file,
    required String fileName,
    bool privacy = true,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      if (!await file.exists()) {
        return UploadResult.failure('ไม่พบไฟล์ที่เลือก');
      }

      final fileSize = await file.length();
      if (fileSize <= 0) {
        return UploadResult.failure('ไฟล์ว่างเปล่าหรือไม่ถูกต้อง', status: 400);
      }
      if (fileSize > maxUploadBytes) {
        return UploadResult.failure('ไฟล์ใหญ่เกิน 1GB', status: 413);
      }

      final tokenResult = await generateUploadToken();
      if (!tokenResult.success || tokenResult.uploadToken == null) {
        return UploadResult.failure(
          tokenResult.message,
          status: tokenResult.status,
        );
      }

      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
        'privacy': privacy ? 'true' : 'false',
      });

      final res = await _http.post(
        '/api/analy/v1/upload',
        queryParameters: {'token': tokenResult.uploadToken},
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: onProgress,
      );

      final data = res.data;
      if (data is Map) {
        final result = UploadResult.fromJson(Map<String, dynamic>.from(data));
        if (result.success && (result.taskId == null || result.taskId!.isEmpty)) {
          return UploadResult.failure('เซิร์ฟเวอร์ไม่ส่ง task_id กลับมา');
        }
        return result;
      }
      return UploadResult.failure(_msgNetwork);
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      final fallback = switch (code) {
        413 => 'ไฟล์มีขนาดใหญ่เกินไป',
        400 => 'ไฟล์ว่างเปล่าหรือไม่ถูกต้อง',
        409 => 'กำลังประมวลผลไฟล์นี้อยู่',
        503 => 'เซิร์ฟเวอร์ไม่พร้อมให้บริการ',
        _ => _msgNetwork,
      };
      return UploadResult.failure(_messageFrom(e, fallback), status: code);
    } catch (_) {
      return UploadResult.failure(_msgNetwork);
    }
  }

  /// สถานะงานวิเคราะห์ (ใช้ poll จนกว่า status จะเป็น success/failed)
  Future<TaskStatusResult> getTaskStatus(String taskId) async {
    final token = await _accessToken();
    if (token == null) {
      return TaskStatusResult.failure(_msgNoSession, httpStatus: 401);
    }

    try {
      final res = await _http.post(
        '/api/analy/v1/task_id',
        data: {'token': token, 'task_id': taskId},
      );

      final data = res.data;
      if (data is Map) {
        return TaskStatusResult.fromJson(
          Map<String, dynamic>.from(data),
          httpStatus: res.statusCode ?? 200,
        );
      }
      return TaskStatusResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      return TaskStatusResult.failure(
        status == 0
            ? _msgNetwork
            : _messageFrom(e, 'ไม่สามารถดึงสถานะการวิเคราะห์ได้'),
        httpStatus: status,
      );
    }
  }

  /// ผลวิเคราะห์ของเครื่องมือเดียว — tool ที่รับคือ virustotal/mobsf/cape/rampartai
  /// (rampart_ai จะถูกแปลงเป็น rampartai ให้อัตโนมัติ)
  Future<ToolReportResult> getToolReport({
    required String taskId,
    required String tool,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      return ToolReportResult.failure(_msgNoSession, httpStatus: 401);
    }

    try {
      final res = await _http.post(
        '/api/analy/v1/report_target',
        data: {
          'token': token,
          'task_id': taskId,
          'tool': AnalysisReport.toolRouteKey(tool),
        },
      );

      final data = res.data;
      if (data is Map) {
        final result = ToolReportResult.fromJson(
          Map<String, dynamic>.from(data),
          httpStatus: res.statusCode ?? 200,
        );
        if (!result.success) {
          return ToolReportResult.failure(
            result.message ?? 'ไม่พบรายงานของเครื่องมือนี้',
            httpStatus: result.httpStatus,
          );
        }
        return result;
      }
      return ToolReportResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      return ToolReportResult.failure(
        status == 0
            ? _msgNetwork
            : _messageFrom(e, 'ไม่สามารถดึงรายงานของเครื่องมือนี้ได้'),
        httpStatus: status,
      );
    }
  }

  /// ประวัติการวิเคราะห์ของผู้ใช้ (มี pagination)
  Future<AnalysisHistoryPage> getHistory({
    int page = 1,
    int limit = 10,
    String? s,
    String? status,
    String? fileType,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      return AnalysisHistoryPage.failure(_msgNoSession, status: 401);
    }

    final body = <String, dynamic>{
      'token': token,
      'page': page,
      'limit': limit,
    };
    if (s != null && s.isNotEmpty) body['s'] = s;
    if (status != null && status.isNotEmpty) body['status'] = status;
    if (fileType != null && fileType.isNotEmpty) body['file_type'] = fileType;

    try {
      final res = await _http.post('/api/analy/v1/history', data: body);

      final data = res.data;
      if (data is Map) {
        return AnalysisHistoryPage.fromJson(Map<String, dynamic>.from(data));
      }
      return AnalysisHistoryPage.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      return AnalysisHistoryPage.failure(
        status == 0 ? _msgNetwork : _messageFrom(e, 'ไม่สามารถดึงประวัติได้'),
        status: status,
      );
    }
  }

  /// เปลี่ยน public/private ของรายงาน
  Future<Map<String, dynamic>> updatePrivacy({
    required String taskId,
    required bool privacy,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      return {'success': false, 'status': 401, 'message': _msgNoSession};
    }

    try {
      final res = await _http.patch(
        '/api/analy/v1/$taskId/privacy',
        data: {'token': token, 'privacy': privacy},
      );

      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'success': false, 'status': 0, 'message': _msgNetwork};
    } catch (e) {
      final status = _failureStatus(e);
      return {
        'success': false,
        'status': status,
        'message': status == 0
            ? _msgNetwork
            : _messageFrom(e, 'ไม่สามารถอัปเดตความเป็นส่วนตัวได้'),
      };
    }
  }

  /// URL สำหรับดาวน์โหลดรายงานรายเครื่องมือ (ฝั่ง backend รับ token ทาง query ได้)
  Future<String> buildDownloadUrl({
    required String tool,
    required String md5,
  }) async {
    final routeTool = AnalysisReport.toolRouteKey(tool);
    final base =
        '${Config.url_server}/api/analy/v1/download/report/$routeTool-$md5.json';

    final token = await _accessToken();
    if (token == null) return base;
    return '$base?token=${Uri.encodeQueryComponent(token)}';
  }
}
