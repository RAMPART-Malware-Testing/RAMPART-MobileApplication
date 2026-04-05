import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rampart/components/animated_logo_component.dart';
import 'package:rampart/services/authService.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _rotationController;

  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _cyanColor => Theme.of(context).extension<CustomColors>()!.cyanColor;
  Color get _hintColor => Theme.of(context).extension<CustomColors>()!.hintColor;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _shimmerController = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat();
    _rotationController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _rotationController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    var res = await authService.resetPassword(email:_emailController.text);
    if (res['success']) {
      _showSnackBar('ส่งรหัส OTP ไปยังอีเมลของคุณแล้ว!', Colors.green, icon: Icons.check_circle);
      Get.offAllNamed('/confirm-otp',arguments: { "type":"forgot-passwd"});
    } else {
      _showSnackBar(res['message'], Colors.red, icon: Icons.check_circle);
    }

    try {
      _showSnackBar('ส่งรหัส OTP ไปยังอีเมลของคุณแล้ว', Colors.green, icon: Icons.mark_email_read_rounded);
      Get.offAllNamed('/confirm-otp', arguments: { "type":"forgot-passwd"});
    } catch (e) {
      _showSnackBar('ไม่พบอีเมลนี้ในระบบ หรือเกิดข้อผิดพลาดกรุณาลองใหม่', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 12)],
            Expanded(child: Text(message, style: GoogleFonts.kanit(fontWeight: FontWeight.w600))),
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
            colors: [const Color(0xFF0f172a), _backgroundColor, const Color(0xFF1e293b)],
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
                    shadows: [Shadow(color: _cyanColor.withOpacity(0.5), blurRadius: 20)],
                  ),
                ),
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
      builder: (context, child) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1 + (_pulseController.value * 0.05)), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
            BoxShadow(color: _cyanColor.withOpacity(0.1 + (_pulseController.value * 0.1)), blurRadius: 30, spreadRadius: -5),
          ],
        ),
        child: child,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text('ลืมรหัสผ่าน', style: GoogleFonts.kanit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'กรอกอีเมลเพื่อรับรหัส OTP สำหรับรีเซ็ตรหัสผ่าน',
              style: GoogleFonts.kanit(fontSize: 14, color: _hintColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            _buildEmailField(),
            const SizedBox(height: 32),

            _buildSendOTPButton(),
            const SizedBox(height: 24),
            
            _buildBackToLoginLink(),
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
            Text('Email Address', style: GoogleFonts.kanit(color: _textColor, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          style: GoogleFonts.kanit(color: _textColor, fontSize: 15),
          keyboardType: TextInputType.emailAddress,
          validator: (v) => (v == null || !v.contains('@')) ? 'กรุณากรอกอีเมลให้ถูกต้อง' : null,
          decoration: InputDecoration(
            hintText: 'analyst@rampart.security',
            hintStyle: GoogleFonts.kanit(color: _hintColor, fontSize: 14),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            prefixIcon: Icon(Icons.email_outlined, color: _cyanColor, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
        ),
      ],
    );
  }

  Widget _buildSendOTPButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [_primaryColor, _cyanColor]),
        boxShadow: [BoxShadow(color: _cyanColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSendOTP,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text('รับรหัส OTP', style: GoogleFonts.kanit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildBackToLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('จำรหัสผ่านได้แล้ว? ', style: GoogleFonts.kanit(color: _hintColor)),
        GestureDetector(
          onTap: () => Get.back(),
          child: Text(
            'เข้าสู่ระบบ',
            style: GoogleFonts.kanit(color: _cyanColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}