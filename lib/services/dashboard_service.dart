import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/core/config.dart';

class DashboardService {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;

  late final Dio _http;
  final _storage = const FlutterSecureStorage();

  final Map<String, dynamic> _errorResponse = {
    "success": false,
    "status": 404,
    "message": "Connect Server Error!!!",
  };

  DashboardService._internal() {
    _http = Dio(
      BaseOptions(
        baseUrl: Config.url_server,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    // _http.interceptors.add(AuthInterceptor());
  }

  // Map<String, dynamic> _buildHeaders({
  //   String? userAgent,
  //   String? ip,
  //   String? deviceToken,
  // }) {
  //   return {
  //     if (userAgent != null && userAgent.isNotEmpty) "User-Agent": userAgent,
  //     if (ip != null && ip.isNotEmpty) "x-client-ip": ip,
  //     if (deviceToken != null && deviceToken.isNotEmpty)
  //       "deviceToken": deviceToken,
  //   };
  // }

  Future<Map<String, dynamic>> summary() async {
    try {
      final res = await _http.post(
        '/api/analy/v1/dashboard/summary',
        data: {},
      );
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }

  Future<Map<String, dynamic>> recentActivities() async {
    var sesstion_type = await _storage.read(key: 'session_type');
    if (sesstion_type == null && sesstion_type != "login_confirm") {
      return {
        "success": false,
        "status": 404,
        "message": "Type Token ไม่ถูกต้อง",
      };
    }
    var session_token = await _storage.read(key: 'session_token');
    try {
      final res = await _http.post(
        '/api/analy/v1/dashboard/recent-activities',
        data: {'token': session_token}
      );
      return res.data;
    } catch (e) {
      return _errorResponse;
    }
  }
}

final dashboardService = DashboardService();
