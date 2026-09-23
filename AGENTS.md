# AGENTS.md — RAMPART

## Stack

- **Flutter** (Dart SDK ^3.9.2; toolchain in use: Flutter 3.44.8 stable), **not** Next.js.
- **State mgmt & routing**: GetX (`GetMaterialApp`, named `GetPage` routes, fade transitions).
- **HTTP**: `dio` (AuthService, DashboardService) + `http` package (FileUploadService).
- **Theming**: `flex_color_scheme` with custom `ThemeExtension<CustomColors>`.
- **Font**: Kanit bundled via `fonts` section in pubspec.yaml, runtime fetching disabled.
- **Storage**: `flutter_secure_storage` for tokens + PIN.
- **Charts**: `fl_chart`.
- **Firebase IS present** — `firebase_core` + `firebase_messaging` + `flutter_local_notifications`, initialised after first frame via `addPostFrameCallback`. Auth itself is email/password + OTP + PIN over REST; Firebase is only the push channel.

## Key commands

| Action | Command |
|--------|---------|
| Install deps | `flutter pub get` |
| Analyze | `flutter analyze` |
| Run (all platforms) | `flutter run` |
| Test (single file) | `flutter test test/widget_test.dart` |
| Build APK | `flutter build apk` |
| Build release APK (shrunk, per ABI) | `flutter build apk --release --split-per-abi` |
| Build iOS | `flutter build ios` |
| Build web | `flutter build web` |

---

## ⚠️ PERFORMANCE IS A FUNCTIONAL REQUIREMENT

**Target device: entry-level Android phone — 1 CPU core, 2 GB RAM.** A feature that works on
your dev machine but drops frames or hangs on this device is **not done**. Treat the numbers
below as acceptance criteria, not aspirations.

### Budget

| Metric | Budget | How to check |
|---|---|---|
| Cold start → first frame | **< 2 s** | `flutter run --profile`, watch "time to first frame" |
| Idle CPU (screen open, nothing happening) | **~0%** — no ticker running | DevTools → Performance, or `adb shell top -n 1 \| grep rampart` |
| Idle frame rate | **no continuous repaints** | DevTools → Performance, check the frame chart is flat when idle |
| Release APK, per ABI | **< 30 MB** | `flutter build apk --release --split-per-abi` then `ls -lh` |
| Memory (RSS) | **< 150 MB** | DevTools → Memory, or `adb shell dumpsys meminfo rampart` |
| User input → visual response | **< 100 ms** | DevTools → Performance, check for "shader jank" / long frames |

### Hard rules

**R1 — Nothing blocks `runApp()`.**
No `await` in front of `runApp()` except a fast local read. Network calls, plugin
initialisation, permission dialogs, and Firebase init all go behind
`WidgetsBinding.instance.addPostFrameCallback` or are fired-and-forgotten. A permission
dialog before the first frame is an ANR-grade bug: the user stares at a blank splash until
they answer. (Fixed: `lib/main.dart` now defers Firebase/FCM init.)

**R2 — Zero infinite animations.**
`AnimationController..repeat()` with no end condition keeps the CPU at 60 fps forever, even
when the widget shows nothing animated. Do not write it. If an animation must loop, it must
(a) be the only thing in its own `RepaintBoundary`, and (b) stop when the screen is not
visible. A `repeat()` controller whose `.value` is never read is a **pure bug** — delete it.
(Fixed: removed all `AnimationController..repeat()` loops from UI files.)

**R3 — `AnimatedBuilder` must either read a value or cache its child.**
```dart
// BAD — rebuilds the whole subtree 60x/s
AnimatedBuilder(animation: c, builder: (ctx, child) => Column(children: [...many children]))

// GOOD — static subtree built once, passed as child
AnimatedBuilder(animation: c, builder: (ctx, child) => Container(
  decoration: BoxDecoration(border: Border.all(color: cyan.withValues(alpha: 0.2 + c.value * 0.3))),
  child: child,
), child: const MyExpensiveStaticRow())

// GOOD — only the animated leaf is inside
AnimatedBuilder(animation: c, builder: (ctx, child) => Opacity(opacity: c.value, child: child), child: logo)
```
Also: an **animated `BoxShadow` re-rasterises the whole widget every frame** (a blur is an
offscreen `saveLayer`). Animate border/glow *colour*, not the blur radius. Static shadows
belong outside the builder.
(Fixed: removed unnecessary `AnimatedBuilder` calls and added `child` where needed.)

**R4 — Never call `GoogleFonts.*()` inside `build()`.**
Each call is a style lookup plus a possible font fetch, and it defeats `const`. Fonts are
already applied globally by the theme (`lib/theme/app_theme.dart:39-40`), so
`GoogleFonts.kanit()` is redundant in almost all call sites — plain `TextStyle` inherits
Kanit. Define styles once as `static final` and reuse them.
(Fixed: bundled Kanit fonts, disabled runtime fetching, removed `google_fonts` dependency.)

**R5 — Every `await` on a platform channel costs milliseconds. Batch them.**
`flutter_secure_storage` reads/writes are Keystore encrypt/decrypt round-trips. Four
sequential writes are four round-trips on the UI isolate. Use
`await Future.wait([...])` for independent operations, and **memoise** values that are read
repeatedly (see current violations in `lib/services/authService.dart:66-78` and
`lib/services/pin_service.dart:14-45`).

**R6 — Keep tab state alive with `IndexedStack`.**
`body: _screens[_currentIndex]` (`lib/screens/main_screen.dart:37`) disposes the outgoing
screen and rebuilds the incoming one from scratch on every tab tap — refetch, re-chart,
re-animate, lost scroll position and lost form input. Use
`IndexedStack(index: _currentIndex, children: _screens)`.

**R7 — Long lists use `ListView.builder`, never `Column` inside `SingleChildScrollView`.**
Anything off-screen must not be built. Same for charts and cards: split page content into
slivers so off-screen sections skip build and layout entirely.

**R8 — Images always get `cacheWidth`/`cacheHeight`.**
An unconstrained `Image.asset` decodes the full-resolution bitmap — the 400 KB logo decodes
to several MB of ARGB in RAM. Pass `cacheWidth: (logicalWidth * devicePixelRatio).round()`
and use `FilterQuality.medium`, not `.high`.

**R9 — Dispose everything: controllers, timers, subscriptions, listeners.**
A `StatefulWidget` that creates an `AnimationController`, `Timer`, or
`StreamSubscription` must override `dispose()`.

**R10 — No per-frame allocation.** Use `const` for `SizedBox`, `EdgeInsets`, `Text`,
`IconData`. Hoist `NumberFormat`, `LinearGradient`, and `TextStyle` to `static final`.
Closures and `withOpacity()` colours created inside an animation's builder allocate on
every frame.

### Definition of Done (perf gate)

Before calling any UI or service change complete:

1. `flutter analyze` is clean — no new warnings.
2. `flutter run --profile` on the emulator, and the screen you touched is **idle-flat** in
   DevTools → Performance (no per-frame activity when nothing is happening).
3. Tab-switch, orientation change, and background→foreground tested — no restart of work
   that should have been kept alive.
4. If you added a dependency: state its size cost and whether a lighter alternative exists.
5. If you touched the cold-start path: re-measure time to first frame.

### Anti-patterns seen in this repo (do not repeat)

| Anti-pattern | Where (as of this audit) |
|---|---|
| Permission dialog + 3-plugin init before `runApp()` | `lib/main.dart:18-27`, `lib/services/fcm_service.dart:95-117` |
| `repeat()` controller with no consumer | `lib/screens/reports_screen.dart:32-36` |
| Three `repeat()` controllers per auth screen, 60 fps forever | `login/register/forgot_password/PINSetup/PinVerify` screens |
| `AnimatedBuilder` with no cached `child`, re-laying-out a whole card per frame | `dashboard_screen.dart:205-275`, `settings_screen.dart:177-258`, `submit_file_screen.dart:363-534` |
| `Listenable.merge` of 3 controllers whose values are never read | `lib/components/animated_logo_component.dart:21-57` |
| 135 `GoogleFonts.kanit()` calls inside `build()` | all screens |
| 4 sequential Keystore writes in a row | `lib/services/authService.dart:66-78` |
| Secure-storage reads on every `inactive` lifecycle event | `lib/services/app_lifecycle_observer.dart:35-40` |
| Tab switch destroys screen state | `lib/screens/main_screen.dart:37` |
| 10 of 11 bundled assets unused (~1.7 MB dead weight) | `assets/images/` |
| Release build: no R8 minify, no resource shrink, no ABI split | `android/app/build.gradle.kts:36-42` |
| `withOpacity()` deprecated usage | 122 occurrences (migrate to `withValues(alpha:)`) |

---

## Project layout

```
lib/
  main.dart                          # Entry: PINService -> GetMaterialApp (Firebase/FCM init deferred)
  core/config.dart                   # API base URL (see "Environment" below)
  theme/app_theme.dart               # FlexThemeData light+dark, CustomColors extension
  controllers/
    PIN_controller.dart              # GetX Controller for PIN setup/verify
  services/
    authService.dart                 # Dio singleton, login/register/reset-password/refresh
    pin_service.dart                 # GetX Service, determines initial route
    dashboard_service.dart           # Dio singleton for dashboard stats (currently unwired)
    file_upload_service.dart         # HTTP multipart upload (placeholder host)
    fcm_service.dart                 # Firebase Messaging + local notifications
    app_lifecycle_observer.dart      # Relocks the app on background
    auth_interceptor.dart            # Dio interceptor (COMMENTED OUT, never attached)
    auth_gate.dart                   # DEAD — never instantiated
    storageService.dart              # DEAD — never used
  models/
    dashboard_stats.dart             # DashboardStats, FileStats, MalwareType
    file_upload.dart                 # FileUploadRequest/Response, SelectedFileInfo
  screens/
    login_screen.dart                # Email/password + mock reCAPTCHA checkbox
    register_screen.dart             # Username/email/password
    confirm_screen.dart              # 6-digit OTP
    forgot_password_screen.dart      # Email -> OTP -> new password
    PINSetupScreen.dart              # 6-digit PIN setup with confirm
    PinVerifyScreen.dart             # 6-digit PIN verify (5 attempts max)
    main_screen.dart                 # Bottom nav: Dashboard, Submit, Reports, Settings
    dashboard_screen.dart            # Stats, risk gauge, top malware bar chart
    submit_file_screen.dart          # File picker + upload (100MB max)
    reports_screen.dart              # Filter chips + report cards
    settings_screen.dart             # Toggles, profile, logout
  components/
    animated_logo_component.dart     # Logo mark (static, no controllers)
  test/
    widget_test.dart                   # App-specific: asserts login screen loads
```

Size: 27 Dart files, ~6,270 lines (~4,300 code lines).

## Architecture

```
Screen (StatefulWidget + setState) -> Service (Dio/HTTP) -> REST API
                     ^ GetX Controller (PIN)
                     ^ GetX DI (.put() / .find())
```

- Services are **singletons** (`factory` + `_internal` pattern).
- `PINService.checkLoginStatus()` runs **before** `runApp()` to decide the initial route
  (`/login`, `/pin-verify`, `/home`) — `lib/services/pin_service.dart:14-29`.
- Routes are defined declaratively in `GetMaterialApp.getPages[]` (`lib/main.dart:43-83`).
- Only `PINController` (a `GetxController`) and `PINService` (a `GetxService`) use GetX state.
  Everything else is plain `setState` (35 call sites).
- **Inconsistencies to be aware of**: two near-identical `Dio` singletons (AuthService and
  DashboardService) instead of one shared client; `flutter_secure_storage` instantiated in
  7 files; **three competing token keys** (`session_token`, `jwt_token`, `token`) plus a
  typo key `deivetoken` that is read (`authService.dart:51`) and deleted (`:302`) but never
  written, so the login `deviceToken` header is always absent.

## Environment

- API base URL: `http://10.212.51.8:8006` (`lib/core/config.dart:3`) — a ZeroTier VPN
  address, reachable only while the device is on that network. **Plain HTTP, no TLS.**
- `targetSdk` is 36. Two consequences the build config currently ignores:
  - Cleartext HTTP is **blocked by default** from API 28 up. Reaching `http://…:8006` on a
    release build needs `android:usesCleartextTraffic="true"` (or a scoped network security
    config) in `android/app/src/main/AndroidManifest.xml`.
  - `POST_NOTIFICATIONS` is **not declared** in the main manifest, so on Android 13+ local
    notifications are silently dropped. `INTERNET` is likewise declared **only** in
    `src/debug/` and `src/profile/` manifests — a release build has no network at all.
- Build config gaps: release `buildTypes` has **no** `isMinifyEnabled` / `isShrinkResources`
  and there is **no** ABI split configured (`android/app/build.gradle.kts:36-42`), so a
  release APK ships all ABIs unshrunk. `android/gradle.properties:9` sets
  `kotlin.incremental=false` (dev build speed only, not app perf).

## Verified status: what is real vs mocked

Do not trust a screen's appearance as evidence a backend exists.

| Feature | Status | Evidence |
|---|---|---|
| Login / Register / OTP / Reset password | **REAL** | `authService.dart:53-63, 145-148, 108-114` |
| Forgot password flow | **BROKEN** | `forgot_password_screen.dart:53-68` shows success and navigates even when the API reports failure |
| PIN setup / verify | **REAL** | `PIN_controller.dart:51-71, 79-116`; keypad is wired |
| Dashboard stats | **MOCK + renders nothing** | fetch is commented out (`dashboard_screen.dart:62-67`), `_stats` is never assigned, so only the welcome card renders. `DashboardService.summary()` has zero callers. |
| Submit/upload file | **BROKEN** | picks a file fine, but posts to the placeholder host `https://your-api-server.com/api` (`file_upload_service.dart:8`); progress bar is faked (`submit_file_screen.dart:246-277`) |
| Reports list | **MOCK** | 6 hardcoded reports (`reports_screen.dart:397-430`), action buttons have empty `onPressed` |
| Settings | **MOCK/PARTIAL** | hardcoded profile `analyst@rampart.security` (`settings_screen.dart:228-243`); toggles persist nothing; dark-mode toggle changes no theme |
| Push notifications | **REAL** | full FCM + local-notification wiring; blocked on Android 13+ until `POST_NOTIFICATIONS` is declared |
| Logout | **BROKEN** | navigates only (`settings_screen.dart:86`); `clearAuthData()` is implemented (`authService.dart:295-305`) but **nothing calls it**, so tokens survive and the app re-locks instead of logging out |
| reCAPTCHA | **MOCK** | cosmetic checkbox toggling a bool; the `flutter_recaptcha_v2_compat` dependency is unused |
| Session/refresh | **PARTIAL** | `refreshAccessToken()` runs on every PIN verify (`PIN_controller.dart:90`) with no expiry check; no token is ever attached to other requests because the interceptor is disabled |

**Unused dependencies:** `flutter_recaptcha_v2_compat`, `mime`, `path` (0 imports).
**Dead code:** `auth_gate.dart`, `storageService.dart`, `auth_interceptor.dart`,
`DashboardService.summary()/recentActivities()`, `lightTheme`, `AuthGate`.

## Known defects

- `AuthInterceptor` is never attached — `authService.dart:6,29`, `dashboard_service.dart:26`
  (import and `addInterceptor` are both commented out). The code inside is also inert: the
  header injection is commented (`auth_interceptor.dart:11-13`) and `onError` deletes the
  wrong key `token` (`:22`).
- Session-type guards in `registerConfirm`, `resetPasswordConfirm`, and
  `recentActivities` use `== null && != type` where `||` is needed, so a wrong session type
  is not rejected (`authService.dart:172, 219`; `dashboard_service.dart:56`). The login path
  uses the correct `||` — copy that.
- PIN fallback `123456` when `user_pin` is missing (`PIN_controller.dart:84`).
- Only `theme:` is wired in `main.dart:41` — no `darkTheme:`/`themeMode:`. The light theme is
  defined but unused, and `CustomColors` is attached **only** to `darkTheme`
  (`app_theme.dart:77-85`) while screens dereference it with `!` — applying the light theme
  would crash.
- `_pulseController` in `reports_screen.dart:32-36` is created, repeated, and never read —
  a continuously regenerating notification with no effect.
- `withOpacity()` is deprecated: 122 occurrences, migrate to `withValues(alpha:)`.
- No CI/CD, no `.vscode/`, no environment files.

## Existing docs (read with caution)

- `README.md` — 2 lines, just `flutter pub get`.
- `API_EXAMPLE.md` — dashboard endpoint spec; documents `GET /dashboard/stats` but the code
  implements `POST /api/analy/v1/dashboard/summary`. Stale.
- `DASHBOARD_README.md` — dashboard screen mock config (`dashboard_stats.dart` model shape).
- `UPLOAD_FILE_README.md` — file upload flow; describes the placeholder host.
- `DESIGN.md` — **belongs to a different project** (a Next.js/Firebase "RAMPART Chat"). Not
  this app's architecture. Ignore it, or delete it.