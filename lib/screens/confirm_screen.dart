import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/services/authService.dart';
import '../theme/app_theme.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key});

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen>
    with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  int _activeOTPIndex = 0;
  String? _verificationType;

  Color get _cardColor => Theme.of(context).cardColor;
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _cyanColor =>
      Theme.of(context).extension<CustomColors>()?.cyanColor ?? Colors.cyan;
  Color get _hintColor =>
      Theme.of(context).extension<CustomColors>()?.hintColor ?? Colors.grey;

  @override
  void initState() {
    super.initState();
    _verificationType = Get.arguments?['type'];
    _otpFocusNode.addListener(_handleOTPFocusChanged);
  }

  @override
  void dispose() {
    _otpFocusNode.removeListener(_handleOTPFocusChanged);
    _otpController.dispose();
    _otpFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
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
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _validatePassword(String password) {
    if (password.length < 6) return false;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );
    return hasUppercase && hasLowercase && hasSpecialCharacters;
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text;

    if (otp.length != 6) {
      _showSnackBar('กรุณากรอก OTP ให้ครบ 6 หลัก', Colors.orangeAccent);
      return;
    }

    if (_verificationType == 'forgot-passwd' &&
        !_validatePassword(_passwordController.text)) {
      _showSnackBar(
        'รหัสผ่านต้องมี 6 ตัวขึ้นไป, มีอักษรพิมพ์เล็ก-ใหญ่ และอักษรพิเศษ',
        Colors.redAccent,
      );
      return;
    }

    setState(() => _isLoading = true);

    final token = await _storage.read(key: 'session_token') ?? '';
    Map<String, dynamic> res;

    try {
      if (_verificationType == 'login') {
        res = await authService.loginConfirm(token: token, otp: otp);
      } else if (_verificationType == 'register') {
        res = await authService.registerConfirm(token: token, otp: otp);
      } else if (_verificationType == 'forgot-passwd') {
        res = await authService.resetPasswordConfirm(
          token: token,
          otp: otp,
          newPasswd: _passwordController.text,
        );
      } else {
        res = {"success": false, "message": "Unknown Type"};
      }

      if (res['success'] == true) {
        _navigateBasedOnType();
      } else {
        _showSnackBar(
          res['message'] ?? 'เกิดข้อผิดพลาด',
          Colors.red,
          icon: Icons.error_outline,
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateBasedOnType() {
    if (_verificationType == 'login') {
      _showSnackBar(
        'เข้าสู่ระบบสำเร็จ',
        Colors.green,
        icon: Icons.check_circle,
      );
      Get.offAllNamed('/pin-setup');
    } else if (_verificationType == 'register') {
      _showSnackBar(
        'ยืนยันตัวตนสำเร็จ กรุณาเข้าสู่ระบบ',
        Colors.green,
        icon: Icons.check_circle,
      );
      Get.offAllNamed('/login');
    } else if (_verificationType == 'forgot-passwd') {
      _showSnackBar(
        'เปลี่ยนรหัสผ่านสำเร็จ',
        Colors.green,
        icon: Icons.lock_reset,
      );
      Get.offAllNamed('/login');
    }
  }

  void _handleOTPFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onOTPChanged(String value) {
    final current = _otpController.text;
    final caret = _otpController.selection.baseOffset.clamp(0, current.length);
    _activeOTPIndex = current.isEmpty ? 0 : caret.clamp(0, 5);

    if (current.length == 6) {
      _otpFocusNode.unfocus();
    } else {
      _otpFocusNode.requestFocus();
      _otpController.selection = TextSelection.collapsed(
        offset: _activeOTPIndex,
      );
    }
    setState(() {});
  }

  void _selectOTPIndex(int index) {
    final value = _otpController.text;
    _activeOTPIndex = index.clamp(0, 5);
    _otpFocusNode.requestFocus();

    if (index < value.length) {
      _otpController.selection = TextSelection(
        baseOffset: index,
        extentOffset: index + 1,
      );
    } else {
      _otpController.selection = TextSelection.collapsed(offset: value.length);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                children: [
                  Icon(Icons.shield_outlined, size: 80, color: _cyanColor),
                  const SizedBox(height: 24),
                  Text(
                    _verificationType == 'forgot-passwd'
                        ? 'ตั้งรหัสผ่านใหม่'
                        : 'ยืนยันรหัส OTP',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildMainCard(),
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

  Widget _buildMainCard() {
    final otp = _otpController.text;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOTPBox(index, otp)),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    showCursor: false,
                    cursorWidth: 0,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: _onOTPChanged,
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 1,
                      height: 1,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_verificationType == 'forgot-passwd') ...[
            const SizedBox(height: 24),
            _buildPasswordField(),
          ],
          const SizedBox(height: 32),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildOTPBox(int index, String otp) {
    final digit = index < otp.length ? otp[index] : '';
    final isActive = _otpFocusNode.hasFocus && index == _activeOTPIndex;

    return Semantics(
      label: 'ช่อง OTP หลักที่ ${index + 1}',
      value: digit.isEmpty ? 'ว่าง' : digit,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectOTPIndex(index),
        child: Container(
          width: 42,
          height: 55,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? _cyanColor : Colors.white12,
              width: 2,
            ),
          ),
          child: Text(
            digit,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: TextStyle(fontFamily: 'Kanit', color: Colors.white),
      decoration: InputDecoration(
        hintText: 'รหัสผ่านใหม่',
        hintStyle: TextStyle(fontFamily: 'Kanit', color: _hintColor),
        prefixIcon: Icon(Icons.lock_outline, color: _cyanColor),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: _hintColor,
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _cyanColor),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleVerify,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'ยืนยันข้อมูล',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton.icon(
      onPressed: () => Get.offAllNamed('/login'),
      icon: Icon(Icons.arrow_back, size: 18, color: _cyanColor),
      label: Text(
        'ย้อนกลับหน้าหลัก',
        style: TextStyle(fontFamily: 'Kanit', color: _cyanColor),
      ),
    );
  }
}
