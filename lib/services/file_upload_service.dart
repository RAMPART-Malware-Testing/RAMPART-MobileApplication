import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/file_upload.dart';

class FileUploadService {
  // TODO: เปลี่ยน base URL ตาม API server ของคุณ
  static const String baseUrl = 'https://your-api-server.com/api';

  /// Upload file พร้อมกำหนด public/private
  ///
  /// Parameters:
  /// - [file]: File object ที่จะ upload
  /// - [fileName]: ชื่อไฟล์
  /// - [isPublic]: กำหนดว่าเป็น public หรือ private (default: false = private)
  /// - [description]: คำอธิบายไฟล์ (optional)
  /// - [token]: Authentication token
  /// - [onProgress]: Callback สำหรับ progress (0.0 - 1.0)
  Future<FileUploadResponse> uploadFile({
    required File file,
    required String fileName,
    bool isPublic = false,
    String? description,
    required String token,
    Function(double)? onProgress,
  }) async {
    try {
      // ตรวจสอบว่าไฟล์มีอยู่จริง
      if (!await file.exists()) {
        throw Exception('ไฟล์ไม่พบ');
      }

      // ตรวจสอบขนาดไฟล์ (สูงสุด 100MB)
      final fileSize = await file.length();
      const maxSize = 100 * 1024 * 1024; // 100MB
      if (fileSize > maxSize) {
        throw Exception('ขนาดไฟล์เกิน 100MB');
      }

      // สร้าง multipart request
      final uri = Uri.parse('$baseUrl/files/upload');
      final request = http.MultipartRequest('POST', uri);

      // เพิ่ม headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      // เพิ่มไฟล์
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ),
      );

      // เพิ่ม fields
      request.fields['is_public'] = isPublic.toString();
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }

      // ส่ง request และติดตาม progress
      final streamedResponse = await request.send();

      // อ่าน response
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return FileUploadResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: กรุณาเข้าสู่ระบบใหม่');
      } else if (response.statusCode == 413) {
        throw Exception('ไฟล์มีขนาดใหญ่เกินไป');
      } else if (response.statusCode == 415) {
        throw Exception('ประเภทไฟล์ไม่รองรับ');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'การอัปโหลดล้มเหลว');
      }
    } on SocketException {
      throw Exception('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// ดึงรายการไฟล์ที่อัปโหลด
  Future<List<FileUploadResponse>> getUploadedFiles({
    required String token,
    bool? isPublic,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/files?page=$page&limit=$limit');

      if (isPublic != null) {
        uri = Uri.parse('$baseUrl/files?page=$page&limit=$limit&is_public=$isPublic');
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => FileUploadResponse.fromJson(item)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: กรุณาเข้าสู่ระบบใหม่');
      } else {
        throw Exception('ไม่สามารถดึงรายการไฟล์ได้');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// ลบไฟล์
  Future<void> deleteFile({
    required String fileId,
    required String token,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/files/$fileId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('ไม่สามารถลบไฟล์ได้');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  /// ตรวจสอบสถานะการวิเคราะห์
  Future<FileUploadResponse> getFileStatus({
    required String fileId,
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/files/$fileId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FileUploadResponse.fromJson(data);
      } else {
        throw Exception('ไม่สามารถดึงข้อมูลไฟล์ได้');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }
}
