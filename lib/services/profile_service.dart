import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/core/config.dart';
import 'package:rampart/models/profile.dart';
import 'package:rampart/services/network_monitor_service.dart';
import 'package:rampart/services/offline_cache.dart';
import 'package:rampart/services/session_guard.dart';
import 'package:rampart/services/tab_cache.dart';

/// บริการจัดการโปรไฟล์ผู้ใช้และประวัติการใช้งาน
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  static ProfileService get instance => _instance;

  late final Dio _http;
  final _storage = const FlutterSecureStorage();

  RampartProfile? _cached;
  RampartProfile? get cached => _cached;

  ProfileService._internal() {
    _http = Dio(
      BaseOptions(
        baseUrl: Config.url_server,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  static const String _msgNetwork = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
  static const String _msgNoSession = 'กรุณาเข้าสู่ระบบใหม่';

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
      }
    }
    return fallback;
  }

  /// คำขอไปไม่ถึงเซิร์ฟเวอร์เลย — บอก NetworkMonitorService ให้แถบออฟไลน์ขึ้นทันที
  void _reportUnreachable(Object error) {
    if (NetworkMonitorService.isUnreachable(error)) {
      NetworkMonitorService().reportUnreachable();
    }
  }

  /// ดึงข้อมูลโปรไฟล์ผู้ใช้
  ///
  /// [force] = true เมื่อต้องการข้อมูลสดจริง ๆ (ข้ามแคชในหน่วยความจำ 4 วินาที)
  ///
  /// ตอนออฟไลน์จะคืนโปรไฟล์ที่บันทึกไว้ในดิสก์ เพื่อให้หน้า Settings ยังแสดงข้อมูล
  /// ของผู้ใช้ได้ — แบนเนอร์ด้านบนหน้าจอเป็นตัวบอกว่าข้อมูลนั้นเป็นของเก่า
  Future<ProfileResult> getProfile({bool force = false}) async {
    final token = await _accessToken();
    if (token == null) {
      return ProfileResult.failure(_msgNoSession, status: 401);
    }

    final scope = OfflineCache.scopeFor(token);
    const cacheKey = 'profile.me';
    final memoryKey = '$scope|$cacheKey';

    if (!force) {
      final cached = TabCache.instance.fresh<ProfileResult>(memoryKey);
      if (cached != null) {
        debugPrint(
          '[cache] โปรไฟล์ยังไม่ครบ ${TabCache.ttl.inSeconds} วินาที — ใช้ของเดิม',
        );
        return cached;
      }

      if (!NetworkMonitorService().isOnline.value) {
        final stale = await _cachedProfile(scope, cacheKey);
        if (stale != null) return stale;
      }
    }

    try {
      final res = await _http.post(
        '/api/profile',
        data: {'token': token},
      );

      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (SessionGuard.isBanned(map)) {
          await SessionGuard.handleBanned();
          return ProfileResult.failure('บัญชีของคุณถูกระงับ', status: 403);
        }

        final result = ProfileResult.fromJson(map);
        if (result.success && result.profile != null) {
          _cached = result.profile;
          unawaited(OfflineCache.instance.put(scope, cacheKey, map));
          TabCache.instance.store(memoryKey, result);
        }
        return result;
      }
      return ProfileResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      _reportUnreachable(e);
      if (status == 0) {
        final stale = await _cachedProfile(scope, cacheKey);
        if (stale != null) return stale;
      }
      return ProfileResult.failure(
        status == 0 ? _msgNetwork : _messageFrom(e, 'ไม่สามารถดึงข้อมูลโปรไฟล์ได้'),
        status: status,
      );
    }
  }

  /// โปรไฟล์ที่เคยดึงสำเร็จและบันทึกไว้ในดิสก์ — คืน null ถ้าไม่มีหรืออ่านไม่ได้
  Future<ProfileResult?> _cachedProfile(String scope, String cacheKey) async {
    final cached = await OfflineCache.instance.get(scope, cacheKey);
    if (cached == null || cached.payload is! Map) return null;
    final result = ProfileResult.fromJson(
      Map<String, dynamic>.from(cached.payload as Map),
    );
    if (!result.success || result.profile == null) return null;
    TabCache.instance.noteSync(cached.savedAt);
    debugPrint('[cache] โปรไฟล์ใช้ข้อมูลที่บันทึกไว้');
    return result;
  }

  /// แก้ไขชื่อผู้ใช้
  Future<ProfileResult> updateUsername(String username) async {
    final trimmed = username.trim();
    final regex = RegExp(r'^[a-zA-Z0-9_.\-\u0E00-\u0E7F]{3,50}$');

    if (!regex.hasMatch(trimmed)) {
      return ProfileResult.failure(
        'ชื่อผู้ใช้ต้องมีความยาว 3-50 ตัวอักษร และใช้ได้เฉพาะตัวอักษรไทย ตัวอักษรอังกฤษ ตัวเลข \'.\', \'_\' และ \'-\' เท่านั้น',
        status: 400,
      );
    }

    final token = await _accessToken();
    if (token == null) {
      return ProfileResult.failure(_msgNoSession, status: 401);
    }

    try {
      final res = await _http.patch(
        '/api/profile',
        data: {'token': token, 'username': trimmed},
      );

      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (SessionGuard.isBanned(map)) {
          await SessionGuard.handleBanned();
          return ProfileResult.failure('บัญชีของคุณถูกระงับ', status: 403);
        }

        final result = ProfileResult.fromJson(map);
        if (result.success && result.profile != null) {
          _cached = result.profile;
        }
        return result;
      }
      return ProfileResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      return ProfileResult.failure(
        status == 0 ? _msgNetwork : _messageFrom(e, 'ไม่สามารถแก้ไขชื่อผู้ใช้ได้'),
        status: status,
      );
    }
  }

  /// อัปโหลดรูปโปรไฟล์
  Future<ProfileResult> uploadAvatar(File file) async {
    try {
      if (!await file.exists()) {
        return ProfileResult.failure('ไม่พบไฟล์รูปภาพที่เลือก');
      }

      final fileSize = await file.length();
      if (fileSize <= 0) {
        return ProfileResult.failure('ไฟล์รูปภาพว่างเปล่า', status: 400);
      }
      if (fileSize > 5 * 1024 * 1024) {
        return ProfileResult.failure('ไฟล์รูปต้องมีขนาดไม่เกิน 5MB', status: 413);
      }

      final extension = file.path.split('.').last.toLowerCase();
      if (!{'png', 'jpg', 'jpeg', 'webp'}.contains(extension)) {
        return ProfileResult.failure(
          'รองรับเฉพาะไฟล์ PNG, JPEG และ WEBP เท่านั้น',
          status: 400,
        );
      }

      final token = await _accessToken();
      if (token == null) {
        return ProfileResult.failure(_msgNoSession, status: 401);
      }

      final form = FormData.fromMap({
        'token': token,
        'file': await MultipartFile.fromFile(file.path),
      });

      final res = await _http.post(
        '/api/profile/avatar',
        data: form,
        options: Options(sendTimeout: const Duration(minutes: 2)),
      );

      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (SessionGuard.isBanned(map)) {
          await SessionGuard.handleBanned();
          return ProfileResult.failure('บัญชีของคุณถูกระงับ', status: 403);
        }

        final result = ProfileResult.fromJson(map);
        if (result.success && result.profile != null) {
          _cached = result.profile;
        }
        return result;
      }
      return ProfileResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      return ProfileResult.failure(
        status == 0 ? _msgNetwork : _messageFrom(e, 'ไม่สามารถอัปโหลดรูปโปรไฟล์ได้'),
        status: status,
      );
    }
  }

  /// ประวัติการเข้าสู่ระบบ
  Future<LoginHistoryResult> loginHistory() async {
    final token = await _accessToken();
    if (token == null) {
      return LoginHistoryResult.failure(_msgNoSession, status: 401);
    }

    try {
      final res = await _http.post(
        '/api/profile/login-history',
        data: {'token': token},
      );

      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (SessionGuard.isBanned(map)) {
          await SessionGuard.handleBanned();
          return LoginHistoryResult.failure('บัญชีของคุณถูกระงับ', status: 403);
        }
        return LoginHistoryResult.fromJson(map);
      }
      return LoginHistoryResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      return LoginHistoryResult.failure(
        status == 0 ? _msgNetwork : _messageFrom(e, 'ไม่สามารถดึงประวัติการเข้าสู่ระบบได้'),
        status: status,
      );
    }
  }

  /// ประวัติการดาวน์โหลด
  Future<DownloadHistoryResult> downloadHistory() async {
    final token = await _accessToken();
    if (token == null) {
      return DownloadHistoryResult.failure(_msgNoSession, status: 401);
    }

    try {
      final res = await _http.post(
        '/api/profile/download-history',
        data: {'token': token},
      );

      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (SessionGuard.isBanned(map)) {
          await SessionGuard.handleBanned();
          return DownloadHistoryResult.failure('บัญชีของคุณถูกระงับ', status: 403);
        }
        return DownloadHistoryResult.fromJson(map);
      }
      return DownloadHistoryResult.failure(_msgNetwork);
    } catch (e) {
      final status = _failureStatus(e);
      return DownloadHistoryResult.failure(
        status == 0 ? _msgNetwork : _messageFrom(e, 'ไม่สามารถดึงประวัติการดาวน์โหลดได้'),
        status: status,
      );
    }
  }

  /// บันทึกการดาวน์โหลดรายงาน (เรียกโดย agent อื่น — ห้าม throw และห้ามแสดง error ให้ผู้ใช้)
  Future<bool> registerDownload({
    String? fileName,
    String? tool,
    String? md5,
  }) async {
    final token = await _accessToken();
    if (token == null) return false;

    try {
      final res = await _http.post(
        '/api/profile/download',
        data: {
          'token': token,
          if (fileName != null) 'file_name': fileName,
          if (tool != null) 'tool': tool,
          if (md5 != null) 'md5': md5,
        },
      );

      final data = res.data;
      if (data is Map) {
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// แปลง avatar_url จาก backend (รองรับทั้ง absolute และ relative)
  static String? resolveAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${Config.url_server}$raw';
  }
}
