import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rampart/components/animated_logo_component.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _rotationController;
  late AnimationController _floatController;

  // ใช้สีจาก Theme แทนการกำหนดแบบ hardcode
  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _cyanColor =>
      Theme.of(context).extension<CustomColors>()!.cyanColor;
  Color get _hintColor =>
      Theme.of(context).extension<CustomColors>()!.hintColor;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _rotationController.dispose();
    _floatController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // จำลองการส่งอีเมล
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isLoading = false;
      });

      // Navigate to OTP verification screen
      Get.toNamed(
        '/confirm-otp',
        arguments: {'email': _emailController.text, 'type': 'forgot-password'},
      );
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogoSection(),
                const SizedBox(height: 10),
                _buildForgotPasswordCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(
                0.1 + (_pulseController.value * 0.05),
              ),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: _cyanColor.withOpacity(
                  0.1 + (_pulseController.value * 0.1),
                ),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'ลืมรหัสผ่าน',
              style: GoogleFonts.kanit(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กรอกอีเมลเพื่อรับรหัส OTP รีเซ็ตรหัสผ่าน',
              style: GoogleFonts.kanit(
                fontSize: 14,
                color: _hintColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Email Field
            _buildEmailField(),
            const SizedBox(height: 24),

            // Send OTP Button
            _buildSendOTPButton(),

            const SizedBox(height: 32),

            // Login Link
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.email_outlined, color: _cyanColor, size: 16),
            const SizedBox(width: 6),
            Text(
              'Email Address',
              style: GoogleFonts.kanit(
                color: _textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: _cyanColor.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: TextFormField(
            controller: _emailController,
            style: GoogleFonts.kanit(color: _textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'analyst@rampart.security',
              hintStyle: GoogleFonts.kanit(color: _hintColor, fontSize: 14),
              border: InputBorder.none,
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 8),
                child: Icon(Icons.email_outlined, color: _cyanColor, size: 20),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณากรอกอีเมล';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'กรุณากรอกอีเมลให้ถูกต้อง';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSendOTPButton() {
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
                color: _cyanColor.withOpacity(
                  0.3 + (_pulseController.value * 0.2),
                ),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: _primaryColor.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendOTP,
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
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'กำลังส่ง OTP...',
                        style: GoogleFonts.kanit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'รับ OTP เพื่อยืนยัน',
                        style: GoogleFonts.kanit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'จำรหัสผ่านได้แล้ว? ',
            style: GoogleFonts.kanit(
              color: _hintColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Get.back();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _cyanColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Text(
                  'เข้าสู่ระบบ',
                  style: GoogleFonts.kanit(
                    color: _cyanColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Animated Logo Container
        _buildAnimatedLogo(),
        const SizedBox(height: 10),

        // Title Section
        _buildTitleSection(),
      ],
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedLogoComponent(
      pulseController: _pulseController,
      rotationController: _rotationController,
      shimmerController: _shimmerController,
      size: 140,
    );
  }

  Widget _buildTitleSection() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Column(
          children: [
            Text(
              'RAMPART',
              style: GoogleFonts.kanit(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: _cyanColor.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
