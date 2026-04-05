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
    String? deviceToken,
  }) async {
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
        final data = res.data['data'];

        if (data != null && data['token'] != null) {
          await _storage.write(
            key: 'session_token',
            value: data['token'].toString(),
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
    if (sesstion_type == null && sesstion_type != "login_confirm") {
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
}

final authService = AuthService();
