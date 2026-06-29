# AGENTS.md — RAMPART

## Stack

- **Flutter** (Dart SDK ^3.9.2, Flutter >=3.35), **not** Next.js.
- **State mgmt & routing**: GetX (`GetMaterialApp`, named `GetPage` routes, fade transitions).
- **HTTP**: `dio` (AuthService, DashboardService) + `http` package (FileUploadService).
- **Theming**: `flex_color_scheme` with custom `ThemeExtension<CustomColors>`.
- **Font**: Google Fonts Kanit.
- **Storage**: `flutter_secure_storage` for tokens + PIN.
- **Charts**: `fl_chart`.
- **No Firebase** — auth is email/password + OTP + PIN via REST API.

## Key commands

| Action | Command |
|--------|---------|
| Install deps | `flutter pub get` |
| Analyze | `flutter analyze` |
| Run (all platforms) | `flutter run` |
| Test (single file) | `flutter test test/widget_test.dart` |
| Build APK | `flutter build apk` |
| Build iOS | `flutter build ios` |
| Build web | `flutter build web` |

## Project layout

```
lib/
  main.dart                          # Entry: init PINService -> GetMaterialApp
  core/config.dart                   # Single ngrok API base URL
  theme/app_theme.dart               # FlexThemeData light+dark, CustomColors extension
  controllers/
    PIN_controller.dart              # GetX Controller for PIN setup/verify
  services/
    authService.dart                 # Dio singleton, login/register/reset-password
    pin_service.dart                 # GetX Service, determines initial route
    dashboard_service.dart           # Dio singleton for dashboard stats
    file_upload_service.dart         # HTTP multipart upload
    auth_interceptor.dart            # Dio interceptor (COMMENTED OUT)
    storageService.dart              # Simple FlutterSecureStorage wrapper
  models/
    dashboard_stats.dart             # DashboardStats, FileStats, MalwareType
    file_upload.dart                 # FileUploadRequest/Response, SelectedFileInfo
  screens/
    login_screen.dart                # Email/password + reCAPTCHA
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
    animated_logo_component.dart     # Pulse + rotation + shimmer logo
test/
  widget_test.dart                   # Default counter test (NOT customized)
```

## Architecture

```
Screen (StatefulWidget) -> Service (Dio/HTTP) -> REST API (ngrok tunnel)
                           ^ GetX Controller (PIN)
                           ^ GetX DI (.put() / .find())
```

- Services are **singletons** (`factory` + `_internal` pattern).
- `PINService` runs **before** `runApp()` to decide initial route (`/login`, `/pin-verify`, `/home`).
- Routes are defined declaratively in `GetMaterialApp.getPages[]`.

## Gotchas & incomplete items

- **AuthInterceptor** (`auth_interceptor.dart`) is **commented out** in both AuthService and DashboardService — auth tokens are NOT sent automatically.
- `FileUploadService.baseUrl` is a placeholder (`https://your-api-server.com/api`) — must be updated.
- Dashboard screen uses a **hardcoded placeholder token**.
- `clearAuthData()` in AuthService is **empty** (logout only navigates, doesn't clear storage).
- `PinVerifyScreen` keypad `onPressed` handlers are **commented out** (digit entry is non-functional).
- PIN default fallback: `123456` (if `user_pin` key is missing from storage).
- App currently only applies `darkTheme` in `main.dart` (light theme defined but unused).
- Settings screen uses **mock hardcoded user** ("Analyst User / analyst@rampart.security").
- `withOpacity()` usage has deprecation warnings — should migrate to `withValues()` (Flutter 3.35+).
- Only 1 test file exists and it's the default Flutter counter test — not app-specific.
- No CI/CD workflows, no `.vscode/` config, no environment files.

## Existing docs (agent should read)

- `README.md` — 2 lines, just `flutter pub get`
- `API_EXAMPLE.md` — Dashboard API endpoint specs
- `DASHBOARD_README.md` — Dashboard screen mock config
- `UPLOAD_FILE_README.md` — File upload flow (exists but not read above)
- `DESIGN.md` — Architectural documentation (created separately)
