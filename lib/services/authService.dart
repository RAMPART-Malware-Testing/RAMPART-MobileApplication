import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/core/config.dart';
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
        '/api/login',
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
          String accessToken = res.data['data']['access_token'].toString();
          await _storage.write(key: 'session_token', value: accessToken);
          await _storage.write(
            key: 'data',
            value: jsonEncode(res.data['data']['data'] ?? {}),
          );
          await _storage.write(key: 'session_type', value: "access");
          if (res.data['data']['refresh_token'] != null) {
            await _storage.write(
              key: 'refresh_token',
              value: res.data['data']['refresh_token'].toString(),
            );
          }
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
    var sesstion_type = await _storage.read(key: 'session_type');
    if (sesstion_type == null || sesstion_type != "login_confirm") {
      return {
        "success": false,
        "status": 404,
        "message": "Type Token ไม่ถูกต้อง",
      };
    }
    try {
      final res = await _http.post(
        '/api/login/confirm',
        data: {'otp': otp, 'token': token},
        options: Options(
          headers: _buildHeaders(userAgent: userAgent, ip: ip),
        ),
      );
      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'];
        if (data != null) {
          String accessToken = data['access_token'] ?? data['token'] ?? '';
          String refreshToken = data['refresh_token'] ?? '';
          if (accessToken.isNotEmpty) {
            await _storage.write(key: 'session_token', value: accessToken);
            if (refreshToken.isNotEmpty) {
              await _storage.write(key: 'refresh_token', value: refreshToken);
            }
            await _storage.write(
              key: 'data',
              value: jsonEncode(data['data'] ?? {}),
            );
            await _storage.write(key: 'session_type', value: "access");
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
        '/api/register',
        data: {'username': username, 'email': email, 'password': password},
      );
      print(res.data);
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
    var sesstion_type = await _storage.read(key: 'session_type');
    if (sesstion_type == null && sesstion_type != "register_confirm") {
      return {
        "success": false,
        "status": 404,
        "message": "Type Token ไม่ถูกต้อง",
      };
    }
    try {
      final res = await _http.post(
        '/api/register/confirm',
        data: {'otp': otp, 'token': token},
      );
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      final res = await _http.post('/api/reset-passwd', data: {'email': email});
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

  Future<Map<String, dynamic>> resetPasswordConfirm({
    required String token,
    required String otp,
    required String newPasswd,
  }) async {
    var sesstion_type = await _storage.read(key: 'session_type');
    if (sesstion_type == null && sesstion_type != "forgot_passwd_confirm") {
      return {
        "success": false,
        "status": 404,
        "message": "Type Token ไม่ถูกต้อง",
      };
    }
    try {
      final res = await _http.post(
        '/api/reset-passwd/confirm',
        data: {'otp': otp, 'token': token, 'newPasswd': newPasswd},
      );
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
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
        '/api/refresh-token',
        data: {if (refreshToken != null) 'refresh_token': refreshToken},
      );
      if (res.data != null && res.data['success'] == true) {
        final data = res.data['data'];
        if (data != null) {
          if (data['access_token'] != null) {
            await _storage.write(
              key: 'session_token',
              value: data['access_token'].toString(),
            );
          }
          if (data['refresh_token'] != null) {
            await _storage.write(
              key: 'refresh_token',
              value: data['refresh_token'].toString(),
            );
          }
        }
      }
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  Future<void> markAuthenticated() async {
    await _storage.write(key: 'is_authenticated', value: 'true');
  }

  Future<void> clearAuthData() async {
    await _storage.delete(key: 'session_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'session_type');
    await _storage.delete(key: 'user_pin');
    await _storage.delete(key: 'data');
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'deivetoken');
    await _storage.delete(key: 'deviceToken');
    await _storage.delete(key: 'is_authenticated');
  }
}

final authService = AuthService();
