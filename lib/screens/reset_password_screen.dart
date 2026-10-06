import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../components/recaptcha_sheet.dart';
import '../services/authService.dart';
import '../services/profile_service.dart';
import '../services/recaptcha_service.dart';
import '../theme/app_theme.dart';

/// หน้าตั้งรหัสผ่านใหม่สำหรับผู้ใช้ที่ล็อกอินอยู่ (เข้าจากหน้าโปรไฟล์/ตั้งค่า)
///
/// ใช้ access token ปัจจุบันเป็นหลักฐานยืนยันตัวตน — เซิร์ฟเวอร์เปลี่ยนรหัสให้ทันที
/// จึงไม่ต้องส่ง OTP ทางอีเมลเหมือนเส้นทาง "ลืมรหัสผ่าน" ของคนที่ล็อกอินไม่ได้
/// และไม่ต้องให้ผู้ใช้กรอกรหัสผ่านเดิม (เซิร์ฟเวอร์ไม่มีทางตรวจให้ ถ้าไม่ล็อกอินใหม่)
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.submit = defaultSubmit});

  /// จุดเชื่อมสำหรับเทสต์ — ค่าเริ่มต้นยิงเซิร์ฟเวอร์จริง
  final Future<Map<String, dynamic>> Function(String newPassword) submit;

  static Future<Map<String, dynamic>> defaultSubmit(String newPassword) =>
      authService.changePassword(newPassword);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  bool _isRecaptchaVerified = false;
  String? _serverError;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// เงื่อนไขเดียวกับตอนสมัครสมาชิก (register_screen) เพื่อไม่ให้ตั้งรหัสที่ระบบอื่นไม่รับ
  static bool _hasMinLength(String value) => value.length >= 8;
  static bool _hasLetterCase(String value) =>
      value.contains(RegExp(r'[A-Z]')) && value.contains(RegExp(r'[a-z]'));
  static bool _hasDigit(String value) => value.contains(RegExp(r'[0-9]'));
  static bool _hasSymbol(String value) =>
      value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  static bool _isAcceptable(String value) =>
      _hasMinLength(value) &&
      _hasLetterCase(value) &&
      _hasDigit(value) &&
      _hasSymbol(value);

  /// เปิด WebView ให้ผู้ใช้ยืนยันกับ Google แล้วตรวจ token กับ Google ในเครื่องแอปเอง
  Future<void> _openRecaptcha() async {
    final token = await RecaptchaSheet.show(context);
    if (!mounted || token == null || token.isEmpty) return;

    final ok = await RecaptchaVerifyService.instance.verifyToken(token);
    if (!mounted) return;
    setState(() {
      _isRecaptchaVerified = ok;
      if (!ok) _serverError = 'ยืนยัน reCAPTCHA ไม่สำเร็จ กรุณาลองใหม่';
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    if (!_isRecaptchaVerified) {
      setState(() => _serverError = 'กรุณายืนยันตัวตนด้วย reCAPTCHA ก่อน');
      return;
    }

    setState(() => _saving = true);
    final result = await widget.submit(_newController.text);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'เปลี่ยนรหัสผ่านสำเร็จ ใช้รหัสใหม่ในการเข้าสู่ระบบครั้งถัดไป',
            style: TextStyle(fontFamily: 'Kanit'),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      Get.back();
      return;
    }

    // เซิร์ฟเวอร์บอกว่า token ใช้ไม่ได้แล้ว — ปลดล็อกด้วย PIN ไม่ได้อีก ต้องล็อกอินใหม่
    if (AuthService.isDeadSession(result)) {
      await AuthService().clearAuthData();
      if (!mounted) return;
      Get.offAllNamed('/login');
      return;
    }

    setState(() {
      _serverError = result['message']?.toString() ?? 'เปลี่ยนรหัสผ่านไม่สำเร็จ';
    });
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0f172a),
              bgColor,
              const Color(0xFF1e293b),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(customColors),
                  const SizedBox(height: 24),
                  _buildAccountCard(customColors),
                  const SizedBox(height: 24),
                  _buildNewPasswordField(customColors),
                  const SizedBox(height: 10),
                  _buildRules(customColors),
                  const SizedBox(height: 18),
                  _buildConfirmField(customColors),
                  if (_serverError != null) ...[
                    const SizedBox(height: 16),
                    _buildServerError(),
                  ],
                  const SizedBox(height: 20),
                  _buildRecaptcha(customColors),
                  const SizedBox(height: 20),
                  _buildSaveButton(customColors),
                  const SizedBox(height: 16),
                  _buildFooterNote(customColors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CustomColors customColors) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Get.back(),
          icon: Icon(Icons.arrow_back, color: customColors.cyanColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [customColors.cyanColor, customColors.blueColor],
              ).createShader(bounds);
            },
            child: const Text(
              'เปลี่ยนรหัสผ่าน',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(CustomColors customColors) {
    final email = ProfileService.instance.cached?.email;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_reset, color: customColors.cyanColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email == null || email.isEmpty ? 'บัญชีนี้' : email,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ยืนยันด้วยเซสชันที่ล็อกอินอยู่ ไม่ต้องยืนยัน OTP ทางอีเมล',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 11.5,
                    color: customColors.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPasswordField(CustomColors customColors) {
    return _buildField(
      customColors,
      label: 'รหัสผ่านใหม่',
      controller: _newController,
      obscure: _obscureNew,
      onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
      // ต้องวาดใหม่ทุกครั้งที่พิมพ์ เพื่ออัปเดตเครื่องหมายถูกใน [_buildRules]
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final v = value ?? '';
        if (v.isEmpty) return 'กรุณากรอกรหัสผ่านใหม่';
        if (!_isAcceptable(v)) {
          return 'รหัสผ่านยังไม่ครบเงื่อนไขด้านล่าง';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmField(CustomColors customColors) {
    return _buildField(
      customColors,
      label: 'ยืนยันรหัสผ่านใหม่',
      controller: _confirmController,
      obscure: _obscureConfirm,
      onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
      validator: (value) {
        if (value == null || value.isEmpty) return 'กรุณายืนยันรหัสผ่านใหม่';
        if (value != _newController.text) return 'รหัสผ่านไม่ตรงกัน';
        return null;
      },
    );
  }

  Widget _buildField(
    CustomColors customColors, {
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: customColors.hintColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: const TextStyle(fontFamily: 'Kanit', color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: customColors.cardBackground,
            suffixIcon: IconButton(
              tooltip: obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: customColors.hintColor,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: customColors.cyanColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  /// เช็กลิสต์แบบเห็นสด ๆ ว่าขาดอะไร — ดีกว่าให้ validator ฟ้องทีละข้อ
  Widget _buildRules(CustomColors customColors) {
    final value = _newController.text;
    final rules = <({String label, bool passed})>[
      (label: 'อย่างน้อย 8 ตัวอักษร', passed: _hasMinLength(value)),
      (label: 'มีตัวพิมพ์ใหญ่และตัวพิมพ์เล็ก', passed: _hasLetterCase(value)),
      (label: 'มีตัวเลขอย่างน้อย 1 ตัว', passed: _hasDigit(value)),
      (label: 'มีอักขระพิเศษ เช่น ! @ # \$ %', passed: _hasSymbol(value)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  rule.passed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: rule.passed
                      ? customColors.cyanColor
                      : customColors.hintColor,
                ),
                const SizedBox(width: 7),
                Text(
                  rule.label,
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 11.5,
                    color: rule.passed
                        ? customColors.cyanColor
                        : customColors.hintColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildServerError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _serverError!,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12.5,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecaptcha(CustomColors customColors) {
    return GestureDetector(
      onTap: _openRecaptcha,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isRecaptchaVerified
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRecaptchaVerified
                ? Colors.green
                : customColors.cyanColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isRecaptchaVerified
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: _isRecaptchaVerified ? Colors.green : customColors.hintColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isRecaptchaVerified ? 'ยืนยันตัวตนสำเร็จ' : 'ฉันไม่ใช่บอท',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  color: _isRecaptchaVerified ? Colors.green : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.security, color: customColors.cyanColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(CustomColors customColors) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saving ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: customColors.cyanColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: customColors.cyanColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'บันทึกรหัสผ่านใหม่',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildFooterNote(CustomColors customColors) {
    return Text(
      'PIN ที่ใช้ปลดล็อกแอปยังเป็นค่าเดิม · ถ้าต้องการรีเซ็ตผ่านอีเมล '
      'ให้ออกจากระบบแล้วใช้ "ลืมรหัสผ่าน" ที่หน้าเข้าสู่ระบบ',
      style: TextStyle(
        fontFamily: 'Kanit',
        fontSize: 11.5,
        height: 1.5,
        color: customColors.hintColor,
      ),
    );
  }
}
