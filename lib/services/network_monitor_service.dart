import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:rampart/core/config.dart';

/// ตรวจว่าแอปยังติดต่อเซิร์ฟเวอร์ได้อยู่หรือไม่
///
/// ใช้ยิง HEAD ไปที่ API จริง ([Config.url_server]) แทนการถามสถานะของ network
/// interface เพราะสิ่งที่แอปต้องการคือ "เรียก API ได้หรือเปล่า" ไม่ใช่ "ต่ออินเทอร์เน็ตได้"
/// — เครื่องที่ต่อ Wi-Fi ได้แต่ captive portal ยังเรียก API ไม่ได้
///
/// ตอบสถานะอะไรก็ถือว่าออนไลน์ทั้งนั้น (รวมถึง 404/405/502) เพราะการได้ status
/// ก็แปลว่ามีการเชื่อมต่อถึงปลายทางแล้ว ออฟไลน์เฉพาะตอนต่อไม่ถึงหรือ timeout
///
/// วนตรวจเฉพาะตอนออฟไลน์ — พอขึ้นเน็ตแล้ว [stopWatching] จะฆยุด timer ทิ้ง
/// ตามงบ "idle CPU ~0%" ใน AGENTS.md
class NetworkMonitorService extends GetxService {
  NetworkMonitorService._() {
    _http = Dio(
      BaseOptions(
        baseUrl: Config.url_server,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
      ),
    );
  }

  factory NetworkMonitorService() => _instance;
  static final NetworkMonitorService _instance = NetworkMonitorService._();

  static const Duration pollInterval = Duration(seconds: 10);

  late final Dio _http;

  /// เริ่มต้นเป็น true เพื่อไม่ให้แถบออฟไลน์โผล่ขึ้นมาก่อนที่จะรู้ความจริง
  final isOnline = true.obs;

  /// เรียกเมื่อขึ้นเน็ตครั้งแรกหลังจากออฟไลน์ — ใช้ต่อกับการสตาร์ท Firebase
  void Function()? onReconnect;

  Timer? _timer;
  bool _watching = false;
  bool _probing = false;
  bool _paused = false;

  /// ส่งคำขอจริงหนึ่งครั้ง คืน true เมื่อติดต่อปลายทางได้
  Future<bool> probe() async {
    if (_probing) return isOnline.value;
    _probing = true;
    try {
      await _http.head<void>('/');
      _setOnline(true);
      return true;
    } on DioException catch (e) {
      // มี response = เซิร์ฟเวอร์ตอบกลับ = มีเน็ต (แม้สถานะจะเป็น error)
      final reachable = e.response != null;
      _setOnline(reachable);
      return reachable;
    } catch (e) {
      debugPrint('[network] ตรวจเน็ตผิดพลาด: $e');
      _setOnline(false);
      return false;
    } finally {
      _probing = false;
    }
  }

  void _setOnline(bool value) {
    if (isOnline.value == value) return;
    isOnline.value = value;
    debugPrint('[network] สถานะเน็ตเปลี่ยนเป็น ${value ? 'ออนไลน์' : 'ออฟไลน์'}');
    if (value) {
      stopWatching();
      onReconnect?.call();
    } else {
      startWatching();
    }
  }

  /// คำขอนี้ "ไปไม่ถึงเซิร์ฟเวอร์เลย" ใช่หรือไม่
  ///
  /// timeout ตอนรอคำตอบไม่นับ — เซิร์ฟเวอร์อาจแค่ตอบช้าซึ่งไม่ใช่เน็ตหลุด
  /// และถ้ามี response กลับมาก็แปลว่าต่อถึงปลายทางแล้วไม่ว่าสถานะจะเป็นอะไร
  static bool isUnreachable(Object error) {
    if (error is! DioException || error.response != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionError || DioExceptionType.connectionTimeout =>
        true,
      _ => false,
    };
  }

  /// ให้บริการที่ยิง API ไม่ติดเรียกตัวนี้ เพื่อให้แถบเตือนขึ้นทันทีโดยไม่ต้องรอรอบตรวจ
  /// ถัดไป (ตอนออนไลน์อยู่ timer จะไม่ทำงาน) — จากนั้น startWatching จะพากลับมาออนไลน์เอง
  /// เมื่อเน็ตกลับมา
  void reportUnreachable() {
    // แอปถูกพับอยู่ — ไม่ต้องเริ่ม timer ตามงบ idle CPU ใน AGENTS.md
    if (_paused) return;
    _setOnline(false);
  }

  /// เริ่มวนตรวจทุก [pollInterval] — เรียกครั้งเดียวตอนตรวจครั้งแรก
  Future<void> checkNow() async {
    await probe();
  }

  void startWatching() {
    if (_watching || _paused) return;
    _watching = true;
    _timer = Timer.periodic(pollInterval, (_) => probe());
    debugPrint('[network] เริ่มตรวจเน็ตทุก ${pollInterval.inSeconds} วินาที');
  }

  void stopWatching() {
    if (!_watching) return;
    _watching = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('[network] หยุดตรวจเน็ต');
  }

  /// หยุดวนตอนแอปถูกพับ เพื่อไม่ให้ตื่นมายิงเน็ตทั้งที่ผู้ใช้ไม่ได้อยู่กับแอป (R9)
  void pause() {
    if (_paused) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// กลับมาที่แอป — ตรวจทันทีหนึ่งครั้งแทนการรอรอบถัดไป
  void resume() {
    if (!_paused) return;
    _paused = false;
    if (!isOnline.value) {
      startWatching();
      probe();
    }
  }

  @override
  void onClose() {
    stopWatching();
    super.onClose();
  }
}
