import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // ใช้สีจาก Theme
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'กรุณายอมรับข้อกำหนดและเงื่อนไขการใช้งาน',
              style: GoogleFonts.kanit(),
            ),
            backgroundColor: Colors.red,
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

      if (mounted) {
        // แสดงแจ้งเตือนสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'สมัครสมาชิกสำเร็จ! กรุณายืนยัน OTP',
                    style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate to OTP verification screen
        await Future.delayed(const Duration(seconds: 1));
        Get.toNamed(
          '/confirm-otp',
          arguments: {'email': _emailController.text, 'type': 'register'},
        );
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
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
          child: Column(
            children: [
              // Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildRegisterCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Column(
          children: [
            Text(
              'สมัครสมาชิก',
              style: GoogleFonts.kanit(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'แพลตฟอร์มตรวจสอบมัลแวร์จากระยะไกลด้วยการทดสอบการทำงานแบบอัตโนมัติ',
              style: GoogleFonts.kanit(
                fontSize: 14,
                color: _hintColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRegisterCard() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email Field
            _buildEmailField(),
            const SizedBox(height: 8),

            // Password Field
            _buildPasswordField(),
            const SizedBox(height: 8),

            // Confirm Password Field
            _buildConfirmPasswordField(),
            const SizedBox(height: 12),

            // Register Button
            _buildRegisterButton(),

            const SizedBox(height: 8),
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

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, color: _cyanColor, size: 16),
            const SizedBox(width: 6),
            Text(
              'Password',
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
              if (value.length < 8) {
                return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
              }
              if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                return 'ต้องมีตัวพิมพ์ใหญ่อย่างน้อย 1 ตัว';
              }
              if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                return 'ต้องมีตัวพิมพ์เล็กอย่างน้อย 1 ตัว';
              }
              if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
                return 'ต้องมีตัวเลขอย่างน้อย 1 ตัว';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        // Password requirements
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPasswordRequirement('อย่างน้อย 8 ตัวอักษร'),
              _buildPasswordRequirement('มีตัวพิมพ์ใหญ่และตัวพิมพ์เล็ก'),
              _buildPasswordRequirement('มีตัวเลขอย่างน้อย 1 ตัว'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: _hintColor.withOpacity(0.6),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.kanit(
              fontSize: 11,
              color: _hintColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, color: _cyanColor, size: 16),
            const SizedBox(width: 6),
            Text(
              'Confirm Password',
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
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
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
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _cyanColor.withOpacity(0.7),
                  size: 20,
                ),
                onPressed: _toggleConfirmPasswordVisibility,
                tooltip: _obscureConfirmPassword
                    ? 'แสดงรหัสผ่าน'
                    : 'ซ่อนรหัสผ่าน',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'กรุณายืนยันรหัสผ่าน';
              }
              if (value != _passwordController.text) {
                return 'รหัสผ่านไม่ตรงกัน';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
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
            onPressed: _isLoading ? null : _handleRegister,
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
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'กำลังสมัครสมาชิก...',
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
                        Icons.person_add_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'สมัครสมาชิก',
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

  Widget _buildLoginLink() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'มีบัญชีอยู่แล้ว? ',
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
                // Navigator.pop(context);
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
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
