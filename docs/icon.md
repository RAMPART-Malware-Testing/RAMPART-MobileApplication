# App Icon และ Splash Screen

วิธีเปลี่ยนไอคอนและหน้าจอโหลดของ RAMPART โดยไม่ต้องแตะโค้ด Dart หรือไฟล์ของแต่ละแพลตฟอร์ม

---

## ภาพรวม

งานนี้ใช้ package 2 ตัวที่ทำงานร่วมกัน โดยอ่านไฟล์ต้นทางจาก `assets/icon/` แล้ว generate ไฟล์ปลายทางให้ทุกแพลตฟอร์มเอง

| Package | รับผิดชอบ | แพลตฟอร์มที่รองรับ |
|---|---|---|
| `flutter_launcher_icons` 0.14.4 | ไอคอนบน launcher / taskbar | Android, iOS, Windows, Web |
| `flutter_native_splash` 2.4.8 | หน้าจอโหลดก่อนแอปเริ่มทำงาน | Android, iOS, Web |

**Windows ไม่ได้ใช้ `flutter_native_splash`** — package นี้ไม่รองรับ Windows หน้าจอฝั่ง desktop ถูกสร้างใน `lib/screens/splash_screen.dart` ซึ่งอ่านไฟล์ `assets/icon/splash_logo.png` ไฟล์เดียวกัน การเปลี่ยนไฟล์นี้จึงครอบคลุมทั้งสองทาง

---

## ไฟล์ที่ต้องแก้

แก้เฉพาะใน `assets/icon/` เท่านั้น มี 4 ไฟล์ นี่คือทั้งหมดที่ต้องแตะ

| ไฟล์ | ใช้ทำอะไร | ขนาด | สี |
|---|---|---|---|
| `app_icon.png` | ไอคอนหลัก — Windows, iOS, Web, Android แบบเก่า | 1024×1024 | พื้นขาว + โลโก้ดำ |
| `app_icon_foreground.png` | Android 8+ adaptive icon | 1024×1024 | โลโก้ดำบนพื้นโปร่งใส |
| `splash_logo.png` | splash ฝั่ง Flutter + Android/iOS/Web | 512×512 | โลโก้**ขาว**บนพื้นโปร่งใส |
| `splash_logo_android12.png` | splash Android 12+ | 960×960 | โลโก้**ขาว**บนพื้นโปร่งใส |

### ทำไมสีต้องต่างกัน

โลโก้ต้นฉบับ `assets/images/logo_bg_white.png` เป็นสีดำบนพื้นขาว แต่ splash วางอยู่บนพื้นมืด `#0f172a` ถ้าใช้โลโก้ดำทั้งคู่ ตอนเปิดแอปจะเห็นสี่เหลี่ยมดำบนพื้นดำ มองไม่เห็น

- ไฟล์ icon → พื้นขาว → ใช้โลโก้ดำ
- ไฟล์ splash → พื้นมืด → ใช้โลโก้ขาว

---

## ขั้นตอนการเปลี่ยน

### 1. เตรียมไฟล์ต้นทาง

วางไฟล์ใหม่ลงใน `assets/icon/` ตามชื่อและขนาดในตารางข้างบน ถ้าจะใช้โลโก้จาก `logo_bg_white.png` เดิม ต้องตัดส่วนคำว่า RAMPART ออก เหลือแต่ emblem เพราะที่ขนาดเล็กจำเป็นต้องอ่านออก (ตัวคำจะกลายเป็นเส้นยาว ๆ ที่อ่านไม่ออก)

### 2. รัน package ทั้งสอง

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### 3. build ใหม่

**Android** — build ใหม่ทุกครั้ง

```bash
flutter run
```

**Windows** — ต้องลบไฟล์ cache ก่อน ไม่งั้นจะได้โค้ดเก่า

```bash
rm -f build/windows/x64/runner/Debug/data/flutter_assets/kernel_blob.bin
flutter run -d windows
```

**iOS** — ต้องเปิด Xcode อีกครั้งเพื่อให้มันอ่าน asset ใหม่

---

## ไฟล์ที่ generate อัตโนมัติ

อย่าแก้ไฟล์เหล่านี้ด้วยมือ เพราะจะถูกเขียนทับทุกครั้งที่รัน package

### ไอคอน

| แพลตฟอร์ม | ไฟล์ |
|---|---|
| Windows | `windows/runner/resources/app_icon.ico` |
| Android | `android/app/src/main/res/mipmap-*/launcher_icon.png` |
| Android | `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml` |
| Android | `android/app/src/main/res/drawable-*/ic_launcher_foreground.png` |
| Android | `android/app/src/main/res/values/colors.xml` |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` |
| Web | `web/favicon.png`, `web/icons/Icon-*.png` |
| Web | `web/manifest.json` (เติมรายการ icon) |
| Android | `android/app/src/main/AndroidManifest.xml` (สลับ `android:icon`) |

### Splash

| แพลตฟอร์ม | ไฟล์ |
|---|---|
| Android | `android/app/src/main/res/drawable-*/splash.png` |
| Android | `android/app/src/main/res/drawable-*/android12splash.png` |
| Android | `android/app/src/main/res/drawable/launch_background.xml` |
| Android | `android/app/src/main/res/values-v31/styles.xml` |
| iOS | `ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png` |
| Web | `web/splash/img/*.png`, `web/index.html` |

---

## การตั้งค่าใน pubspec.yaml

ทั้งสอง package อ่าน config จาก pubspec ไฟล์เดียวกัน

### `flutter_native_splash` (บรรทัด 103)

```yaml
flutter_native_splash:
  color: "#0f172a"
  color_dark: "#0f172a"
  image: assets/icon/splash_logo.png
  image_dark: assets/icon/splash_logo.png
  android: true
  ios: true
  web: true
  color_web: "#0f172a"
  color_dark_web: "#0f172a"
  image_web: assets/icon/splash_logo.png
  image_dark_web: assets/icon/splash_logo.png
  android_12:
    color: "#0f172a"
    color_dark: "#0f172a"
    image: assets/icon/splash_logo_android12.png
    image_dark: assets/icon/splash_logo_android12.png
```

**ข้อควรระวัง** — เวอร์ชัน 2.4.8 ใช้ชื่อ key ของ web แบบ `color_dark_web` / `image_dark_web` (คำว่า dark อยู่กลาง) ไม่ใช่ `color_web_dark` แบบที่เวอร์ชันใหม่กว่าใช้ ถ้าใส่ผิดจะได้ error `type '_Map<String, dynamic>' is not a subtype of type 'bool'`

### `flutter_launcher_icons` (บรรทัด 121)

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  min_sdk_android: 21
  remove_alpha_ios: true
  windows:
    generate: true
    image_path: "assets/icon/app_icon.png"
    icon_size: 256
  web:
    generate: true
    image_path: "assets/icon/app_icon.png"
    background_color: "#0f172a"
    theme_color: "#0f172a"
```

`android: "launcher_icon"` ตั้งชื่อ resource เป็น `launcher_icon` แทน `ic_launcher` ค่านี้ต้องตรงกับชื่อไฟล์ที่ package generate และ manifest จะถูกแก้ให้อัตโนมัติ

---

## เรื่องสำคัญที่ต้องระวัง

### 1. ขอบโลโก้ต้องไม่ชิดขอบ canvas

Android 8+ ตัด icon เป็นวงกลมหรือสี่เหลี่ยมมน โลโก้ที่ชิดขอบจะถูกตัดทิ้ง ต้องเว้นรอบประมาณ 25-30% ของ canvas

ไฟล์ `app_icon.png` ใช้โลโก้กว้าง 74% ของ canvas ส่วน `app_icon_foreground.png` ใช้ 50% เพราะถูกตัดเข้าวงกลมอีกชั้นหนึ่ง (safe zone คือ 66/108 ของ canvas)

สำหรับ `splash_logo_android12.png` ระบบจะแสดงเฉพาะวงกลมกลาง 2/3 ของหน้าต่าง ซึ่งเต็มพอดีกับ 240dp

### 2. `icon_size: 256` ของ Windows

package เขียน `.ico` ไฟล์เดียว ขนาดเดียว Windows จะย่อให้เองทุกจุด (taskbar, Alt-Tab, explorer) ผลที่ได้คือไอคอนจะไม่คมชัดเท่าไฟล์ multi-size ถ้าต้องการความคมบน Windows ให้เขียน `.ico` เองหลังรัน package เสร็จ โดยใส่หลายขนาด (16/24/32/48/64/128/256) แล้ว build ใหม่

### 3. สีพื้นหลังต้องตรงกับธีม

`color` ใน `flutter_native_splash` ต้องตรงกับ `AppTheme.splashBackground` ใน `lib/theme/app_theme.dart` ไม่งั้นจะเห็นรอยต่อสีตอนเปลี่ยนจาก splash ไปหน้าแรก ปัจจุบันทั้งคู่เป็น `#0f172a`

### 4. Windows build อาจพังเรื่อง install path

ถ้าเจอ error แบบนี้:

```
file cannot create directory: C:/Program Files/rampart.  Maybe need administrative privileges.
```

แปลว่า `CMAKE_INSTALL_PREFIX` ถูก cache ไว้ผิดที่ (ต้องใช้สิทธิ์ admin) แก้ด้วย:

```bash
cmake -DCMAKE_INSTALL_PREFIX:PATH="<โฟลเดอร์โปรเจกต์>/build/windows/x64/runner/Debug" build/windows/x64
flutter build windows
```

### 5. Firebase C++ SDK สำหรับ Windows

Windows build ต้องดาวน์โหลด Firebase C++ SDK ขนาด 806 MB จาก `dl.google.com` ถ้า cache ยังอยู่ที่ `build/windows/x64/firebase_cpp_sdk_windows_12.7.0.zip` จะไม่ต้องดาวน์โหลดใหม่

ถ้าต้องดาวน์โหลดใหม่ CMake จะล้มเหลว เพราะมันต่อผ่าน IPv6 ซึ่งเครือข่ายนี้ไม่ผ่าน ต้องดาวน์โหลดเองด้วย `curl` แบบบังคับ IPv4:

```bash
curl -4 -o build/windows/x64/firebase_cpp_sdk_windows_12.7.0.zip \
  https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_windows_12.7.0.zip
```

---

## สรุปไฟล์ที่เกี่ยวข้อง

### แก้ได้เอง

- `assets/icon/app_icon.png`
- `assets/icon/app_icon_foreground.png`
- `assets/icon/splash_logo.png`
- `assets/icon/splash_logo_android12.png`
- `pubspec.yaml` (บล็อก `flutter_native_splash` และ `flutter_launcher_icons`)

### อ่านอย่างเดียว ห้ามแก้

- `lib/screens/splash_screen.dart` — splash ฝั่ง Windows/Flutter อ่าน `splash_logo.png` อัตโนมัติ
- `windows/runner/resources/app_icon.ico` — generate จาก package
- `android/app/src/main/res/**` — generate จาก package
- `ios/Runner/Assets.xcassets/**` — generate จาก package
- `web/favicon.png`, `web/icons/**` — generate จาก package
