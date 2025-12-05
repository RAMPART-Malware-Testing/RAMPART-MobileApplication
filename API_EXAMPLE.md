# RAMPART Dashboard API Documentation

## API Endpoint สำหรับ Dashboard

### Base URL
```
https://your-api-server.com/api
```

### Authentication
ใช้ Bearer Token ใน Header:
```
Authorization: Bearer {token}
```

---

## 1. Get Dashboard Statistics

**Endpoint:** `GET /dashboard/stats`

**Query Parameters:**
- `period` (string): "daily" หรือ "monthly" - สำหรับ TOP 10 malware

**Response Example:**
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
    },
    {
      "name": "Ransomware.WannaCry",
      "count": 98,
      "percentage": 25.5
    },
    {
      "name": "Adware.Generic",
      "count": 76,
      "percentage": 19.8
    },
    {
      "name": "Spyware.Agent",
      "count": 45,
      "percentage": 11.7
    },
    {
      "name": "Backdoor.Generic",
      "count": 23,
      "percentage": 6.0
    },
    {
      "name": "Worm.Conficker",
      "count": 18,
      "percentage": 4.5
    }
  ]
}
```

---

## 2. Get Top Malware Types (Optional - ถ้าต้องการแยก endpoint)

**Endpoint:** `GET /dashboard/top-malware`

**Query Parameters:**
- `period` (string): "daily" หรือ "monthly"

**Response Example:**
```json
[
  {
    "name": "Trojan.Generic",
    "count": 125,
    "percentage": 32.5
  },
  {
    "name": "Ransomware.WannaCry",
    "count": 98,
    "percentage": 25.5
  }
]
```

---

## 3. Get Public File Statistics (Optional)

**Endpoint:** `GET /dashboard/public-files`

**Response Example:**
```json
{
  "success": 1523,
  "pending": 45,
  "failed": 12
}
```

---

## 4. Get My File Statistics (Optional)

**Endpoint:** `GET /dashboard/my-files`

**Response Example:**
```json
{
  "success": 156,
  "pending": 5,
  "failed": 3
}
```

---

## Data Models

### FileStats
```typescript
{
  success: number;    // จำนวนไฟล์ที่วิเคราะห์สำเร็จ
  pending: number;    // จำนวนไฟล์ที่รอวิเคราะห์
  failed: number;     // จำนวนไฟล์ที่วิเคราะห์ไม่สำเร็จ
}
```

### MalwareType
```typescript
{
  name: string;       // ชื่อประเภทมัลแวร์
  count: number;      // จำนวนไฟล์ที่พบ
  percentage: number; // เปอร์เซ็นต์ (0-100)
}
```

### DashboardStats
```typescript
{
  public_files: FileStats;         // สถิติไฟล์ public
  my_files: FileStats;             // สถิติไฟล์ของผู้ใช้
  total_members: number;           // จำนวนสมาชิกทั้งหมด (ไม่รวม admin)
  average_risk_score: number;      // คะแนนความเสี่ยงเฉลี่ย (0-100)
  top_malware_types: MalwareType[]; // TOP 10 มัลแวร์
}
```

---

## หมายเหตุสำหรับ Backend Developer

1. **Public Files**: ไฟล์ที่ทุกคนในระบบเข้าถึงได้ (public visibility)
2. **My Files**: ไฟล์ที่ผู้ใช้ที่ login อยู่เป็นเจ้าของ
3. **Total Members**: นับเฉพาะ user ที่มี role เป็น "user" (ไม่นับ admin, master)
4. **Average Risk Score**: คะแนนเฉลี่ยของไฟล์ที่ตรวจพบว่าเป็นมัลแวร์เท่านั้น
5. **TOP 10 Malware**:
   - แสดงสูงสุด 10 อันดับ
   - เรียงจากมากไปน้อยตาม count
   - สามารถกรองตาม period (daily/monthly)
   - percentage คำนวณจากจำนวนมัลแวร์ทั้งหมดในช่วงเวลานั้น

---

## Error Responses

### 401 Unauthorized
```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal Server Error",
  "message": "Failed to fetch dashboard statistics"
}
```
