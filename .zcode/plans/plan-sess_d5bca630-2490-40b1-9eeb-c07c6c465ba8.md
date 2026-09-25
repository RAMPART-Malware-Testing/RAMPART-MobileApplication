## เป้าหมาย
ใช้ `E:\GITHUB\RAMPART-WebApplication` เป็น source of truth เฉพาะ UX/UI ของระบบวิเคราะห์ไฟล์ แล้วปรับ Flutter ให้แสดง hierarchy, ข้อความ, สถานะ, สี และ metrics ให้ตรงกัน โดยคง API endpoints และ auth flow เดิม ไม่แก้ Web repository

## Findings
- Mobile แสดง progress เป็นรายการเครื่องมือแบน ขณะที่ Web ใช้ `Analysis Pipeline` 3 ระยะ: VirusTotal, MobSF/CAPE/RampartAI, Gemini
- Mobile ใช้ risk labels `low/caution/high/critical`; Web ใช้ score tiers `<30`, `30–59`, `60–79`, `>=80`
- Mobile แสดงผลรวมและ detail แบบย่อ; Web มี score bar, per-tool scores, tool metrics, Risk Indicators และ Gemini summary
- Mobile รายงานยังไม่มี search, file-type filter, sort และ tool score chips แบบ Web
- `AnalysisService` มี `updatePrivacy` และ `buildDownloadUrl` แล้ว แต่ยังไม่มี UI ใช้งาน
- ฟิลด์ description ใน Mobile ถูกเก็บแต่ไม่ได้ส่ง API; Web ไม่มีฟิลด์นี้

## Implementation scope

### 1. Shared analysis presentation
- เพิ่ม component/model helpers กลางสำหรับ status badge, score tier, score bar, tool metadata และ analysis card
- ใช้สีแบบ Web: waiting slate, running amber, completed emerald, failed red, skipped slate
- ใช้ tier labels ภาษาไทยตรง Web: `ปลอดภัย`, `ความเสี่ยงปานกลาง`, `อันตราย`, `อันตรายร้ายแรง`
- คัดลอกเฉพาะ logo ที่จำเป็นจาก Web มา `assets/images/` และใช้ `cacheWidth`/`cacheHeight`; ไม่เพิ่ม dependency ใหม่
- สร้าง token สี/พื้นผิวเฉพาะ analysis เพื่อไม่กระทบหน้า login/PIN

### 2. Progress screen
แก้ `lib/screens/analysis_progress_screen.dart`:
- เปลี่ยน flat tool list เป็น pipeline 3 ระย�าม Web
- แสดง `Analysis Pipeline`, `Stage 1 — Initial Triage`, `Stage 2 — Multi-Engine Analysis`, `Parallel Processing`, `Stage 3 — AI Recommendation`
- แสดง status badge ของ VirusTotal, MobSF, CAPE, RampartAI, Gemini พร้อม note/score
- รักษา poll ทุก 2.5 วินาที, retry และ network error handling เดิม
- ใช้ static status indicator หรือ bounded animation เท่านั้น; ห้าม `repeat()`/spinner ไม่รู้จบเพื่อรักษา performance budget

### 3. Result screen
แก้ `lib/screens/analysis_result_screen.dart` และ model/helper ที่เกี่ยวข้อง:
- โหลด task status และ tool reports ที่ backend ระบุใน `report.tools` แบบขนานหลังงานสำเร็จ
- แสดง `คะแนนความอันตรายรวม` / `Overall Danger Score`, score bar และ tier
- เพิ่ม `คะแนนความเสี่ยงรายเครื่องมือ` พร้อม per-tool bars และ logos
- เพิ่ม `Risk Indicators` ให้ตรง Web
- ปรับ detail cards ให้แสดง metrics เดียวกับ Web:
  - VirusTotal: Detection/Total Engines หรือ Threat Score
  - MobSF: Permissions, Activities, Services, Receivers, Risk Score
  - CAPE: Danger Score, Network, Registry, Files, Processes, Behavior Report
  - RampartAI: Prediction, Confidence, Malware/Benign Probability
  - Gemini: Summary, Threat Assessment, Behavior, Recommendation, Overall Risk
- คง lazy detail loading เป็น fallback เมื่อ tool report โหลดไม่ได้
- เพิ่ม privacy toggle `สาธารณะ/ส่วนตัว` เฉพาะเจ้าของรายงาน โดยเพิ่ม profile lookup ที่ใช้ token เดิม; ซ่อน toggle เมื่อยืนยัน owner ไม่ได้
- ไม่เพิ่มระบบดาวน์โหลดไฟล์ใหม่ในรอบนี้ เพราะต้องการจัดการ path/permission ของ Android; คง service เดิมไว้สำหรับรอบถัดไป

### 4. Reports screen
แก้ `lib/screens/reports_screen.dart` และ `lib/services/analysis_service.dart`:
- เพิ่มช่องค้นหาชื่อไฟล์/Task ID
- เพิ่ม file type filters ตาม Web: APK, EXE, MSI, BAT, DMG, IPA, ZIP
- เพิ่ม sort controls: วันที่, ชื่อไฟล์, ขนาด, ความเสี่ยง พร้อม asc/desc
- ส่ง `s`, `file_type`, sort key/direction ใน request `/history`
- ใช้ score tier เดียวกับ Web และแสดง tool chips พร้อมคะแนนย่อย
- คง infinite scroll เพื่อเหมาะกับมือถือ แต่รักษา page reset เมื่อเปลี่ยน filter

### 5. Submit screen
แก้ `lib/screens/submit_file_screen.dart`:
- ปรับหัวข้อ/คำอธิบายและ dropzone ให้ตรง Web
- ใช้สถานะ `อัปโหลด %`, `กำลังวิเคราะห์`, `เสร็จสิ้น`, `ล้มเหลว` แบบเดียวกัน
- แสดง privacy เป็น `สาธารณะ/ส่วนตัว` และคง default private
- เอา description field ที่ไม่ถูกส่ง backend ออก เพื่อไม่ให้ UI ชวนผู้ใช้กรอกข้อมูลที่ไม่มีผล
- คง 1GB validation และ upload progress จริง

### 6. Verification
- เพิ่ม widget/unit tests สำหรับ score tiers, status normalization, pipeline grouping และ report filters
- รัน `dart format`
- รัง `flutter analyze --no-pub` เฉพาะไฟล์ที่แก้ และรายงาน baseline warnings ที่ไม่เกี่ยวข้อง
- รัน `flutter test --no-pub` สำหรับ analysis tests และ OTP regression test
- ถ้า emulator พร้อม ให้ตรวจ upload → progress → result ด้วย task จริง; หาก backend ยัง rate-limit/500 ให้ระบุ blocker แยกจาก UI verification

## Constraints
- ไม่แก้ API URL, auth/PIN, Firebase หรือ cold-start ในงานนี้
- ไม่แก้ source Web
- ไม่ใช้ animation loop หรือ rebuild ต่อเนื่อง
- ไม่ commit/push จนกว่าจะตรวจ diff และ tests ผ่าน