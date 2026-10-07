import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:rampart/core/config.dart';

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

  final isOnline = true.obs;

  void Function()? onReconnect;

  Timer? _timer;
  bool _watching = false;
  bool _probing = false;
  bool _paused = false;

  Future<bool> probe() async {
    if (_probing) return isOnline.value;
    _probing = true;
    try {
      await _http.head<void>('/');
      _setOnline(true);
      return true;
    } on DioException catch (e) {
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

  static bool isUnreachable(Object error) {
    if (error is! DioException || error.response != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionError || DioExceptionType.connectionTimeout =>
        true,
      _ => false,
    };
  }

  void reportUnreachable() {
    if (_paused) return;
    _setOnline(false);
  }

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

  void pause() {
    if (_paused) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

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
