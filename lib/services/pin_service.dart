import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PINService extends GetxService {
  final _storage = const FlutterSecureStorage();
  String initialRoute = '/login';

  Future<PINService> init() async {
    await checkLoginStatus();
    return this;
  }

  Future<void> checkLoginStatus() async {
    String? refreshToken = await _storage.read(key: 'refresh_token');
    String? hasPin = await _storage.read(key: 'user_pin');

    if (refreshToken != null) {
      initialRoute = (hasPin != null) ? '/pin-verify' : '/home';
    } else {
      initialRoute = '/login';
    }
  }
}