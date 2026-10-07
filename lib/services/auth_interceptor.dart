import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final _storage = const FlutterSecureStorage();
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    String? token = await _storage.read(key: 'session_token');
    print(token);


    return handler.next(options);
  }
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      print('❌ Token หมดอายุ หรือ ไม่ได้รับอนุญาต!');
      await _storage.delete(key: 'token');

    }
    return handler.next(err);
  }
}
