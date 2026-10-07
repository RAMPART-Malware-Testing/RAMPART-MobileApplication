import 'package:get/get.dart';
import 'package:rampart/services/authService.dart';

class SessionGuard {
  static bool _handling = false;

  static bool isBanned(dynamic response) {
    if (response is! Map) return false;
    return response['status'] == 'ACCOUNT_BANNED';
  }

  static Future<void> handleBanned() async => _clearThenGo('/banned');

  static Future<void> handleSessionDead() async => _clearThenGo('/login');

  static Future<void> _clearThenGo(String route) async {
    if (_handling) return;
    _handling = true;

    try {
      await AuthService().clearAuthData();
      if (Get.context != null) {
        try {
          Get.offAllNamed(route);
        } catch (_) {
        }
      }
    } finally {
      _handling = false;
    }
  }
}
