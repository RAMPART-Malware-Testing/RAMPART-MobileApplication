import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class RecaptchaVerifyService {
  RecaptchaVerifyService._();
  static final RecaptchaVerifyService instance = RecaptchaVerifyService._();

  static const String siteKey = '6Lf1ttUtAAAAAO-mpBGtDbbCVqKY_2M7PHRDFJc7';
  static const String _siteSecret = '6Lf1ttUtAAAAAAqdeNXxDuI8gfcWA9IBJNoLqrq1';
  static const String _verifyUrl =
      'https://www.google.com/recaptcha/api/siteverify';

  static final Dio _http = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<bool> verifyToken(String token) async {
    try {
      final res = await _http.post(
        _verifyUrl,
        data: {'secret': _siteSecret, 'response': token},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final ok = res.data is Map && res.data['success'] == true;
      if (!ok) {
        debugPrint('[RECAPTCHA] verify ไม่ผ่าน: ${res.data}');
      }
      return ok;
    } catch (e) {
      debugPrint('[RECAPTCHA] verify error: $e');
      return false;
    }
  }
}
