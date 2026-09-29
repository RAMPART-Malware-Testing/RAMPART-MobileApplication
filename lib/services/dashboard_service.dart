import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/core/config.dart';
import 'package:rampart/models/dashboard_stats.dart';
import 'package:rampart/services/network_monitor_service.dart';
import 'package:rampart/services/offline_cache.dart';
import 'package:rampart/services/tab_cache.dart';

/// ชั้นเชื่อมต่อข้อมูลหน้า Dashboard
///
/// กฎสำคัญของ API นี้เหมือน [AnalysisService]: access token ส่งเป็น field `token`
/// ใน JSON body ทุก endpoint และ response ใช้ envelope `{success, status, message, data}`
///
/// หน้าเว็บ (`RAMPART-WebApplication`) ยิง endpoint เดียวกันนี้ผ่าน Next.js route
/// ซึ่งห่อ summary อีกชั้นหนึ่ง — [DashboardBundle.fromResponses] จึงแตก envelope ให้ทั้งสองแบบ
///
/// ไม่ throw ออกไปให้คนเรียก: จับ error แล้วคืน bundle ที่ success = false
class DashboardService {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;

  DashboardService._internal() {
    _http = Dio(
      BaseOptions(
        baseUrl: Config.url_server,
        connectTimeout: const Duration(seconds: 20),
        // summary เป็น query รวมหลายตารางและครั้งแรกหลัง cache หมดอายุจะช้ามาก
        // ถ้าตั้งสั้นเกินไป Dio จะตัดการเชื่อมต่อทิ้ง แล้วหน้าจะขึ้นว่า "เชื่อมต่อไม่ได้"
        // ทั้งที่เซิร์ฟเวอร์กำลังทำงานปกติ — ต้องรอให้พอ
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

  /// จำนวนรายงานสาธารณะที่แสดงต่อหนึ่งหน้า — หน้า dashboard โชว์ 5 อันดับแรก
  /// ส่วนที่เหลือดูต่อได้ที่หน้า "Public Reports" (backend จำกัด limit สูงสุด 100)
  static const int publicReportLimit = 5;

  /// จำนวนกิจกรรมล่าสุดที่แสดงบน dashboard — backend คืนสูงสุด 10 รายการตายตัว
  /// (endpoint `recent-activities` ไม่รับ page/limit) จึงไม่มี pagination
  /// ฝั่งเซิร์ฟเวอร์ แสดงแค่ 5 อันดับแรก ปุ่ม "ดูเพิ่มเติม" ของส่วนนี้จึงพา
  /// ไปแท็บ Reports ซึ่งมีประวัติฉบับเต็มพร้อมแบ่งหน้า
  static const int recentActivityLimit = 5;

  Future<String?> _accessToken() async {
    final token = await _storage.read(key: 'session_token');
    if (token == null || token.isEmpty || token == 'null') return null;
    return token;
  }

  /// แยก network error (ไปไม่ถึงเซิร์ฟเวอร์ -> 0) จาก error ที่เซิร์ฟเวอร์ตอบกลับ
  int _failureStatus(Object error) {
    if (error is DioException) {
      return error.response?.statusCode ?? 0;
    }
    return 0;
  }

  /// ข้อความสำหรับเคสที่คำขอไปไม่ถึงเซิร์ฟเวอร์เลย
  ///
  /// แยก timeout ออกจากเครือข่ายตาย เพราะสองอย่างนี้แก้ได้ต่างกัน —
  /// ถ้าแสดงเป็นข้อความเดียวกันผู้ใช้จะเข้าใจผิดว่าเน็ตมีปัญหา
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

  /// ดึงข้อความจากเซิร์ฟเวอร์ก่อน ถ้าไม่มีจึงใช้ข้อความไทยที่เตรียมไว้
  ///
  /// backend ตอบเป็น `{"detail": "..."}` เมื่อ token ไม่ถูกต้อง จึงต้องอ่าน `detail` ด้วย
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

  /// คืน body ดิบตามที่เซิร์ฟเวอร์ส่งมา
  ///
  /// ห้ามแปลง list ให้เป็น Map เด็ดขาด — `recent-activities` คืน array ตรง ๆ
  /// ถ้าบังคับให้เป็น Map ข้อมูลจะหายไปเงียบ ๆ แล้วหน้าจะขึ้นว่าเชื่อมต่อไม่ได้
  /// ทั้งที่เซิร์ฟเวอร์ตอบปกติ
  dynamic _asPayload(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return raw;
  }

  /// ป้ายกำกับว่า request นี้ไปไม่ถึงเซิร์ฟเวอร์เลย (ต่อไม่ติด/timeout)
  ///
  /// ใช้แยกจาก "เซิร์ฟเวอร์ตอบกลับแต่บอกว่าล้ม" เพราะสองกรณีหลังต้องไม่เอา
  /// ข้อมูลเก่ามาโชว์ — เช่น token หมดอายุ (401) ต้องให้ผู้ใช้ล็อกอินใหม่
  static const String _transportFlag = '_transport';

  bool _isTransportFailure(dynamic res) =>
      res is Map && res[_transportFlag] == true;

  Map<String, dynamic> _transportError(Object error) {
    // คำขอไปไม่ถึงเซิร์ฟเวอร์ — บอก NetworkMonitorService ให้แถบออฟไลน์ขึ้นทันที
    // ไม่ต้องรอให้ถึงรอบตรวจถัดไป (ตอนออนไลน์อยู่ตัว monitor ไม่ได้วนตรวจ)
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

  /// รายงานสาธารณะ — เรียงใหม่สุดก่อนด้วย `created_at: -1`
  ///
  /// หน้าเว็บยิง endpoint นี้โดยไม่แนบ token แต่ทุก endpoint อื่นของระบบรับ token
  /// ใน body เช่นกัน จึงส่งไปด้วย — ถ้า backend ไม่ได้ตรวจก็จะไม่รับรู้
  Future<dynamic> publicReports({
    String? token,
    int page = 1,
    int limit = publicReportLimit,
  }) async {
    try {
      final res = await _http.post(
        '/api/analy/v1/dashboard/reports',
        data: {
          'page': page,
          'limit': limit,
          'created_at': -1,
          if (token != null) 'token': token,
        },
      );
      return _asPayload(res.data);
    } catch (e) {
      return _transportError(e);
    }
  }

  /// ดึงหนึ่งหน้าของรายงานสาธารณะ — ใช้ทั้งตอนโหลดหน้าแรกและตอนกด "ดูเพิ่มเติม"
  ///
  /// ไม่ผ่านแคชใด ๆ เพราะการกดปุ่มคือความตั้งใจของผู้ใช้ที่จะได้ข้อมูลใหม่
  /// ไม่ throw — ความผิดพลาดถูกห่อไว้ใน [PublicReportsPage.error] เสมอ
  Future<PublicReportsPage> loadPublicReportsPage({
    required int page,
    int limit = publicReportLimit,
  }) async {
    final token = await _accessToken();
    final res = await publicReports(token: token, page: page, limit: limit);
    return PublicReportsPage.fromResponse(res, limit: limit);
  }

  /// ยิงทั้งสาม endpoint พร้อมกันแล้วรวมเป็นชุดเดียว
  ///
  /// [force] = true เมื่อผู้ใช้สั่งดึงเอง (ดึงลงเพื่อรีเฟรช / ปุ่มลองอีกครั้ง) — ข้ามแคช
  /// ในหน่วยความจำ ส่วนการกดแท็บใช้ค่าเริ่มต้น ซึ่งยิงเซิร์ฟเวอร์ใหม่เฉพาะตอนที่แคช
  /// ครบอายุ [TabCache.ttl] แล้วเท่านั้น
  ///
  /// เรียกแบบขนาน (R5 — batch) เพราะทั้งสามเป็นคำขอที่ไม่ต้องรอกัน และ
  /// `FlutterSecureStorage` อ่านค่า access token แค่ครั้งเดียวก่อนยิง
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

      // รู้แน่อยู่แล้วว่าเน็ตไม่ขึ้น — ข้ามการยิงที่จะรอจน timeout แล้วหยิบของเก่ามาใช้เลย
      if (!NetworkMonitorService().isOnline.value) {
        final stale = await _readCache(scope);
        if (stale != null) return stale;
      }
    }

    // ยิงทั้งสาม endpoint พร้อมกัน — ไม่ต้องรอกันเพราะไม่มี dependency ระหว่างกัน
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

    // summary คือเนื้อหาหลักของหน้า — ถ้าได้ไม่มีต้องรายงานเหตุผลเสมอ
    // ไม่ว่า endpoint อื่นจะมีข้อมูลหรือไม่ การคืน bundle ที่ error ว่างทำให้
    // หน้าจอขึ้นการ์ด "เกิดข้อผิดพลาด" แต่ไม่มีบอกว่าเพราะอะไร
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
      // ของสดจากเซิร์ฟเวอร์ — เก็บไว้ให้การกดแท็บครั้งถัดไปใน 4 วินาทีนี้ใช้ซ้ำ
      TabCache.instance.store(memoryKey, bundle);
      // และบันทึกลงดิสก์ไว้ให้ใช้ตอนออฟไลน์ ไม่ await เพราะผู้ใช้
      // ไม่ควรรอการเขียนดิสก์ก่อนเห็นหน้าจอ
      unawaited(_writeCache(scope, results));
      return bundle;
    }

    // สรุปไม่ได้ — ถ้าล้มเพราะไม่มีเน็ต (ไม่ใช่เพราะเซิร์ฟเวอร์ปฏิเสธ)
    // ให้ย้อนกลับไปใช้ของที่เคยโหลดสำเร็จ
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

    // บอกแบนเนอร์ออฟไลน์ว่านี่คือข้อมูล ณ เวลาใด
    TabCache.instance.noteSync(summary.savedAt);

    debugPrint('[cache] dashboard ใช้ข้อมูลที่บันทึกไว้ล่าสุด');
    return DashboardBundle.fromResponses(
      summary: summary.payload,
      recentActivities: entries[1]?.payload,
      publicReports: entries[2]?.payload,
    );
  }

  /// เลือกข้อความที่ตรงที่สุดจาก response ที่ล้มเหลว
  ///
  /// ลำดับความสำคัญ: ข้อความที่ชั้น service ใส่ไว้ตอน exception (ซึ่งเป็นข้อความ
  /// จริงจากเซิร์ฟเวอร์ หรือข้อความว่าติดต่อไม่ได้) -> `detail` จาก FastAPI ->
  /// ข้อความว่าไม่มีข้อมูล
  ///
  /// เคสที่ payload สำเร็จแต่อ่านไม่ออก ไม่ควรถูกรายงานว่า "เชื่อมต่อไม่ได้"
  /// เพราะทำให้ผู้ใช้ไปแก้เรื่องเน็ตทั้งที่ปัญหาอยู่ที่อื่น
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
