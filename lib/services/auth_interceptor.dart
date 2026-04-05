import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final _storage = const FlutterSecureStorage();
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    String? token = await _storage.read(key: 'session_token');
    print(token);

    // if (token != null && !options.path.contains('/login') && !options.path.contains('/register')) {
    //   options.headers['Authorization'] = 'Bearer $token';
    // }

    // print('➡️ ยิง API ไปที่: ${options.uri}');
    return handler.next(options);
  }
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      print('❌ Token หมดอายุ หรือ ไม่ได้รับอนุญาต!');
      await _storage.delete(key: 'token');
      
      // TODO: สั่งให้แอปเด้งกลับไปหน้า Login (มักจะเรียกผ่าน Global Navigator Key หรือ State Management)
    }
    return handler.next(err);
  }
}