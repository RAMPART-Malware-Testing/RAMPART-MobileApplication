import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rampart/components/animated_logo_component.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRecaptchaVerified = false;

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
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      // ตรวจสอบว่ายืนยัน reCAPTCHA แล้วหรือยัง
      if (!_isRecaptchaVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'กรุณายืนยันตัวตนด้วย reCAPTCHA ก่อน',
              style: GoogleFonts.kanit(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _isLoading = false;
      });

      // Navigate to home screen on successful login
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'เข้าสู่ระบบสำเร็จ!',
                style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      Get.offAllNamed('/home');
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
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
                _buildLoginCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
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
              'เข้าสู่ระบบ',
              style: GoogleFonts.kanit(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'แพลตฟอร์มตรวจสอบมัลแวร์จากระยะไกลด้วยการทดสอบการทำงานแบบอัตโนมัติ',
              style: GoogleFonts.kanit(
                fontSize: 14,
                color: _hintColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Email Field
            _buildEmailField(),
            const SizedBox(height: 8),

            // Password Field
            _buildPasswordField(),
            const SizedBox(height: 8),

            // reCAPTCHA Placeholder
            _buildRecaptchaSection(),
            const SizedBox(height: 8),

            // Login Button
            _buildLoginButton(),
            const SizedBox(height: 32),

            // Register Link
            _buildRegisterLink(),
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

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, color: _cyanColor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Password',
                style: GoogleFonts.kanit(
                  color: _textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  Get.toNamed('/forgot-password');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'ลืมรหัสผ่าน ?',
                    style: GoogleFonts.kanit(
                      color: _cyanColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: _cyanColor.withOpacity(0.5),
                    ),
                  ),
                ),
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
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.kanit(color: _textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.kanit(color: _hintColor, fontSize: 14),
              border: InputBorder.none,
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 8),
                child: Icon(Icons.lock_outline, color: _cyanColor, size: 20),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _cyanColor.withOpacity(0.7),
                  size: 20,
                ),
                onPressed: _togglePasswordVisibility,
                tooltip: _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณากรอกรหัสผ่าน';
              }
              if (value.length < 6) {
                return 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecaptchaSection() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return GestureDetector(
          onTap: !_isRecaptchaVerified
              ? () {
                  setState(() {
                    _isRecaptchaVerified = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            'ยืนยันตัวตนสำเร็จ! ✓',
                            style: GoogleFonts.kanit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isRecaptchaVerified
                  ? Colors.green.withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isRecaptchaVerified
                    ? Colors.green
                    : _cyanColor.withOpacity(
                        0.3 + (_pulseController.value * 0.2),
                      ),
                width: 2,
              ),
              boxShadow: _isRecaptchaVerified
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 0,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: _cyanColor.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Checkbox-style indicator
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _isRecaptchaVerified
                        ? Colors.green
                        : Colors.transparent,
                    border: Border.all(
                      color: _isRecaptchaVerified ? Colors.green : _hintColor,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _isRecaptchaVerified
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 16),

                // Text and Icon
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isRecaptchaVerified
                                ? Icons.verified_user
                                : Icons.security_outlined,
                            color: _isRecaptchaVerified
                                ? Colors.green
                                : _cyanColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isRecaptchaVerified
                                  ? 'ยืนยันตัวตนสำเร็จ'
                                  : 'ฉันไม่ใช่บอท',
                              style: GoogleFonts.kanit(
                                color: _isRecaptchaVerified
                                    ? Colors.green
                                    : _textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!_isRecaptchaVerified) ...[
                        const SizedBox(height: 4),
                        Text(
                          'คลิกเพื่อยืนยันตัวตน',
                          style: GoogleFonts.kanit(
                            color: _hintColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // reCAPTCHA-style logo
                if (!_isRecaptchaVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: _cyanColor,
                          size: 16,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'reCAPTCHA',
                          style: GoogleFonts.roboto(
                            color: _hintColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isRecaptchaVerified = false;
                      });
                    },
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: _cyanColor,
                      size: 20,
                    ),
                    tooltip: 'รีเซ็ต',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginButton() {
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
            onPressed: _isLoading ? null : _handleLogin,
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
                        'กำลังเข้าสู่ระบบ...',
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
                      const Icon(
                        Icons.login_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'เข้าสู่ระบบ',
                        style: GoogleFonts.kanit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildRegisterLink() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ยังไม่มีบัญชี? ',
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
                Get.toNamed('/register');
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
                  'สร้างบัญชี',
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
          const SizedBox(width: 4),
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
