/// ข้อมูลไฟล์ที่ผู้ใช้เลือกไว้แสดงบนหน้าจอ (ยังไม่อัปโหลด)
///
/// ส่วน request/response ของการอัปโหลดอยู่ใน `lib/models/analysis.dart`
/// เพราะยิงตรงไปที่ API วิเคราะห์ของ RAMPART
class SelectedFileInfo {
  final String name;
  final String path;
  final int size;
  final String? extension;

  SelectedFileInfo({
    required this.name,
    required this.path,
    required this.size,
    this.extension,
  });

  String get sizeInMB => (size / (1024 * 1024)).toStringAsFixed(2);

  String get displaySize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
