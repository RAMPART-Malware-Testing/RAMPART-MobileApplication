import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rampart/components/animated_logo_component.dart';
import 'package:rampart/services/authService.dart';
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _rotationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isRecaptchaVerified) {
      _showSnackBar('กรุณายืนยันตัวตนด้วย reCAPTCHA ก่อน', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    var res = await authService.login(email:_emailController.text,password: _passwordController.text);
    setState(() => _isLoading = false);
    if (res['success']) {
      _showSnackBar('เข้าสู่ระบบสำเร็จ!', Colors.green, icon: Icons.check_circle);
      if (res['data']['bypass_otp'] == true) {
        Get.offAllNamed('/home');
        return;
      }
      Get.offAllNamed('/confirm-otp',arguments: { "type":"login"});
    } else {
      _showSnackBar(res['message'], Colors.red, icon: Icons.check_circle);
    }
  }

  void _showSnackBar(String message, Color color, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
            ],
            Text(
              message,
              style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
              children: [
                AnimatedLogoComponent(
                  pulseController: _pulseController,
                  rotationController: _rotationController,
                  shimmerController: _shimmerController,
                  size: 140,
                ),
                const SizedBox(height: 10),
                Text(
                  'RAMPART',
                  style: GoogleFonts.kanit(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: _cyanColor.withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
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
      builder: (context, child) => Container(
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
      ),
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
              ),
            ),
            Text(
              'เข้าสู่ระบบเพื่อใช้บริการวิเคราะห์มัลแวร์',
              style: GoogleFonts.kanit(fontSize: 14, color: _hintColor),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'analyst@rampart.security',
              icon: Icons.email_outlined,
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'กรุณากรอกอีเมลให้ถูกต้อง'
                  : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (v) => (v == null || v.length < 6)
                  ? 'รหัสผ่านต้องมี 6 ตัวขึ้นไป'
                  : null,
            ),
            const SizedBox(height: 24),
            _buildRecaptcha(),
            const SizedBox(height: 24),
            _buildLoginButton(),
            const SizedBox(height: 16),
            _buildRegisterLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _cyanColor, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.kanit(
                  color: _textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (isPassword)
              GestureDetector(
                onTap: () => Get.toNamed('/forgot-password'),
                child: Text(
                  'ลืมรหัสผ่าน ?',
                  style: GoogleFonts.kanit(
                    color: _cyanColor,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          style: GoogleFonts.kanit(color: _textColor, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.kanit(color: _hintColor, fontSize: 14),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            prefixIcon: Icon(icon, color: _cyanColor, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _cyanColor.withOpacity(0.7),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecaptcha() {
    return GestureDetector(
      onTap: () => setState(() => _isRecaptchaVerified = !_isRecaptchaVerified),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isRecaptchaVerified
              ? Colors.green.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRecaptchaVerified
                ? Colors.green
                : _cyanColor.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isRecaptchaVerified
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: _isRecaptchaVerified ? Colors.green : _hintColor,
            ),
            const SizedBox(width: 12),
            Text(
              _isRecaptchaVerified ? 'ยืนยันตัวตนสำเร็จ' : 'ฉันไม่ใช่บอท',
              style: GoogleFonts.kanit(
                color: _isRecaptchaVerified ? Colors.green : _textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(Icons.security, color: _cyanColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [_primaryColor, _cyanColor]),
        boxShadow: [
          BoxShadow(
            color: _cyanColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
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
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'เข้าสู่ระบบ',
                style: GoogleFonts.kanit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('ยังไม่มีบัญชี? ', style: GoogleFonts.kanit(color: _hintColor)),
        GestureDetector(
          onTap: () => Get.toNamed('/register'),
          child: Text(
            'สร้างบัญชี',
            style: GoogleFonts.kanit(
              color: _cyanColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
