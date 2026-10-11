import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import 'package:rampart/services/network_monitor_service.dart';
import 'package:rampart/services/profile_service.dart';

/// Service จัดการการแจ้งเตือนทั้งหมด รวมถึงการนับแจ้งเตือนใหม่สำหรับ badge
class NotificationService extends GetxController {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _reportsSeenKey = 'notif_reports_seen';
  static const String _publicSeenKey = 'notif_public_seen';

  final _storage = const FlutterSecureStorage();
  bool _syncing = false;

  /// จำนวนรายงานใหม่ที่ยังไม่ได้ตรวจสอบ/อ่าน
  final _notificationCount = 0.obs;

  /// จำนวนไฟล์สาธารณะใหม่ที่ยังไม่ได้ดู
  final _publicCount = 0.obs;

  /// สตรีมสำหรับ UI ติดตามการเปลี่ยนแปลง
  Stream<int> get notificationCountStream => _notificationCount.stream;

  /// ค่าปัจจุบันของแจ้งเตือนรายงาน
  int get notificationCount => _notificationCount.value;

  /// ค่าปัจจุบันของไฟล์สาธารณะใหม่
  int get publicCount => _publicCount.value;

  /// เพิ่มจำนวนการแจ้งเตือนใหม่
  void inc() => _notificationCount.value++;

  /// ตั้งจำนวนแจ้งเตือนรายงาน
  void setCount(int count) => _notificationCount.value = count;

  /// ตั้งจำนวนไฟล์สาธารณะใหม่
  void setPublicCount(int count) => _publicCount.value = count;

  /// ผู้ใช้เปิดดูรายงานแล้ว — เคลียร์ badge และจดเวลาไว้ให้เซิร์ฟเวอร์นับเฉพาะรายการใหม่
  Future<void> clear() async {
    _notificationCount.value = 0;
    await _stampSeen(_reportsSeenKey);
  }

  /// ผู้ใช้เปิดดูรายการสาธารณะแล้ว
  Future<void> clearPublic() async {
    _publicCount.value = 0;
    await _stampSeen(_publicSeenKey);
  }

  /// ตรวจสอบว่ามีการแจ้งเตือนใหม่หรือไม่
  bool get hasUnread => _notificationCount.value > 0;

  /// จำนวนที่ยังไม่ได้ตรวจสอบ (ใช้กับ Obx เพื่อให้ badge อัปเดตเอง)
  int get count => _notificationCount.value;

  /// ดึงจำนวนรายการใหม่จากเซิร์ฟเวอร์ (/api/profile/notifications)
  /// เทียบกับเวลาที่ผู้ใช้ดูล่าสุด แล้วอัปเดต badge ทั้งสองแท็บ
  Future<void> syncFromServer() async {
    if (_syncing) return;
    if (!NetworkMonitorService().isOnline.value) return;
    _syncing = true;
    try {
      final stamps = await Future.wait([
        _storage.read(key: _reportsSeenKey),
        _storage.read(key: _publicSeenKey),
      ]);
      final result = await ProfileService.instance.notificationCounts(
        reportsSince: DateTime.tryParse(stamps[0] ?? ''),
        publicSince: DateTime.tryParse(stamps[1] ?? ''),
      );
      if (!result.success) return;
      setCount(result.reports);
      setPublicCount(result.publicCount);
    } catch (_) {
      // badge sync ล้มเหลวได้เงียบ ๆ — มี FCM push เติมเต็มอยู่แล้ว
    } finally {
      _syncing = false;
    }
  }

  /// ล้างทุกอย่างเมื่อออกจากระบบ (badge + เวลาดูล่าสุด)
  Future<void> reset() async {
    _notificationCount.value = 0;
    _publicCount.value = 0;
    await Future.wait([
      _storage.delete(key: _reportsSeenKey),
      _storage.delete(key: _publicSeenKey),
    ]);
  }

  Future<void> _stampSeen(String key) {
    return _storage.write(
      key: key,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }
}
