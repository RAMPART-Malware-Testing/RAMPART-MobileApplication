import 'package:get/get.dart';
import 'package:rampart/services/authService.dart';

/// ตรวจสอบและจัดการกรณีที่บัญชีถูกระงับโดยเซิร์ฟเวอร์
class SessionGuard {
  static bool _handling = false;

  /// ตรวจว่า response จาก backend มี status == 'ACCOUNT_BANNED'
  static bool isBanned(dynamic response) {
    if (response is! Map) return false;
    return response['status'] == 'ACCOUNT_BANNED';
  }

  /// ล้าง session ทั้งหมดแล้วพาไปหน้า /banned
  static Future<void> handleBanned() async => _clearThenGo('/banned');

  /// session ตายถาวร — token ยังไม่หมดอายุแต่ผู้ใช้ไม่มีอยู่ในฐานข้อมูลแล้ว
  /// (เช่นหลังย้ายเซิร์ฟเวอร์ ฐานข้อมูลถูกล้าง หรือบัญชีถูกลบ)
  ///
  /// กรณีนี้กด "ลองใหม่" ไม่มีทางสำเร็จ เพราะทุกคำขอจะได้ 401 กลับมาเหมือนเดิม
  /// ผู้ใช้จะต้องล็อกใหม่เพื่อให้เซิร์ฟเวอร์สร้างแถวผู้ใช้ขึ้นมาใหม่
  static Future<void> handleSessionDead() async => _clearThenGo('/login');

  /// กัน race condition เมื่อหลาย endpoint ตอบว่า session ตายพร้อมกัน
  static Future<void> _clearThenGo(String route) async {
    if (_handling) return;
    _handling = true;

    try {
      await AuthService().clearAuthData();
      // navigation ต้องมี context ถึงจะทำได้ — ถ้ายังไม่พร้อมให้ข้าม
      if (Get.context != null) {
        try {
          Get.offAllNamed(route);
        } catch (_) {
          // ถ้า navigation ล้มเหลว (เช่นอยู่นอก material app) ก็ปล่อยให้ล้างข้อมูลแล้วจบ
        }
      }
    } finally {
      _handling = false;
    }
  }
}
