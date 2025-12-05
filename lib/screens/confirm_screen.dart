import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({Key? key}) : super(key: key);

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = 60;
  Timer? _timer;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  String? _email;
  String? _verificationType; // 'register', 'login', 'forgot-password'

  // ใช้สีจาก Theme
  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _cyanColor =>
      Theme.of(context).extension<CustomColors>()!.cyanColor;
  Color get _blueColor =>
      Theme.of(context).extension<CustomColors>()!.blueColor;
  Color get _hintColor =>
      Theme.of(context).extension<CustomColors>()!.hintColor;

  @override
  void initState() {
    super.initState();

    // Get email and verification type from arguments
    _email = Get.arguments?['email'] ?? 'your-email@example.com';
    _verificationType = Get.arguments?['type'] ?? 'register';

    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Start resend timer
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _shimmerController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimer = 60;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _handleVerifyOTP() async {
    // Get OTP code
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'กรุณากรอก OTP ให้ครบ 6 หลัก',
            style: GoogleFonts.kanit(),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    // Show success message based on verification type
    String successMessage;
    String navigateTo;

    switch (_verificationType) {
      case 'login':
        successMessage = 'ยืนยัน OTP สำเร็จ! กำลังเข้าสู่ระบบ... ✓';
        navigateTo = '/home'; // TODO: Change to your home/dashboard route
        break;
      case 'forgot-password':
        successMessage = 'ยืนยัน OTP สำเร็จ! กรุณาตั้งรหัสผ่านใหม่';
        navigateTo = '/reset-password'; // TODO: Create reset password screen
        break;
      case 'register':
      default:
        successMessage = 'ยืนยัน OTP สำเร็จ! บัญชีของคุณพร้อมใช้งานแล้ว ✓';
        navigateTo = '/login';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                successMessage,
                style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate based on verification type
    await Future.delayed(const Duration(seconds: 1));

    if (navigateTo == '/home') {
      Get.offAllNamed('/home');
    } else if (navigateTo == '/reset-password') {
      // For now, redirect to login as /reset-password doesn't exist yet
      // TODO: Navigate to reset password screen
      Get.offAllNamed('/login');
    } else {
      Get.offAllNamed(navigateTo);
    }
  }

  void _handleResendOTP() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    // Clear OTP fields
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.send, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'ส่ง OTP ใหม่สำเร็จ!',
              style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: _cyanColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Restart timer
    _startResendTimer();
  }

  void _onOTPChanged(int index, String value) {
    setState(() {}); // Rebuild to update border color

    if (value.isNotEmpty) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last field, remove focus and auto-verify if all fields filled
        _focusNodes[index].unfocus();

        // Check if all OTP fields are filled
        String otp = _otpControllers.map((c) => c.text).join();
        if (otp.length == 6) {
          // Auto-verify after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _handleVerifyOTP();
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0f172a),
              _backgroundColor,
              const Color(0xFF1e293b),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildOTPCard(),
                  const SizedBox(height: 24),
                  _buildBackButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Column(
          children: [
            // Icon with animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cyanColor.withOpacity(0.3 + (_pulseController.value * 0.2)),
                    _blueColor.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _cyanColor.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cyanColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: _cyanColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title - Dynamic based on verification type
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [_textColor, _cyanColor, _textColor],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              child: Text(
                _getTitle(),
                style: GoogleFonts.kanit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              _getDescription(),
              style: GoogleFonts.kanit(
                fontSize: 16,
                color: _textColor.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ที่ส่งไปยัง $_email',
              style: GoogleFonts.kanit(
                fontSize: 14,
                color: _cyanColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _buildOTPCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1 + (_pulseController.value * 0.05)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: _cyanColor.withOpacity(0.1 + (_pulseController.value * 0.1)),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          // OTP Input Fields
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              6,
              (index) => _buildOTPField(index),
            ),
          ),
          const SizedBox(height: 32),

          // Verify Button
          _buildVerifyButton(),
          const SizedBox(height: 24),

          // Resend Section
          _buildResendSection(),
        ],
      ),
    );
  }

  Widget _buildOTPField(int index) {
    return Expanded(
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _otpControllers[index].text.isNotEmpty
                ? _cyanColor
                : Colors.white.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: _otpControllers[index].text.isNotEmpty
              ? [
                  BoxShadow(
                    color: _cyanColor.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: GoogleFonts.kanit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _textColor,
              height: 1.2,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) => _onOTPChanged(index, value),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [_primaryColor, _cyanColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _cyanColor.withOpacity(0.3 + (_pulseController.value * 0.2)),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'ยืนยัน OTP',
                        style: GoogleFonts.kanit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        // Timer or Resend Button
        if (!_canResend)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: _hintColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'ส่ง OTP ใหม่ได้ใน $_resendTimer วินาที',
                style: GoogleFonts.kanit(
                  color: _hintColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
        else
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _handleResendOTP,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _cyanColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: _cyanColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'ส่ง OTP ใหม่',
                      style: GoogleFonts.kanit(
                        color: _cyanColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Help Text
        Text(
          'ไม่ได้รับรหัส OTP?',
          style: GoogleFonts.kanit(
            color: _hintColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Get.back();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded, color: _cyanColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _getBackButtonText(),
                style: GoogleFonts.kanit(
                  color: _cyanColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: _cyanColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods to get dynamic text based on verification type
  String _getTitle() {
    switch (_verificationType) {
      case 'login':
        return 'ยืนยันการเข้าสู่ระบบ';
      case 'forgot-password':
        return 'ยืนยันตัวตน';
      case 'register':
      default:
        return 'ยืนยันอีเมล';
    }
  }

  String _getDescription() {
    switch (_verificationType) {
      case 'login':
        return 'กรุณากรอกรหัส OTP 6 หลัก\nเพื่อเข้าสู่ระบบ';
      case 'forgot-password':
        return 'กรุณากรอกรหัส OTP 6 หลัก\nเพื่อรีเซ็ตรหัสผ่าน';
      case 'register':
      default:
        return 'กรุณากรอกรหัส OTP 6 หลัก\nเพื่อยืนยันการสมัครสมาชิก';
    }
  }

  String _getBackButtonText() {
    switch (_verificationType) {
      case 'login':
        return 'กลับไปหน้าเข้าสู่ระบบ';
      case 'forgot-password':
        return 'กลับไปหน้าลืมรหัสผ่าน';
      case 'register':
      default:
        return 'กลับไปหน้าสมัครสมาชิก';
    }
  }
}
