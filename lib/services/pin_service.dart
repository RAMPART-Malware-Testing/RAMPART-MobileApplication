import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PINService extends GetxService {
  final _storage = const FlutterSecureStorage();
  String initialRoute = '/login';
  final isLocked = false.obs;

  Future<PINService> init() async {
    await checkLoginStatus();
    return this;
  }

  Future<void> checkLoginStatus() async {
    String? refreshToken = await _storage.read(key: 'refresh_token');
    String? sessionToken = await _storage.read(key: 'session_token');
    String? hasPin = await _storage.read(key: 'user_pin');

    bool hasValidSession = refreshToken != null ||
        (sessionToken != null && sessionToken != 'null' && sessionToken.isNotEmpty);

    if (!hasValidSession) {
      initialRoute = '/login';
    } else if (hasPin != null) {
      initialRoute = '/pin-verify';
    } else {
      initialRoute = '/home';
    }
  }

  void lock() {
    isLocked.value = true;
  }

  void unlock() {
    isLocked.value = false;
  }

  Future<void> evaluateLockOnBackground() async {
    String? refreshToken = await _storage.read(key: 'refresh_token');
    String? hasPin = await _storage.read(key: 'user_pin');
    if (refreshToken != null && hasPin != null) {
      lock();
    }
  }

  void evaluateUnlockOnForeground() {
    if (isLocked.value) {
      isLocked.value = false;
      Get.offAllNamed('/pin-verify');
    }
  }
}