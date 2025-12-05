# Submit File Screen - Documentation

## ภาพรวม

Submit File Screen สำหรับอัปโหลดไฟล์เพื่อวิเคราะห์มัลแวร์ พร้อมฟีเจอร์ครบครันและใช้งานง่าย

---

## ✨ Features หลัก

### 1. **📤 File Upload**
- เลือกไฟล์ทุกประเภท (Any File Type)
- รองรับไฟล์ขนาดสูงสุด 100MB
- แสดงข้อมูลไฟล์: ชื่อ, ขนาด, ประเภท
- Progress indicator ขณะอัปโหลด

### 2. **🔒 Privacy Control**
- **Private (Default)**: ผลการวิเคราะห์เป็นส่วนตัว มองเห็นได้เฉพาะเจ้าของ
- **Public**: ผลการวิเคราะห์เป็นสาธารณะ ทุกคนสามารถเข้าถึงได้
- สลับด้วย Toggle Switch ที่ใช้งานง่าย

### 3. **📝 Description (Optional)**
- เพิ่มคำอธิบายเกี่ยวกับไฟล์
- จำกัด 200 ตัวอักษร
- ไม่บังคับ

### 4. **🎯 User Experience**
- File validation (ขนาดไฟล์)
- Error handling พร้อม message ชัดเจน
- Loading state & Progress tracking
- Success notification พร้อมรายละเอียด
- Auto reset form หลังอัปโหลดสำเร็จ

---

## 📱 UI Components

### 1. Upload Area
- Click-to-select file
- แสดง icon และชื่อไฟล์
- Animated border (pulse effect)
- Disabled ขณะอัปโหลด

### 2. File Info Card (แสดงหลังเลือกไฟล์)
- ชื่อไฟล์
- ขนาดไฟล์ (auto format: B, KB, MB, GB)
- ประเภทไฟล์ (extension)

### 3. Visibility Card (แสดงหลังเลือกไฟล์)
- Icon แสดงสถานะ (Public/Private)
- Toggle Switch สำหรับเปลี่ยนแปลง
- คำอธิบายชัดเจน

### 4. Description Card (แสดงหลังเลือกไฟล์)
- Multi-line text field
- Character counter (0/200)
- Optional field

### 5. Upload Button
- แสดงสถานะ: "อัปโหลดและวิเคราะห์" / "กำลังอัปโหลด..."
- Disabled ขณะอัปโหลด
- Progress indicator

---

## 🔧 Technical Details

### Dependencies

```yaml
dependencies:
  file_picker: ^8.0.0+1  # สำหรับเลือกไฟล์
  http: ^1.2.0           # สำหรับ HTTP request
  path: ^1.9.0           # สำหรับจัดการ path
```

### File Structure

```
lib/
├── models/
│   └── file_upload.dart           # Models สำหรับ upload
├── services/
│   └── file_upload_service.dart   # API service สำหรับ upload
└── screens/
    └── submit_file_screen.dart    # UI screen
```

---

## 📊 Data Models

### 1. FileUploadRequest

```dart
class FileUploadRequest {
  final File file;
  final String fileName;
  final bool isPublic;       // Default: false (private)
  final String? description; // Optional
}
```

### 2. FileUploadResponse

```dart
class FileUploadResponse {
  final String fileId;
  final String fileName;
  final String status;       // 'pending', 'analyzing', 'completed'
  final bool isPublic;
  final String uploadedAt;
  final int fileSize;
  final String? message;
}
```

### 3. SelectedFileInfo

```dart
class SelectedFileInfo {
  final String name;
  final String path;
  final int size;
  final String? extension;

  String get displaySize;    // Auto format (B, KB, MB, GB)
}
```

---

## 🔌 API Integration

### Endpoint

```
POST /api/files/upload
```

### Request Format

**Multipart Form Data:**

```
Content-Type: multipart/form-data
Authorization: Bearer {token}

Fields:
- file: [Binary File]
- is_public: boolean (true/false)
- description: string (optional)
```

### cURL Example

```bash
curl -X POST https://your-api-server.com/api/files/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@/path/to/file.apk" \
  -F "is_public=false" \
  -F "description=Test malware sample"
```

### Response Format

**Success (200/201):**

```json
{
  "file_id": "abc123xyz",
  "file_name": "suspicious_app.apk",
  "status": "pending",
  "is_public": false,
  "uploaded_at": "2024-01-15T10:30:00Z",
  "file_size": 5242880,
  "message": "File uploaded successfully. Analysis started."
}
```

**Error Responses:**

```json
// 401 Unauthorized
{
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}

// 413 Payload Too Large
{
  "error": "File Too Large",
  "message": "File size exceeds 100MB limit"
}

// 415 Unsupported Media Type
{
  "error": "Unsupported File Type",
  "message": "This file type is not supported"
}

// 400 Bad Request
{
  "error": "Bad Request",
  "message": "Missing required fields"
}
```

---

## ⚙️ Configuration

### 1. API Base URL

แก้ไขใน [`lib/services/file_upload_service.dart`](lib/services/file_upload_service.dart:8):

```dart
static const String baseUrl = 'https://your-api-server.com/api';
```

### 2. Authentication Token

แก้ไขใน [`lib/screens/submit_file_screen.dart`](lib/screens/submit_file_screen.dart:152):

```dart
// TODO: ดึง token จาก storage หรือ state management
const token = 'your_auth_token_here';
```

**แนะนำให้ใช้:**

```dart
// ตัวอย่างใช้ GetX
final authController = Get.find<AuthController>();
final token = authController.token.value;

// หรือ SharedPreferences
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('auth_token') ?? '';
```

### 3. File Size Limit

แก้ไขใน [`lib/screens/submit_file_screen.dart`](lib/screens/submit_file_screen.dart:76):

```dart
const maxSize = 100 * 1024 * 1024; // 100MB
```

---

## 🎨 Customization

### เปลี่ยน Default Visibility

ในไฟล์ `submit_file_screen.dart`:

```dart
// ค่าเริ่มต้นเป็น Private
bool _isPublic = false;

// เปลี่ยนเป็น Public
bool _isPublic = true;
```

### ปรับแต่ง Description Length

```dart
// ปัจจุบัน: 200 ตัวอักษร
maxLength: 200,

// เปลี่ยนเป็น 500 ตัวอักษร
maxLength: 500,
```

### เพิ่ม/ลด Info Cards

แก้ไขใน method `_buildInfoCards()`:

```dart
_buildInfoCard(
  icon: Icons.your_icon,
  title: 'หัวข้อของคุณ',
  description: 'คำอธิบาย...',
  color: Colors.blue,
),
```

---

## 🚀 Usage Flow

### User Flow

1. **เลือกไฟล์**
   - คลิกที่ Upload Area
   - เลือกไฟล์จาก File Picker
   - ระบบตรวจสอบขนาดไฟล์
   - แสดง File Info Card

2. **ตั้งค่า (Optional)**
   - เปลี่ยน Public/Private (default: Private)
   - เพิ่มคำอธิบาย (optional)

3. **อัปโหลด**
   - กดปุ่ม "อัปโหลดและวิเคราะห์"
   - แสดง Progress Bar
   - รอการอัปโหลดเสร็จสิ้น

4. **ผลลัพธ์**
   - แสดง Success Message
   - Form รีเซ็ตอัตโนมัติ
   - พร้อมสำหรับอัปโหลดไฟล์ใหม่

### Error Handling

| Error | Message | Solution |
|-------|---------|----------|
| No file selected | กรุณาเลือกไฟล์ก่อนอัปโหลด | เลือกไฟล์ก่อน upload |
| File too large | ขนาดไฟล์เกิน 100MB | เลือกไฟล์ขนาดเล็กกว่า |
| Network error | ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ | ตรวจสอบอินเทอร์เน็ต |
| Unauthorized | กรุณาเข้าสู่ระบบใหม่ | Login อีกครั้ง |
| Server error | เกิดข้อผิดพลาด | ลองใหม่อีกครั้ง |

---

## 🧪 Testing

### Manual Testing Checklist

- [ ] เลือกไฟล์ได้ทุกประเภท
- [ ] แสดงข้อมูลไฟล์ถูกต้อง
- [ ] ตรวจจับไฟล์ขนาดเกิน 100MB
- [ ] Toggle Public/Private ทำงานถูกต้อง
- [ ] เพิ่มคำอธิบายได้
- [ ] Upload progress แสดงถูกต้อง
- [ ] แสดง error message เมื่อเกิดข้อผิดพลาด
- [ ] Form reset หลังอัปโหลดสำเร็จ
- [ ] ปุ่ม disabled ขณะกำลัง upload

### Mock Upload (สำหรับทดสอบ UI)

แก้ไข method `_uploadFile()` ใน `submit_file_screen.dart`:

```dart
// Comment out API call
// await _uploadService.uploadFile(...);

// Simulate upload
await Future.delayed(const Duration(seconds: 2));

setState(() {
  _isUploading = false;
  _uploadProgress = 1.0;
});
```

---

## 📝 Backend Requirements

Backend ต้องรองรับ:

1. **Multipart Form Data Upload**
   - รับไฟล์ binary
   - รับ fields: `is_public`, `description`

2. **File Validation**
   - ตรวจสอบขนาดไฟล์ (max 100MB)
   - ตรวจสอบประเภทไฟล์ (optional)
   - Virus scan ก่อนเก็บ (recommended)

3. **Authentication**
   - ตรวจสอบ Bearer Token
   - เชื่อมโยงไฟล์กับ user

4. **Response**
   - ส่งกลับ `file_id` สำหรับติดตามสถานะ
   - ส่งสถานะเริ่มต้น (`pending`)

5. **Storage**
   - เก็บไฟล์อย่างปลอดภัย
   - จัดการ permissions (public/private)

---

## 🔐 Security Notes

### Client-Side

1. **File Size Validation**
   - ตรวจสอบก่อนส่ง API
   - ป้องกัน upload ไฟล์ขนาดใหญ่

2. **Token Management**
   - เก็บ token อย่างปลอดภัย
   - ใช้ HTTPS เท่านั้น

3. **Error Messages**
   - ไม่เปิดเผยข้อมูลละเอียดของระบบ
   - แสดงข้อความที่เหมาะสมกับ user

### Server-Side (Backend)

1. **File Validation**
   - ตรวจสอบ MIME type
   - Scan virus/malware
   - จำกัดขนาดไฟล์

2. **Access Control**
   - ตรวจสอบ authentication
   - จัดการ permissions อย่างเหมาะสม
   - Private files ต้องเข้าถึงได้เฉพาะเจ้าของ

3. **Storage Security**
   - เข้ารหัสไฟล์
   - แยก storage ตาม visibility
   - Backup regularly

---

## 🐛 Known Issues

1. **withOpacity Deprecation**
   - ใน Flutter เวอร์ชันใหม่ `withOpacity()` ถูก deprecated
   - จะอัปเดตเป็น `withValues()` ในเวอร์ชันถัดไป

2. **Progress Callback**
   - `onProgress` callback ใน HTTP multipart ยังไม่ support ใน `http` package
   - ใช้ `_simulateProgress()` แทนชั่วคราว
   - พิจารณาใช้ `dio` package สำหรับ progress tracking ที่แม่นยำ

---

## 📚 Additional Resources

### Alternative Packages

**สำหรับ HTTP with Progress:**
```yaml
dio: ^5.0.0  # รองรับ upload progress callback จริง
```

**สำหรับ Token Storage:**
```yaml
flutter_secure_storage: ^9.0.0  # เก็บ token อย่างปลอดภัย
```

### Related Screens

- [Dashboard Screen](DASHBOARD_README.md) - แสดงสถิติการวิเคราะห์
- [Reports Screen](lib/screens/reports_screen.dart) - ดูผลการวิเคราะห์

---

## 📞 Support

หากมีปัญหาหรือข้อสงสัย:

1. **API Issues**: ติดต่อ Backend Team
2. **UI/UX Issues**: ติดต่อ Frontend Team
3. **File Upload Errors**: ตรวจสอบ API logs

---

## 📄 License

Copyright © 2024 RAMPART Team
