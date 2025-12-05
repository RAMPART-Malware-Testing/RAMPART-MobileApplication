import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dashboard_stats.dart';

class DashboardService {
  // TODO: เปลี่ยน base URL ตาม API server ของคุณ
  static const String baseUrl = 'https://your-api-server.com/api';

  /// ดึงข้อมูลสถิติ Dashboard
  ///
  /// Parameters:
  /// - [period]: 'daily' หรือ 'monthly' สำหรับ TOP 10 malware
  /// - [token]: Authentication token
  Future<DashboardStats> getDashboardStats({
    String period = 'monthly',
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats?period=$period'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DashboardStats.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: กรุณาเข้าสู่ระบบใหม่');
      } else {
        throw Exception('Failed to load dashboard stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading dashboard stats: $e');
    }
  }

  /// ดึงข้อมูล TOP 10 malware แยกตามช่วงเวลา
  Future<List<MalwareType>> getTopMalwareTypes({
    String period = 'monthly',
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/top-malware?period=$period'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => MalwareType.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load top malware types');
      }
    } catch (e) {
      throw Exception('Error loading top malware types: $e');
    }
  }

  /// ดึงข้อมูลสถิติไฟล์ Public
  Future<FileStats> getPublicFileStats({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/public-files'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FileStats.fromJson(data);
      } else {
        throw Exception('Failed to load public file stats');
      }
    } catch (e) {
      throw Exception('Error loading public file stats: $e');
    }
  }

  /// ดึงข้อมูลสถิติไฟล์ของผู้ใช้เอง
  Future<FileStats> getMyFileStats({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/my-files'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FileStats.fromJson(data);
      } else {
        throw Exception('Failed to load my file stats');
      }
    } catch (e) {
      throw Exception('Error loading my file stats: $e');
    }
  }
}
