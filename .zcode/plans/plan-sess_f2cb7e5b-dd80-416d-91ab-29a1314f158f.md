Plan: Remove all unnecessary animations to meet performance budget for 1‑CPU/2 GB RAM devices

Goals
- Eliminate all AnimationController..repeat() loops that run at 60 fps when the UI is idle.
- Remove AnimatedBuilder branches that cause per‑frame rebuild/re‑layout of static sub‑trees.
- Keep UI appearance (logos, cards, etc.) as static images or widgets; no functional animation is required per user request.
- Ensure no compile errors and that the app still runs and navigates correctly.

Files to modify (based on earlier explore results and audit):
| File | Changes |
|------|---------|
| lib/components/animated_logo_component.dart | - Remove the three AnimationController fields (pulseController, rotationController, shimmerController).<br>- Remove constructor parameters for those controllers.<br>- Remove initState/dispose (if any) and TickerProviderStateMixin.<br>- Replace the AnimatedBuilder with a static Stack containing the white‑glow Container and the Image.asset.<br>- Keep the imagePath and size parameters; the glow can be a static BoxDecoration with constant blurRadius and spreadRadius. |
| lib/screens/login_screen.dart | - Remove _pulseController, _shimmerController, _rotationController fields.<br>- Remove their initialization in initState and disposal in dispose.<br>- Remove TickerProviderStateMixin if no other controllers remain.<br>- Replace the AnimatedBuilder that wraps the logo with the static logo widget (just pass the child: Form(...) directly).<br>- Keep the Form and other UI unchanged. |
| lib/screens/register_screen.dart | Same changes as login_screen.dart. |
| lib/screens/forgot_password_screen.dart | Same changes as login_screen.dart. |
| lib/screens/PINSetupScreen.dart | Same changes as login_screen.dart. |
| lib/screens/PinVerifyScreen.dart | Same changes as login_screen.dart. |
| lib/screens/dashboard_screen.dart | - Remove _pulseController field, its initState/dispose, and TickerProviderStateMixin if unused elsewhere.<br>- The AnimatedBuilder currently has no child:; replace it with the subtree that was inside the builder (the Column with welcome card, stats, chart, list).<br>- If any other animations exist (none per audit), remove them. |
| lib/screens/settings_screen.dart | - Remove _pulseController field, its initState/dispose, and TickerProviderStateMixin.<br>- There are two AnimatedBuilder s (profile card and logout button). Replace each with its static subtree (move the builder body out and use it as the widget directly).<br>- Keep UI unchanged otherwise. |
| lib/screens/submit_file_screen.dart | - Remove _pulseController field, its initState/dispose, and TickerProviderStateMixin.<br>- Replace the AnimatedBuilder (no child: param) with the subtree that was inside the builder (the upload card UI).<br>- Keep all other logic (file picker, upload, progress simulation). |
| lib/screens/reports_screen.dart | - Remove _pulseController field, its initState/dispose, and TickerProviderStateMixin.<br>- No AnimatedBuilder present, so just delete the controller declarations and related methods. |

Steps for each file
1. Delete the controller field declarations.
2. Delete the initState block that creates and starts the controllers (.repeat() calls).
3. Dispose block that disposes the controllers (if present).
4. Remove TickerProviderStateMixin from the class if no other controllers remain in that class.
5. Locate the AnimatedBuilder usage:
   - If it has a child: parameter, replace the whole AnimatedBuilder with its child (the subtree is already built once).
   - If it lacks a child: parameter, take the widget tree currently returned by the builder function and use it directly as the widget in that spot.
6. Ensure the resulting widget tree compiles (no missing parentheses, correct indentation).
7. Run flutter analyze to confirm no new errors.
8. (Optional) Run the app on an emulator or device to verify UI looks static and navigation works.

Why this meets the performance budget
- Removes per‑frame ticker callbacks → CPU can idle when the screen is static.
- Eliminates AnimatedBuilder rebuilds → no per‑frame layout or BuildContext work.
- Stops continuous BoxShadow blur re‑rasterization (saveLayer) → GPU load drops.
- No change to functionality; all user interactions (button presses, form input) remain intact.

Post‑implementation verification (to be done after the plan is approved)
- flutter run --profile and observe DevTools → Performance frame chart: idle sections should be flat (no spikes).
- Confirm release APK size with flutter build apk --release --split-per-abi is under 30 MB per ABI.
- Verify that navigation, login, PIN, upload, etc. still work via manual testing.

If the user wishes to keep any subtle animation (e.g., a brief pulse on startup), we can discuss adding a time‑limited animation (run forward() once then dispose) but per the current request “เอาออกเลย” we will remove them entirely.