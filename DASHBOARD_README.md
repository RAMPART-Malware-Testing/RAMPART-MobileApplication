# Dashboard Screen Documentation

## ภาพรวม

Dashboard Screen แสดงสถิติการวิเคราะห์ไฟล์มัลแวร์ในระบบ RAMPART ประกอบด้วยข้อมูลต่างๆ ดังนี้:

### ✨ Features

1. **📊 ไฟล์ Public ในระบบ**
   - จำนวนไฟล์ที่วิเคราะห์สำเร็จ (เสร็จสิ้น)
   - จำนวนไฟล์ที่รอวิเคราะห์ (pending)
   - จำนวนไฟล์ที่วิเคราะห์ไม่สำเร็จ (failed)
   - ยอดรวมไฟล์ทั้งหมด

2. **📁 ไฟล์ของฉัน**
   - จำนวนไฟล์ของตัวเองที่วิเคราะห์สำเร็จ
   - จำนวนไฟล์ที่รอวิเคราะห์
   - จำนวนไฟล์ที่วิเคราะห์ไม่สำเร็จ
   - ยอดรวมไฟล์ของตัวเอง

3. **👥 สมาชิกในระบบ**
   - จำนวนสมาชิกผู้ใช้ทั้งหมด (ไม่รวม master, admin)

4. **⚠️ คะแนนความเสี่ยงเฉลี่ย**
   - คะแนนความเสี่ยงเฉลี่ยของไฟล์มัลแวร์ที่ตรวจพบ (0-100)
   - แสดงด้วย Circular Progress Indicator
   - มี 3 ระดับ: ต่ำ (เขียว), ปานกลาง (ส้ม), สูง (แดง)

5. **🏆 TOP 10 มัลแวร์**
   - แสดงประเภทมัลแวร์ที่พบมากที่สุด 10 อันดับ
   - สลับดูได้ทั้ง **รายวัน** และ **รายเดือน**
   - แสดงด้วย Bar Chart
   - แสดง List พร้อมจำนวนและเปอร์เซ็นต์

---

## 📱 UI Components

### 1. Header
- แสดงชื่อแอป "RAMPART"
- Dashboard icon

### 2. Welcome Card
- แสดงข้อความต้อนรับ
- มี animation pulse effect

### 3. Statistics Cards
- แยกเป็นส่วนๆ ตามหมวดหมู่
- ใช้สี coding:
  - 🟢 เขียว = สำเร็จ
  - 🟠 ส้ม = รอดำเนินการ
  - 🔴 แดง = ไม่สำเร็จ/อันตราย

### 4. Risk Score Card
- Circular progress indicator
- แสดงคะแนนและระดับความเสี่ยง

### 5. Malware Chart & List
- Bar Chart แบบโต้ตอบได้ (tooltip)
- List พร้อม ranking (#1-#10)
- Period selector (รายวัน/รายเดือน)

---

## 🔧 การติดตั้ง

### Dependencies ที่ต้องการ

ตรวจสอบใน `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.3.2
  http: ^1.2.0
  fl_chart: ^0.69.0
  intl: ^0.19.0
```

### ติดตั้ง Dependencies

```bash
flutter pub get
```

---

## ⚙️ Configuration

### 1. ตั้งค่า API Base URL

แก้ไขไฟล์ [`lib/services/dashboard_service.dart`](lib/services/dashboard_service.dart:7):

```dart
static const String baseUrl = 'https://your-api-server.com/api';
```

เปลี่ยนเป็น URL ของ API server จริง

### 2. ตั้งค่า Authentication Token

ในไฟล์ [`lib/screens/dashboard_screen.dart`](lib/screens/dashboard_screen.dart:61):

```dart
// TODO: ดึง token จาก storage หรือ state management
const token = 'your_auth_token_here';
```

แนะนำให้ใช้:
- `shared_preferences` สำหรับเก็บ token
- State management (GetX, Provider, Bloc) สำหรับจัดการ authentication state

**ตัวอย่างการใช้ GetX:**

```dart
// ใน _loadDashboardData()
final authController = Get.find<AuthController>();
final token = authController.token.value;

final stats = await _dashboardService.getDashboardStats(
  period: _selectedPeriod,
  token: token,
);
```

---

## 📂 โครงสร้างไฟล์

```
lib/
├── models/
│   └── dashboard_stats.dart       # Data models
├── services/
│   └── dashboard_service.dart     # API service
└── screens/
    └── dashboard_screen.dart      # UI screen
```

### Models

**[`lib/models/dashboard_stats.dart`](lib/models/dashboard_stats.dart)**

- `DashboardStats` - ข้อมูล Dashboard ทั้งหมด
- `FileStats` - สถิติไฟล์ (success, pending, failed)
- `MalwareType` - ข้อมูลประเภทมัลแวร์

### Services

**[`lib/services/dashboard_service.dart`](lib/services/dashboard_service.dart)**

Methods:
- `getDashboardStats()` - ดึงข้อมูล Dashboard ทั้งหมด
- `getTopMalwareTypes()` - ดึงข้อมูล TOP 10 malware
- `getPublicFileStats()` - ดึงสถิติไฟล์ public
- `getMyFileStats()` - ดึงสถิติไฟล์ของผู้ใช้

---

## 🔌 API Integration

ดูรายละเอียด API Endpoints และ Response Format ได้ที่:
**[`API_EXAMPLE.md`](API_EXAMPLE.md)**

### ตัวอย่าง API Response

```json
{
  "public_files": {
    "success": 1523,
    "pending": 45,
    "failed": 12
  },
  "my_files": {
    "success": 156,
    "pending": 5,
    "failed": 3
  },
  "total_members": 245,
  "average_risk_score": 68.5,
  "top_malware_types": [
    {
      "name": "Trojan.Generic",
      "count": 125,
      "percentage": 32.5
    }
  ]
}
```

---

## 🎨 Customization

### เปลี่ยนสี Theme

สีหลักถูกดึงมาจาก [`lib/theme/app_theme.dart`](lib/theme/app_theme.dart):

- `cyanColor` - สีฟ้า cyan
- `blueColor` - สีน้ำเงิน
- `hintColor` - สีข้อความรอง

### เปลี่ยนจำนวนสูงสุดของ TOP Malware

ในไฟล์ `dashboard_screen.dart`:

```dart
// ปัจจุบันคือ 10
final malwareData = _stats!.topMalwareTypes.take(10).toList();

// เปลี่ยนเป็น 5
final malwareData = _stats!.topMalwareTypes.take(5).toList();
```

---

## 🚀 Features พิเศษ

### 1. Pull to Refresh
ดึงหน้าจอลงเพื่อโหลดข้อมูลใหม่

### 2. Loading State
แสดง loading indicator ขณะโหลดข้อมูล

### 3. Error Handling
แสดง error card พร้อมปุ่ม "ลองอีกครั้ง" เมื่อเกิด error

### 4. Number Formatting
ตัวเลขจะแสดงด้วย comma separator (เช่น 1,523)

### 5. Animations
- Pulse animation บน Welcome Card
- Smooth transitions ระหว่าง states

---

## 🧪 Testing

### Mock Data สำหรับทดสอบ

หากยังไม่มี API จริง สามารถ mock data ได้โดยแก้ไข `_loadDashboardData()`:

```dart
Future<void> _loadDashboardData() async {
  setState(() {
    _isLoading = true;
    _error = '';
  });

  await Future.delayed(const Duration(seconds: 1)); // Simulate API delay

  // Mock data
  final mockStats = DashboardStats(
    publicFiles: FileStats(success: 1523, pending: 45, failed: 12),
    myFiles: FileStats(success: 156, pending: 5, failed: 3),
    totalMembers: 245,
    averageRiskScore: 68.5,
    topMalwareTypes: [
      MalwareType(name: 'Trojan.Generic', count: 125, percentage: 32.5),
      MalwareType(name: 'Ransomware.WannaCry', count: 98, percentage: 25.5),
      MalwareType(name: 'Adware.Generic', count: 76, percentage: 19.8),
      MalwareType(name: 'Spyware.Agent', count: 45, percentage: 11.7),
      MalwareType(name: 'Backdoor.Generic', count: 23, percentage: 6.0),
    ],
  );

  setState(() {
    _stats = mockStats;
    _isLoading = false;
  });
}
```

---

## 📝 TODO List

- [ ] เชื่อมต่อกับ Authentication system จริง
- [ ] เพิ่ม error logging
- [ ] เพิ่ม analytics tracking
- [ ] รองรับ offline mode (cache data)
- [ ] เพิ่ม filter เพิ่มเติม (date range)
- [ ] Export รายงานเป็น PDF

---

## 🐛 Known Issues

1. **withOpacity Deprecation Warning**:
   - ในเวอร์ชัน Flutter ใหม่ `withOpacity()` ถูก deprecated
   - จะแก้ไขใช้ `withValues()` ในเวอร์ชันถัดไป

---

## 📞 Support

หากมีปัญหาหรือข้อสงสัย กรุณาติดต่อ:
- Backend Team: สำหรับ API issues
- Frontend Team: สำหรับ UI/UX issues

---

## 📄 License

Copyright © 2024 RAMPART Team
