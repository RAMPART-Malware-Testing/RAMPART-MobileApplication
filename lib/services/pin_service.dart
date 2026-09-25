import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PINService extends GetxService {
  final _storage = const FlutterSecureStorage();
  String initialRoute = '/login';
  final isLocked = false.obs;

  /// ช่วงเวลาที่ยกเว้นการล็อก หลังจากแอปเปิด Activity ภายนอกเอง
  /// (ตัวเลือกไฟล์, กล้อง) — ถ้าไม่ยกเว้น พอกลับมาจาก picker
  /// แอปจะถูกมองว่าเพิ่งอยู่เบื้องหลังและเด้งไปหน้า PIN ทันที
  static const Duration _suppressWindow = Duration(minutes: 2);
  DateTime? _lockSuppressedAt;

  /// เรียกก่อนเปิด Activity ภายนอก เพื่อไม่ให้การล็อกทำงานระหว่างนั้น
  void suppressLockBriefly() {
    _lockSuppressedAt = DateTime.now();
  }

  bool get _isLockSuppressed {
    final at = _lockSuppressedAt;
    if (at == null) return false;

    // หน้าต่างหมดอายุเองได้ เพื่อไม่ให้การล็อกถูกปิดค้างถ้าลืมเคลียร์
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
    String? sessionType = await _storage.read(key: 'session_type');
    String? refreshToken = await _storage.read(key: 'refresh_token');
    String? sessionToken = await _storage.read(key: 'session_token');
    String? hasPin = await _storage.read(key: 'user_pin');

    // ต้องเป็น session ที่ยืนยันเสร็จแล้วเท่านั้น ไม่ใช่แค่ "มี token ค้างอยู่"
    // ไม่งั้น token ขั้นตอน login_confirm / register_confirm / forgot_passwd_confirm
    // ที่ยังไม่ได้ยืนยันจะถูกนับเป็น session ที่ใช้ได้ และพาเข้า /home ทันที
    bool hasAccessToken = sessionToken != null &&
        sessionToken != 'null' &&
        sessionToken.isNotEmpty;

    // refreshAccessToken() ก็ปฏิเสธถ้า session_type ไม่ใช่ access เช่นกัน
    // ดังนั้นไม่ว่าจะถือ token ชนิดใด ก็นับเป็น session ที่ใช้ได้ก็ต่อเมื่อผ่านการยืนยันแล้ว
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

    // อ่านพร้อมกันในรอบเดียว (ลดการเข้าถึง Keystore)
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