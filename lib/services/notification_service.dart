import 'package:get/get.dart';

/// Service จัดการการแจ้งเตือนทั้งหมด รวมถึงการนับแจ้งเตือนใหม่สำหรับ badge
class NotificationService extends GetxController {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// จำนวนการแจ้งเตือนที่ยังไม่ได้ตรวจสอบ/อ่าน
  final _notificationCount = 0.obs;

  /// สตรีมสำหรับ UI ติดตามการเปลี่ยนแปลง
  Stream<int> get notificationCountStream => _notificationCount.stream;

  /// ค่าปัจจุบันของการแจ้งเตือน
  int get notificationCount => _notificationCount.value;

  /// เพิ่มจำนวนการแจ้งเตือนใหม่
  void inc() => _notificationCount.value++;

  /// เพิ่มจำนวนการแจ้งเตือน (override)
  void setCount(int count) => _notificationCount.value = count;

  /// ล้างจำนวนการแจ้งเตือน (เมื่อผู้ใช้ตรวจสอบแล้ว)
  void clear() => _notificationCount.value = 0;

  /// ตรวจสอบว่ามีการแจ้งเตือนใหม่หรือไม่
  bool get hasUnread => _notificationCount.value > 0;

  /// จำนวนที่ยังไม่ได้ตรวจสอบ (ใช้กับ Obx เพื่อให้ badge อัปเดตเอง)
  int get count => _notificationCount.value;
}