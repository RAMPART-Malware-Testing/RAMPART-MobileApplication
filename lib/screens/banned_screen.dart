import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rampart/services/authService.dart';
import '../theme/app_theme.dart';

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cyanColor =
        Theme.of(context).extension<CustomColors>()?.cyanColor ?? Colors.cyan;
    final hintColor =
        Theme.of(context).extension<CustomColors>()?.hintColor ?? Colors.grey;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0f172a), Color(0xFF1e293b)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.block,
                        size: 64,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'บัญชีของคุณถูกระงับการใช้งาน',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'บัญชีของคุณถูกระงับการใช้งานโดยผู้ดูแลระบบ\nหากมีข้อสงสัยหรือต้องการอุทธรณ์\nกรุณาติดต่อทีมผู้ดูแลระบบ',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 14,
                        color: hintColor,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.email_outlined,
                                  color: cyanColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'ติดต่อเรา',
                                style: TextStyle(
                                  fontFamily: 'Kanit',
                                  fontSize: 14,
                                  color: hintColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            'rampartmalwareanalysis@gmail.com',
                            style: TextStyle(
                              fontFamily: 'Kanit',
                              fontSize: 14,
                              color: cyanColor,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await authService.clearAuthData();
                          Get.offAllNamed('/login');
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        label: const Text(
                          'กลับไปหน้าเข้าสู่ระบบ',
                          style: TextStyle(
                            fontFamily: 'Kanit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyanColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
