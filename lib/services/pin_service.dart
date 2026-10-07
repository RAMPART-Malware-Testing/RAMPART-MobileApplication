import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PINService extends GetxService {
  final _storage = const FlutterSecureStorage();
  String initialRoute = '/login';
  final isLocked = false.obs;

  static const Duration _suppressWindow = Duration(minutes: 2);
  DateTime? _lockSuppressedAt;

  void suppressLockBriefly() {
    _lockSuppressedAt = DateTime.now();
  }

  bool get _isLockSuppressed {
    final at = _lockSuppressedAt;
    if (at == null) return false;

    if (DateTime.now().difference(at) > _suppressWindow) {
      _lockSuppressedAt = null;
      return false;
    }
    return true;
  }

  Future<PINService> init() async {
    await checkLoginStatus();
    return this;
  }

  Future<void> checkLoginStatus() async {
    final values = await Future.wait([
      _storage.read(key: 'session_type'),
      _storage.read(key: 'refresh_token'),
      _storage.read(key: 'session_token'),
      _storage.read(key: 'user_pin'),
    ]);
    final sessionType = values[0];
    final refreshToken = values[1];
    final sessionToken = values[2];
    final hasPin = values[3];

    bool hasAccessToken = sessionToken != null &&
        sessionToken != 'null' &&
        sessionToken.isNotEmpty;

    bool hasValidSession =
        sessionType == 'access' && (hasAccessToken || refreshToken != null);

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
    if (_isLockSuppressed) return;

    final values = await Future.wait([
      _storage.read(key: 'refresh_token'),
      _storage.read(key: 'user_pin'),
    ]);

    if (values[0] != null && values[1] != null) {
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
