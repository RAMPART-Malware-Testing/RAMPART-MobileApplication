import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/core/config.dart';
import 'package:rampart/services/offline_cache.dart';
import 'package:rampart/services/tab_cache.dart';
import 'package:rampart/services/session_guard.dart';
// import 'package:rampart/services/auth_interceptor.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  late final Dio _http;
  final _storage = const FlutterSecureStorage();

  final Map<String, dynamic> _errorResponse = {
    "success": false,
    "status": 404,
    "message": "Connect Server Error!!!",
  };

  AuthService._internal() {
    _http = Dio(
      BaseOptions(
        baseUrl: Config.url_server,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    // _http.interceptors.add(AuthInterceptor());
  }

  Map<String, dynamic> _buildHeaders({
    String? userAgent,
    String? ip,
    String? deviceToken,
  }) {
    return {
      if (userAgent != null && userAgent.isNotEmpty) "User-Agent": userAgent,
      if (ip != null && ip.isNotEmpty) "x-client-ip": ip,
      if (deviceToken != null && deviceToken.isNotEmpty)
        "deviceToken": deviceToken,
    };
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? userAgent,
    String? ip,
  }) async {
    var deviceToken = await _storage.read(key: 'deivetoken');
    try {
      final res = await _http.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
        options: Options(
          headers: _buildHeaders(
            userAgent: userAgent,
            ip: ip,
            deviceToken: deviceToken,
          ),
        ),
      );
      if (res.data != null && res.data['success'] == true) {
        if (res.data['data']['bypass_otp'] == true) {
          final data = res.data['data'];
          String accessToken = data['access_token'].toString();
          
          // รวม Keystore writes พร้อมกันลดรอบการเข้าถึง
          final writes = <Future<void>>[
            _storage.write(key: 'session_token', value: accessToken),
            _storage.write(
              key: 'data',
              value: jsonEncode(data['data'] ?? {}),
            ),
            _storage.write(key: 'session_type', value: "access"),
          ];
          
          if (data['refresh_token'] != null) {
            writes.add(_storage.write(
              key: 'refresh_token',
              value: data['refresh_token'].toString(),
            ));
          }
          
          // backend อาจคืน device_token / deviceToken / deiveToken — รองรับทุกแบบ
          final devToken = data['device_token'] ?? data['deviceToken'] ?? data['deiveToken'];
          if (devToken != null && devToken.toString().isNotEmpty) {
            writes.add(_storage.write(key: 'deivetoken', value: devToken.toString()));
          }
          
          await Future.wait(writes);
        } else if (res.data['data']['token'] != null) {
          await _storage.write(
            key: 'session_token',
            value: res.data['data']['token'].toString(),
          );
          await _storage.write(key: 'session_type', value: "login_confirm");
        }
      }
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  Future<Map<String, dynamic>> loginConfirm({
    required String token,
    required String otp,
    String? userAgent,
    String? ip,
  }) async {
    var sessionType = await _storage.read(key: 'session_type');
    if (sessionType == null || sessionType != "login_confirm") {
      return {
        "success": false,
        "status": 404,
        "message": "Type Token ไม่ถูกต้อง",
      };
    }
    try {
      final res = await _http.post(
        '/api/auth/login/confirm',
        data: {'otp': otp, 'token': token},
        options: Options(
          headers: _buildHeaders(userAgent: userAgent, ip: ip),
        ),
      );
      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'];
        if (data != null) {
          String accessToken = data['access_token'] ?? data['token'] ?? '';
          
          if (accessToken.isNotEmpty) {
            final writes = <Future<void>>[
              _storage.write(key: 'session_token', value: accessToken),
              _storage.write(
                key: 'data',
                value: jsonEncode(data['data'] ?? {}),
              ),
              _storage.write(key: 'session_type', value: "access"),
            ];
            
            String refreshToken = data['refresh_token'] ?? '';
            if (refreshToken.isNotEmpty) {
              writes.add(_storage.write(key: 'refresh_token', value: refreshToken));
            }
            
            // backend คืน deiveToken (สะกดผิด) เป็นตัว trusted device
            final devToken = data['deiveToken'] ?? data['device_token'] ?? data['deviceToken'];
            if (devToken != null && devToken.toString().isNotEmpty) {
              writes.add(_storage.write(key: 'deivetoken', value: devToken.toString()));
            }
            
            await Future.wait(writes);
          }
        }
      }
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _http.post(
        '/api/auth/register',
        data: {'username': username, 'email': email, 'password': password},
      );
      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'];

        if (data != null && data['token'] != null) {
          await _storage.write(
            key: 'session_token',
            value: data['token'].toString(),
          );
          await _storage.write(key: 'session_type', value: "register_confirm");
        }
      }
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  Future<Map<String, dynamic>> registerConfirm({
    required String token,
    required String otp,
  }) async {
    var sessionType = await _storage.read(key: 'session_type');
    if (sessionType == null || sessionType != "register_confirm") {
      return {
        "success": false,
        "status": 404,
        "message": "Type Token ไม่ถูกต้อง",
      };
    }
    try {
      final res = await _http.post(
        '/api/auth/register/confirm',
        data: {'otp': otp, 'token': token},
      );
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      final res = await _http.post(
        '/api/auth/reset-passwd',
        data: {'email': email},
      );
      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'];

        if (data != null && data['token'] != null) {
          await _storage.write(
            key: 'session_token',
            value: data['token'].toString(),
          );
          await _storage.write(
            key: 'session_type',
            value: "forgot_passwd_confirm",
          );
        }
      }
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  /// ยืนยัน OTP แล้วตั้งรหัสผ่านใหม่ — ใช้กับเส้นทาง "ลืมรหัสผ่าน" ของคนที่ยังไม่ล็อกอิน
  /// จึงต้องมี `session_type` เป็น forgot_passwd_confirm จากขั้นตอนขอ OTP ก่อน
  Future<Map<String, dynamic>> resetPasswordConfirm({
    required String token,
    required String otp,
    required String newPasswd,
  }) async {
    var sesstion_type = await _storage.read(key: 'session_type');
    if (sesstion_type == null || sesstion_type != "forgot_passwd_confirm") {
      return {
        "success": false,
        "status": 404,
        "message": "Type Token ไม่ถูกต้อง",
      };
    }
    try {
      final res = await _http.post(
        '/api/auth/reset-passwd/confirm',
        data: {'otp': otp, 'token': token, 'newPasswd': newPasswd},
      );
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  /// ตั้งรหัสผ่านใหม่ให้บัญชีที่ล็อกอินอยู่ โดยใช้ access token เป็นหลักฐานยืนยันตัวตน
  ///
  /// เป็น endpoint เดียวกับ [resetPassword] แต่คนละโหมด: ถ้าส่ง `token` (type=access)
  /// มาพร้อม `newPasswd` เซิร์ฟเวอร์จะเปลี่ยนรหัสให้ทันที ไม่ต้องยืนยัน OTP ทางอีเมล
  /// (โหมดขอ OTP ใช้เมื่อส่งแค่ email ซึ่งเป็นเส้นทางของคนที่ล็อกอินไม่ได้)
  ///
  /// ไม่แตะ token/PIN ที่เก็บไว้ — ผู้ใช้ยังอยู่ในเซสชันเดิมหลังเปลี่ยนรหัสผ่าน
  Future<Map<String, dynamic>> changePassword(String newPassword) async {
    final token = await _storage.read(key: 'session_token');
    if (token == null || token.isEmpty || token == 'null') {
      return {
        'success': false,
        'status': 'NO_SESSION',
        'message': 'ไม่พบเซสชัน กรุณาเข้าสู่ระบบใหม่',
      };
    }

    try {
      final res = await _http.post(
        '/api/auth/reset-passwd',
        data: {'token': token, 'newPasswd': newPassword},
      );
      if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
      return _errorResponse;
    } catch (e) {
      final status = _failureStatus(e);
      return {
        'success': false,
        'status': status,
        'message': status == 0
            ? 'Connect Server Error!!!'
            : _messageFrom(e, 'ไม่สามารถเปลี่ยนรหัสผ่านได้'),
      };
    }
  }

  /// ข้อความจากเซิร์ฟเวอร์เมื่อคำขอล้มเหลว (backend ส่ง `detail` ของ FastAPI มาด้วย)
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

  /// แยกสาเหตุความล้มเหลวของคำขอ refresh:
  /// - เซิร์ฟเวอร์ตอบกลับด้วย error -> คืน HTTP status code (401/403/422 ...)
  /// - ไม่ถึงเซิร์ฟเวอร์ (network/DNS/timeout/socket) หรือไม่ทราบสาเหตุ -> คืน 0
  int _failureStatus(Object error) {
    if (error is DioException) {
      final response = error.response;
      if (response != null) {
        return response.statusCode ?? 0;
      }
    }
    return 0;
  }

  Future<Map<String, dynamic>> refreshAccessToken() async {
    var sessionType = await _storage.read(key: 'session_type');
    if (sessionType == null || sessionType != "access") {
      return {
        "success": false,
        "status": 401,
        "message": "Session type mismatch or not authenticated",
      };
    }
    try {
      var refreshToken = await _storage.read(key: 'refresh_token');
      final res = await _http.post(
        '/api/auth/refresh',
        data: {if (refreshToken != null) 'refresh_token': refreshToken},
      );
      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'];
        if (data != null) {
          final writes = <Future<void>>[
            if (data['access_token'] != null)
              _storage.write(
                key: 'session_token',
                value: data['access_token'].toString(),
              ),
            if (data['refresh_token'] != null)
              _storage.write(
                key: 'refresh_token',
                value: data['refresh_token'].toString(),
              ),
          ];
          if (writes.isNotEmpty) {
            await Future.wait(writes);
          }
        }
      }
      return res.data;
    } catch (e) {
      final status = _failureStatus(e);
      return {
        "success": false,
        "status": status,
        "message": status == 0
            ? "Connect Server Error!!!"
            : "Server error HTTP $status",
      };
    }
  }

  Future<void> markAuthenticated() async {
    await _storage.write(key: 'is_authenticated', value: 'true');
  }

  /// โหลดข้อมูลผู้ใช้จาก API เพื่อยืนยันสิทธิ์เจ้าของรายงานก่อนแสดงตัวเลือก privacy
  Future<Map<String, dynamic>> getProfile() async {
    final token = await _storage.read(key: 'session_token');
    // ข้าม token ที่เป็น null หรือ string 'null' (ตรงกับ analysis_service.dart)
    if (token == null || token.isEmpty || token == 'null') return _errorResponse;
    try {
      final res = await _http.post('/api/profile', data: {'token': token});
      if (res.data is! Map) return _errorResponse;
      return Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      return _errorResponse;
    }
  }

  Future<void> registerFcmToken(String fcmToken) async {
    final accessToken = await _storage.read(key: 'session_token');
    // 'null' เป็นสตริงที่เคยถูกเขียนลงไปจริงในอดีต จึงต้องกันด้วย ไม่ใช่แค่ค่าว่าง
    if (accessToken == null || accessToken.isEmpty || accessToken == 'null') return;
    try {
      await _http.post(
        '/api/fcm/register',
        data: {'token': accessToken, 'fcm_token': fcmToken},
      );
    } catch (e) {
      print('[AUTH] FCM token registration failed: $e');
    }
  }

  /// Detach this device from push before the session is cleared.
  ///
  /// Without it the account keeps this phone's token, and whoever signs in next
  /// on the same account would receive this user's analysis results.
  Future<void> unregisterFcmToken() async {
    final accessToken = await _storage.read(key: 'session_token');
    // 'null' เป็นสตริงที่เคยถูกเขียนลงไปจริงในอดีต จึงต้องกันด้วย ไม่ใช่แค่ค่าว่าง
    if (accessToken == null || accessToken.isEmpty || accessToken == 'null') return;
    try {
      await _http.post('/api/fcm/unregister', data: {'token': accessToken});
    } catch (e) {
      print('[AUTH] FCM token unregister failed: $e');
    }
  }

  /// สถานะที่เซิร์ฟเวอร์ส่งกลับมาเมื่อ session ปัจจุบันใช้ไม่ได้แล้ว
  /// ทั้งหมดนี้ผู้ใช้ต้องเริ่มยืนยันใหม่จากหน้า login — ไม่ใช่แค่ลอง OTP ใหม่อีกครั้ง
  static const Set<String> deadSessionStatuses = {
    'TOKEN_INVALID',
    'TOKEN_WRONG_TYPE',
    'TOKEN_EXPIRED',
    'OTP_EXPIRED',
  };

  /// เซิร์ฟเวอร์ตอบ HTTP 200 แม้ session จะตายแล้ว (ไม่ throw) จึงต้องดู field `status`
  /// ใน body ไม่ใช่ HTTP status code
  static bool isDeadSession(Map<String, dynamic> res) =>
      deadSessionStatuses.contains(res['status']);

  /// ตรวจว่าบัญชีถูกระงับ — delegate ไปยัง SessionGuard เพื่อไม่ซ้ำ string literal
  static bool isAccountBanned(Map<String, dynamic>? res) =>
      SessionGuard.isBanned(res);

  /// ล้างเฉพาะ token ของขั้นตอนยืนยัน OTP ที่ค้างอยู่
  /// ไม่แตะ PIN หรือ refresh_token เพราะผู้ใช้อาจมี session ที่ใช้ได้อยู่แล้ว
  Future<void> clearStaleSession() async {
    await Future.wait([
      _storage.delete(key: 'session_token'),
      _storage.delete(key: 'session_type'),
      _storage.delete(key: 'data'),
    ]);
  }

  Future<void> clearAuthData() async {
    // ลบพร้อมกัน (Future.wait) ลดรอบการเข้าถึง Keystore
    await Future.wait([
      _storage.delete(key: 'session_token'),
      _storage.delete(key: 'refresh_token'),
      _storage.delete(key: 'session_type'),
      _storage.delete(key: 'user_pin'),
      _storage.delete(key: 'data'),
      _storage.delete(key: 'jwt_token'),
      _storage.delete(key: 'deivetoken'),
      _storage.delete(key: 'deviceToken'),
      _storage.delete(key: 'is_authenticated'),
      _storage.delete(key: 'pin_wrong_count'),
      // สวิตช์แจ้งเตือนเป็นค่าประจำเครื่อง ถ้าไม่ล้างคนถัดไปที่ล็อกอินจะไม่ได้
      // แจ้งเตือนเลยเพราะติดค่าที่คนก่อนปิดไว้
      _storage.delete(key: 'notif_enabled'),
    ]);
    // ข้อมูลที่แคชไว้เป็นของผู้ใช้คนเดิม — ต้องหายไปพร้อมกับ token
    // ไม่งั้นคนที่ล็อกอินคนถัดไปบนเครื่องเดียวกันจะเห็นประวัติของคนก่อน
    await OfflineCache.instance.clearAll();
    TabCache.instance.clear();
  }
}

final authService = AuthService();
