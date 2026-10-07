import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/core/config.dart';
import 'package:rampart/models/dashboard_stats.dart';
import 'package:rampart/services/network_monitor_service.dart';
import 'package:rampart/services/offline_cache.dart';
import 'package:rampart/services/tab_cache.dart';

class DashboardService {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;

  DashboardService._internal() {
    _http = Dio(
      BaseOptions(
        baseUrl: Config.url_server,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
  }

  late final Dio _http;
  final _storage = const FlutterSecureStorage();

  static const String _msgNoSession = 'กรุณาเข้าสู่ระบบใหม่';
  static const String _msgNetwork = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
  static const String _msgTimeout = 'เซิร์ฟเวอร์ใช้เวลานานเกินกำหนด กรุณาลองใหม่อีกครั้ง';

  static const int publicReportLimit = 5;

  static const int recentActivityLimit = 5;

  Future<String?> _accessToken() async {
    final token = await _storage.read(key: 'session_token');
    if (token == null || token.isEmpty || token == 'null') return null;
    return token;
  }

  int _failureStatus(Object error) {
    if (error is DioException) {
      return error.response?.statusCode ?? 0;
    }
    return 0;
  }

  String _offlineMessage(Object error) {
    if (error is DioException &&
        const {
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
        }.contains(error.type)) {
      return _msgTimeout;
    }
    return _msgNetwork;
  }

  String _messageFrom(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        for (final key in const ['message', 'detail']) {
          final value = data[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    }
    return fallback;
  }

  dynamic _asPayload(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return raw;
  }

  static const String _transportFlag = '_transport';

  bool _isTransportFailure(dynamic res) =>
      res is Map && res[_transportFlag] == true;

  Map<String, dynamic> _transportError(Object error) {
    if (NetworkMonitorService.isUnreachable(error)) {
      NetworkMonitorService().reportUnreachable();
    }
    return {
      'success': false,
      'status': _failureStatus(error),
      'message': _messageFrom(error, _offlineMessage(error)),
      _transportFlag: true,
    };
  }

  Future<dynamic> summary(String token) async {
    try {
      final res = await _http.post(
        '/api/analy/v1/dashboard/summary',
        data: {'token': token},
      );
      return _asPayload(res.data);
    } catch (e) {
      return _transportError(e);
    }
  }

  Future<dynamic> recentActivities(String token) async {
    try {
      final res = await _http.post(
        '/api/analy/v1/dashboard/recent-activities',
        data: {'token': token},
      );
      return _asPayload(res.data);
    } catch (e) {
      return _transportError(e);
    }
  }

  Future<dynamic> publicReports({
    String? token,
    int page = 1,
    int limit = publicReportLimit,
    String? s,
    String? status,
    String? fileType,
    String sortField = 'created_at',
    int sortDirection = -1,
  }) async {
    try {
      final res = await _http.post(
        '/api/analy/v1/dashboard/reports',
        data: {
          'page': page,
          'limit': limit,
          if (s != null && s.isNotEmpty) 's': s,
          if (status != null && status.isNotEmpty) 'status': status,
          if (fileType != null && fileType.isNotEmpty) 'file_type': fileType,
          if (sortField.isNotEmpty) sortField: sortDirection >= 0 ? 1 : -1,
          if (token != null) 'token': token,
        },
      );
      return _asPayload(res.data);
    } catch (e) {
      return _transportError(e);
    }
  }

  Future<PublicReportsPage> loadPublicReportsPage({
    required int page,
    int limit = publicReportLimit,
    String? s,
    String? status,
    String? fileType,
    String sortField = 'created_at',
    int sortDirection = -1,
  }) async {
    final token = await _accessToken();
    final res = await publicReports(
      token: token,
      page: page,
      limit: limit,
      s: s,
      status: status,
      fileType: fileType,
      sortField: sortField,
      sortDirection: sortDirection,
    );
    return PublicReportsPage.fromResponse(res, limit: limit);
  }

  Future<DashboardBundle> loadDashboard({bool force = false}) async {
    final token = await _accessToken();
    if (token == null) {
      return const DashboardBundle.empty(error: _msgNoSession);
    }

    final scope = OfflineCache.scopeFor(token);
    final memoryKey = 'dashboard.bundle.$scope';

    if (!force) {
      final cached = TabCache.instance.fresh<DashboardBundle>(memoryKey);
      if (cached != null) {
        debugPrint(
          '[cache] dashboard ยังไม่ครบ ${TabCache.ttl.inSeconds} วินาที — ใช้ของเดิม',
        );
        return cached;
      }

      if (!NetworkMonitorService().isOnline.value) {
        final stale = await _readCache(scope);
        if (stale != null) return stale;
      }
    }

    final results = await Future.wait([
      summary(token),
      recentActivities(token),
      publicReports(token: token),
    ]);

    var bundle = DashboardBundle.fromResponses(
      summary: results[0],
      recentActivities: results[1],
      publicReports: results[2],
    );

    if (bundle.summary == null) {
      bundle = DashboardBundle(
        summary: null,
        recentActivities: bundle.recentActivities,
        publicReports: bundle.publicReports,
        error: _errorMessageFrom([results[0], results[1]]),
        hasAnyData: bundle.hasAnyData,
      );
    }

    if (bundle.summary != null) {
      TabCache.instance.store(memoryKey, bundle);
      unawaited(_writeCache(scope, results));
      return bundle;
    }

    if (_isTransportFailure(results[0])) {
      final cached = await _readCache(scope);
      if (cached != null) return cached;
    }

    return bundle;
  }

  Future<void> _writeCache(String scope, List<dynamic> results) async {
    const keys = [
      'dashboard.summary',
      'dashboard.recent_activities',
      'dashboard.public_reports',
    ];
    for (var i = 0; i < keys.length; i++) {
      if (_isTransportFailure(results[i])) continue;
      await OfflineCache.instance.put(scope, keys[i], results[i]);
    }
  }

  Future<DashboardBundle?> _readCache(String scope) async {
    const keys = [
      'dashboard.summary',
      'dashboard.recent_activities',
      'dashboard.public_reports',
    ];
    final entries = await Future.wait([
      for (final key in keys) OfflineCache.instance.get(scope, key),
    ]);

    final summary = entries[0];
    if (summary == null || summary.payload == null) return null;

    TabCache.instance.noteSync(summary.savedAt);

    debugPrint('[cache] dashboard ใช้ข้อมูลที่บันทึกไว้ล่าสุด');
    return DashboardBundle.fromResponses(
      summary: summary.payload,
      recentActivities: entries[1]?.payload,
      publicReports: entries[2]?.payload,
    );
  }

  String _errorMessageFrom(List<dynamic> responses) {
    for (final res in responses) {
      if (res is! Map) continue;
      for (final key in const ['message', 'detail']) {
        final value = res[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return 'ยังไม่มีข้อมูลสำหรับแสดงผล';
  }
}

final dashboardService = DashboardService();
