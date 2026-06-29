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
          content: Text(message, style: const TextStyle(fontFamily: 'Kanit')),
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
    String? savedPin = await _storage.read(key: 'user_pin');

    if (savedPin == null) {
      savedPin = '123456'; 
      await _storage.write(key: 'user_pin', value: '123456');
    }

    if (pin.value == savedPin) {
      wrongCount.value = 0;
      final res = await authService.refreshAccessToken();
      isLoading.value = false;

      if (res['success'] == true) {
        Get.find<PINService>().unlock();
        pin.value = '';
        Get.offAllNamed('/home');
      } else {
        _showNotice('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่อีกครั้ง', isError: true);
        await authService.clearAuthData();
        pin.value = '';
        Get.offAllNamed('/login');
      }
    } else {
      isLoading.value = false;
      pin.value = ''; 
      wrongCount.value++;

      if (wrongCount.value >= maxAttempts) {
        _showNotice('กรอกรหัสผิดเกินกำหนด ระบบทำการล็อกเอาต์อัตโนมัติ', isError: true);
        await authService.clearAuthData();
        Get.offAllNamed('/login');
      } else {
        _showNotice('PIN ไม่ถูกต้อง (ระบุผิดไปแล้ว ${wrongCount.value}/$maxAttempts ครั้ง)', isError: true);
      }
    }
  }
}