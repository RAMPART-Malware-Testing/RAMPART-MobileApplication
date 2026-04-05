import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rampart/screens/login_screen.dart';
import 'package:rampart/screens/register_screen.dart';
import 'package:rampart/screens/confirm_screen.dart';
import 'package:rampart/screens/forgot_password_screen.dart';
import 'package:rampart/screens/main_screen.dart';
import 'package:rampart/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RAMPART',
      theme: AppTheme.darkTheme,
      initialRoute: '/login',
      getPages: [
        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
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
      ],
      unknownRoute: GetPage(
        name: '/notfound',
        page: () => const LoginScreen(),
      ),
    );
  }
}
