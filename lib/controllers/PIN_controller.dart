import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rampart/services/authService.dart';
import 'package:rampart/services/pin_service.dart';

class PINController extends GetxController {
  final _storage = const FlutterSecureStorage();
  
  var pin = ''.obs;
  var wrongCount = 0.obs;
  var isLoading = false.obs;
  var isConfirmStage = false.obs;
  
  final int maxAttempts = 5;
  String _firstPin = '';

  void _showNotice(String message, {bool isError = false}) {
    if (Get.context != null) {
      ScaffoldMessenger.of(Get.context!).clearSnackBars();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Kanit', )),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void addDigit(int digit, {required bool isSetupMode}) {
    if (pin.value.length < 6 && !isLoading.value) {
      pin.value += digit.toString();
      if (pin.value.length == 6) {
        if (isSetupMode) {
          _handlePinSetup();
        } else {
          _verifyPin();
        }
      }
    }
  }

  void deleteDigit() {
    if (pin.value.isNotEmpty && !isLoading.value) {
      pin.value = pin.value.substring(0, pin.value.length - 1);
    }
  }

  void _handlePinSetup() async {
    if (!isConfirmStage.value) {
      _firstPin = pin.value;
      pin.value = '';
      isConfirmStage.value = true;
      _showNotice('กรุณากรอกรหัส PIN อีกครั้งเพื่อยืนยัน');
    } else {
      if (pin.value == _firstPin) {
        await _storage.write(key: 'user_pin', value: pin.value);
        await authService.markAuthenticated();
        _showNotice('ตั้งค่ารหัส PIN เรียบร้อยแล้ว');
        _resetSetupState();
        Get.offAllNamed('/home');
      } else {
        pin.value = '';
        _firstPin = '';
        isConfirmStage.value = false;
        _showNotice('รหัสยืนยันไม่ตรงกับครั้งแรก กรุณาตั้งค่าใหม่อีกครั้ง', isError: true);
      }
    }
  }

  void _resetSetupState() {
    pin.value = '';
    _firstPin = '';
    isConfirmStage.value = false;
  }

  Future<void> _verifyPin() async {
    isLoading.value = true;
    // อ่าน PIN กับตัวนับพร้อมกันในรอบเดียว (ลดการเข้าถึง Keystore)
    final stored = await Future.wait([
      _storage.read(key: 'user_pin'),
      _storage.read(key: 'pin_wrong_count'),
    ]);
    String? savedPin = stored[0];
    // ใช้ค่าที่เก็บไว้จริงเป็นหลัก กันตัวนับรีเซ็ตเมื่อปิดแอปแล้วเปิดใหม่
    final persistedWrong = int.tryParse(stored[1] ?? '');

    if (savedPin == null) {
      savedPin = '123456'; 
      await _storage.write(key: 'user_pin', value: '123456');
    }

    if (pin.value == savedPin) {
      // PIN ถูกต้อง: ปลดล็อกทันทีโดยไม่รอเครือข่าย
      // เดิมบังคับให้ refresh token สำเร็จก่อน ถ้าเน็ตล่มจะถูกล้างเซสชันและต้อง login ใหม่
      wrongCount.value = 0;
      await _storage.write(key: 'pin_wrong_count', value: '0');
      isLoading.value = false;
      Get.find<PINService>().unlock();
      pin.value = '';
      Get.offAllNamed('/home');
      _refreshSessionInBackground();
    } else {
      isLoading.value = false;
      pin.value = ''; 
      wrongCount.value = (persistedWrong ?? wrongCount.value) + 1;
      await _storage.write(
        key: 'pin_wrong_count',
        value: wrongCount.value.toString(),
      );

      if (wrongCount.value >= maxAttempts) {
        _showNotice('กรอกรหัสผิดเกินกำหนด ระบบทำการล็อกเอาต์อัตโนมัติ', isError: true);
        await authService.clearAuthData();
        wrongCount.value = 0;
        Get.offAllNamed('/login');
      } else {
        _showNotice('PIN ไม่ถูกต้อง (ระบุผิดไปแล้ว ${wrongCount.value}/$maxAttempts ครั้ง)', isError: true);
      }
    }
  }

  /// ต่ออายุ token เบื้องหลังหลังปลดล็อกแล้ว
  /// - 401/403 = เซสชันตายจริง -> ล้างข้อมูลและกลับไปหน้า login
  /// - 0 = คำขอไปไม่ถึงเซิร์ฟเวอร์ (เน็ต/timeout) -> คงเซสชันไว้ ไม่บังคับ login ใหม่
  Future<void> _refreshSessionInBackground() async {
    final res = await authService.refreshAccessToken();
    if (res['success'] == true) return;

    final status = res['status'];
    if (status == 401 || status == 403) {
      _showNotice('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่อีกครั้ง', isError: true);
      await authService.clearAuthData();
      Get.offAllNamed('/login');
    }
  }
}