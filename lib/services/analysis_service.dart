import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/core/config.dart';
import 'package:rampart/models/analysis.dart';
import 'package:rampart/services/network_monitor_service.dart';
import 'package:rampart/services/offline_cache.dart';
import 'package:rampart/services/tab_cache.dart';

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

  static const int maxUploadBytes = 1024 * 1024 * 1024;

  static Future<String> computeFileSha256(File file) {
    final path = file.path;
    return Isolate.run(() async {
      final completer = Completer<String>();
      final input = crypto.sha256.startChunkedConversion(
        _DigestCollector((digest) {
          if (!completer.isCompleted) completer.complete(digest.toString());
        }),
      );
      await for (final chunk in File(path).openRead()) {
        input.add(chunk);
      }
      input.close();
      return completer.future;
    });
  }

  Future<String?> _accessToken() async {
    final token = await _storage.read(key: 'session_token');
    if (token == null || token.isEmpty || token == 'null') return null;
    return token;
  }

  int _failureStatus(Object error) {
    if (error is DioException) {
      final response = error.response;
      if (response != null) return response.statusCode ?? 0;
    }
    return 0;
  }

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

  void _reportUnreachable(Object error) {
    if (NetworkMonitorService.isUnreachable(error)) {
      NetworkMonitorService().reportUnreachable();
    }
  }

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

  Future<UploadResult?> findExistingAnalysis({
    required File file,
    required String fileName,
    required int fileSize,
    bool privacy = true,
  }) async {
    final token = await _accessToken();
    if (token == null) return null;

    try {
      final sha256 = await computeFileSha256(file);
      final res = await _http.post(
        '/api/analy/v1/check-hash',
        data: {
          'token': token,
          'sha256': sha256,
          'file_name': fileName,
          'file_size': fileSize,
          'privacy': privacy,
        },
        options: Options(receiveTimeout: const Duration(minutes: 2)),
      );

      final data = res.data;
      if (data is! Map) return null;
      final result = UploadResult.fromJson(Map<String, dynamic>.from(data));
      if (!result.success) return null;

      if (result.found != true) return null;
      if (result.taskId == null || result.taskId!.isEmpty) return null;
      return result;
    } catch (_) {
      return null;
    }
  }

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

      final existing = await findExistingAnalysis(
        file: file,
        fileName: fileName,
        fileSize: fileSize,
        privacy: privacy,
      );
      if (existing != null) return existing;

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
        if (result.success &&
            (result.taskId == null || result.taskId!.isEmpty)) {
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

  Future<TaskStatusResult> getTaskStatus(String taskId) async {
    final token = await _accessToken();
    if (token == null) {
      return TaskStatusResult.failure(_msgNoSession, httpStatus: 401);
    }

    final scope = OfflineCache.scopeFor(token);
    final cacheKey = 'analysis.task.$taskId';

    try {
      final res = await _http.post(
        '/api/analy/v1/task_id',
        data: {'token': token, 'task_id': taskId},
      );

      final data = res.data;
      if (data is Map) {
        final result = TaskStatusResult.fromJson(
          Map<String, dynamic>.from(data),
          httpStatus: res.statusCode ?? 200,
        );
        if (result.success) {
          unawaited(OfflineCache.instance.put(scope, cacheKey, data));
        }
        return result;
      }
      return TaskStatusResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      if (status == 0) {
        final cached = await _cachedTask(scope, cacheKey, taskId);
        if (cached != null) return cached;
      }
      return TaskStatusResult.failure(
        status == 0
            ? _msgNetwork
            : _messageFrom(e, 'ไม่สามารถดึงสถานะการวิเคราะห์ได้'),
        httpStatus: status,
      );
    }
  }

  Future<ToolReportResult> getToolReport({
    required String taskId,
    required String tool,
  }) async {
    final token = await _accessToken();
    if (token == null) {
      return ToolReportResult.failure(_msgNoSession, httpStatus: 401);
    }

    final routeKey = AnalysisReport.toolRouteKey(tool);
    final scope = OfflineCache.scopeFor(token);
    final cacheKey = 'analysis.tool.$taskId.$routeKey';

    try {
      final res = await _http.post(
        '/api/analy/v1/report_target',
        data: {
          'token': token,
          'task_id': taskId,
          'tool': routeKey,
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
        unawaited(OfflineCache.instance.put(scope, cacheKey, data));
        return result;
      }
      return ToolReportResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      if (status == 0) {
        final cached = await OfflineCache.instance.get(scope, cacheKey);
        if (cached != null && cached.payload is Map) {
          final result = ToolReportResult.fromJson(
            Map<String, dynamic>.from(cached.payload as Map),
            httpStatus: 200,
          );
          if (result.success) {
            debugPrint('[cache] รายงาน $routeKey ของ $taskId ใช้ข้อมูลที่บันทึกไว้');
            return result;
          }
        }
      }
      return ToolReportResult.failure(
        status == 0
            ? _msgNetwork
            : _messageFrom(e, 'ไม่สามารถดึงรายงานของเครื่องมือนี้ได้'),
        httpStatus: status,
      );
    }
  }

  Future<TaskStatusResult?> _cachedTask(
    String scope,
    String cacheKey,
    String taskId,
  ) async {
    final cached = await OfflineCache.instance.get(scope, cacheKey);
    if (cached == null || cached.payload is! Map) return null;
    final result = TaskStatusResult.fromJson(
      Map<String, dynamic>.from(cached.payload as Map),
      httpStatus: 200,
    );
    if (!result.success) return null;
    debugPrint('[cache] สถานะงาน $taskId ใช้ข้อมูลที่บันทึกไว้');
    return result;
  }

  Future<AnalysisHistoryPage> getHistory({
    int page = 1,
    int limit = 10,
    String? s,
    String? status,
    String? fileType,
    String? sortField,
    int sortDirection = -1,
    bool force = false,
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
    if (sortField != null && sortField.isNotEmpty) {
      body[sortField] = sortDirection >= 0 ? 1 : -1;
    }

    final scope = OfflineCache.scopeFor(token);
    final cacheKey = OfflineCache.normaliseKey([
      'analysis.history',
      page,
      limit,
      s,
      status,
      fileType,
      sortField,
      sortDirection,
    ]);
    final memoryKey = '$scope|$cacheKey';

    if (!force) {
      final cached = TabCache.instance.fresh<AnalysisHistoryPage>(memoryKey);
      if (cached != null) {
        debugPrint(
          '[cache] ประวัติการวิเคราะห์ยังไม่ครบ ${TabCache.ttl.inSeconds} วินาที — ใช้ของเดิม',
        );
        return cached;
      }

      if (!NetworkMonitorService().isOnline.value) {
        final stale = await _cachedHistory(scope, cacheKey);
        if (stale != null) return stale;
      }
    }

    try {
      final res = await _http.post('/api/analy/v1/history', data: body);

      final data = res.data;
      if (data is Map) {
        final result =
            AnalysisHistoryPage.fromJson(Map<String, dynamic>.from(data));
        if (result.success) {
          unawaited(OfflineCache.instance.put(scope, cacheKey, data));
          TabCache.instance.store(memoryKey, result);
        }
        return result;
      }
      return AnalysisHistoryPage.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      _reportUnreachable(e);
      if (status == 0) {
        final cached = await _cachedHistory(scope, cacheKey);
        if (cached != null) return cached;
      }
      return AnalysisHistoryPage.failure(
        status == 0 ? _msgNetwork : _messageFrom(e, 'ไม่สามารถดึงประวัติได้'),
        status: status,
      );
    }
  }

  Future<AnalysisHistoryPage?> _cachedHistory(
    String scope,
    String cacheKey,
  ) async {
    final cached = await OfflineCache.instance.get(scope, cacheKey);
    if (cached == null || cached.payload is! Map) return null;
    final result = AnalysisHistoryPage.fromJson(
      Map<String, dynamic>.from(cached.payload as Map),
    );
    if (!result.success) return null;
    TabCache.instance.noteSync(cached.savedAt);
    debugPrint('[cache] ประวัติการวิเคราะห์ใช้ข้อมูลที่บันทึกไว้');
    return result;
  }

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

class _DigestCollector implements Sink<crypto.Digest> {
  _DigestCollector(this.onDigest);

  final void Function(crypto.Digest digest) onDigest;

  @override
  void add(crypto.Digest data) {
    onDigest(data);
  }

  @override
  void close() {}
}
