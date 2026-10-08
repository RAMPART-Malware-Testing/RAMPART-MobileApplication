import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:rampart/services/fcm_service.dart';
import 'package:rampart/services/network_monitor_service.dart';
import 'package:rampart/services/notification_service.dart';
import 'package:rampart/screens/PINSetupScreen.dart';
import 'package:rampart/screens/PinVerifyScreen.dart';
import 'package:rampart/screens/login_screen.dart';
import 'package:rampart/screens/register_screen.dart';
import 'package:rampart/screens/confirm_screen.dart';
import 'package:rampart/screens/forgot_password_screen.dart';
import 'package:rampart/screens/main_screen.dart';
import 'package:rampart/screens/analysis_progress_screen.dart';
import 'package:rampart/screens/analysis_result_screen.dart';
import 'package:rampart/screens/public_reports_screen.dart';
import 'package:rampart/screens/activity_history_screen.dart';
import 'package:rampart/screens/banned_screen.dart';
import 'package:rampart/screens/help_screen.dart';
import 'package:rampart/screens/profile_edit_screen.dart';
import 'package:rampart/screens/reset_password_screen.dart';
import 'package:rampart/screens/tool_report_screen.dart';
import 'package:rampart/screens/splash_screen.dart';
import 'package:rampart/services/app_lifecycle_observer.dart';
import 'package:rampart/services/pin_service.dart';
import 'package:rampart/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Widget? _app;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final pinService = PINService();
    final monitor = NetworkMonitorService();
    Intl.defaultLocale = 'th';
    await initializeDateFormatting('th');

    try {
      await pinService.checkLoginStatus();
    } catch (e) {
      debugPrint('[bootstrap] checkLoginStatus failed: $e');
      if (mounted) {
        setState(() => _failure = 'อ่านข้อมูลการเข้าสู่ระบบไม่สำเร็จ กำลังเข้าสู่ระบบใหม่');
      }
    }
    if (!mounted) return;
    Get.put(pinService);
    Get.put(NotificationService());
    Get.put(monitor);
    monitor.onReconnect = _initPush;

    setState(() {
      _failure = null;
      _app = AppLifecycleObserver(
        child: MyApp(initialRoute: pinService.initialRoute),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await monitor.checkNow();
      if (!monitor.isOnline.value) return;
      await _initPush();
    });
  }

  Future<void> _initPush() async {
    final ready = await FcmService().initialize();
    if (!ready || !mounted) return;
    FcmService().handlePendingInitialMessage();
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          const SplashScreen(),
          if (_failure != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Text(
                _failure!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final String  initialRoute;
  const MyApp({super.key, required this.initialRoute});
  
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RAMPART',
      theme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      getPages: [
        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/pin-verify',
          page: () => const PinVerifyScreen(), 
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/pin-setup',
          page: () => const PinSetupScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/register',
          page: () => const RegisterScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/confirm-otp',
          page: () => const ConfirmScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/forgot-password',
          page: () => const ForgotPasswordScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/home',
          page: () => const MainScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/analysis-progress',
          page: () => const AnalysisProgressScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/analysis-result',
          page: () => const AnalysisResultScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/public-reports',
          page: () => const PublicReportsScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/banned',
          page: () => const BannedScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/profile-edit',
          page: () => const ProfileEditScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/reset-password',
          page: () => const ResetPasswordScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/activity-history',
          page: () => const ActivityHistoryScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/tool-report',
          page: () => const ToolReportScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/help',
          page: () => const HelpScreen(),
          transition: Transition.fadeIn,
        ),
      ],
      unknownRoute: GetPage(
        name: '/notfound',
        page: () => const LoginScreen(),
      ),
    );
  }
}
