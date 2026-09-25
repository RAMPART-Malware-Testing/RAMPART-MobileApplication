import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rampart/services/authService.dart';
import 'package:rampart/services/pin_service.dart';

/// ตัวแทนของ token ที่ยังไม่ผ่านการยืนยัน — ไม่ใช่ credential จริง
const _fakeConfirmToken = 'fake.confirm.token.value';
const _fakeAccessToken = 'fake.access.token.value';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService.isDeadSession', () {
    test('treats every status the server sends for a dead session', () {
      for (final status in [
        'TOKEN_INVALID',
        'TOKEN_WRONG_TYPE',
        'TOKEN_EXPIRED',
        'OTP_EXPIRED',
      ]) {
        expect(
          AuthService.isDeadSession({'success': false, 'status': status}),
          isTrue,
          reason: '$status ต้องถือว่า session ตายแล้ว',
        );
      }
    });

    test('keeps the user on the screen for a recoverable failure', () {
      expect(
        AuthService.isDeadSession({'success': false, 'status': 'OTP_WRONG'}),
        isFalse,
      );
      expect(
        AuthService.isDeadSession({
          'success': false,
          'status': 'Connect Server Error!!!',
        }),
        isFalse,
      );
    });

    test('never treats a success as a dead session', () {
      expect(
        AuthService.isDeadSession({'success': true, 'status': 'LOGIN_SUCCESS'}),
        isFalse,
      );
    });
  });

  group('AuthService.clearStaleSession', () {
    test('drops the pending confirmation without touching the PIN', () async {
      FlutterSecureStorage.setMockInitialValues({
        'session_token': _fakeConfirmToken,
        'session_type': 'login_confirm',
        'data': '{}',
        'user_pin': '999999',
      });

      await authService.clearStaleSession();

      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'session_token'), isNull);
      expect(await storage.read(key: 'session_type'), isNull);
      expect(await storage.read(key: 'data'), isNull);
      // PIN ยังอยู่ เพราะผู้ใช้อาจเข้าใช้งานอยู่แล้ว
      expect(await storage.read(key: 'user_pin'), '999999');
    });
  });

  group('PINService.checkLoginStatus', () {
    Future<String> routeFor(Map<String, String> storage) async {
      FlutterSecureStorage.setMockInitialValues(storage);
      final service = PINService();
      await service.checkLoginStatus();
      return service.initialRoute;
    }

    test('an unverified login token must not route into the app', () async {
      expect(
        await routeFor({
          'session_token': _fakeConfirmToken,
          'session_type': 'login_confirm',
        }),
        '/login',
      );
    });

    test('register and reset confirmation tokens are equally rejected',
        () async {
      expect(
        await routeFor({
          'session_token': _fakeConfirmToken,
          'session_type': 'register_confirm',
        }),
        '/login',
      );
      expect(
        await routeFor({
          'session_token': _fakeConfirmToken,
          'session_type': 'forgot_passwd_confirm',
        }),
        '/login',
      );
    });

    test('a refresh token without an access type is not a session', () async {
      expect(
        await routeFor({
          'session_token': _fakeConfirmToken,
          'session_type': 'login_confirm',
          'refresh_token': _fakeAccessToken,
        }),
        '/login',
      );
    });

    test('a confirmed session still routes to PIN or home', () async {
      expect(
        await routeFor({
          'session_token': _fakeAccessToken,
          'session_type': 'access',
          'user_pin': '999999',
        }),
        '/pin-verify',
      );
      expect(
        await routeFor({
          'session_token': _fakeAccessToken,
          'session_type': 'access',
        }),
        '/home',
      );
      expect(
        await routeFor({
          'session_type': 'access',
          'refresh_token': _fakeAccessToken,
        }),
        '/home',
      );
    });

    test('an empty session token is not a session', () async {
      expect(
        await routeFor({'session_token': '', 'session_type': 'access'}),
        '/login',
      );
      expect(
        await routeFor({'session_token': 'null', 'session_type': 'access'}),
        '/login',
      );
    });
  });
}
