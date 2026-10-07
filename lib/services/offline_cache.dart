import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class OfflineCache {
  OfflineCache._();

  static final OfflineCache instance = OfflineCache._();

  static const int maxPayloadBytes = 2 * 1024 * 1024;

  static const String _folder = 'rampart_cache';

  Directory? _root;
  Future<Directory>? _pendingRoot;

  Future<Directory> _dir() async {
    final cached = _root;
    if (cached != null) return cached;
    return _pendingRoot ??= _createRoot();
  }

  Future<Directory> _createRoot() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}$_folder');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _root = dir;
      return dir;
    } catch (e) {
      _pendingRoot = null;
      debugPrint('[cache] เตรียมโฟลเดอร์ cache ไม่ได้: $e');
      rethrow;
    }
  }

  String _fileName(String scope, String key) {
    final raw = '$scope/$key';
    final digest = sha256.convert(utf8.encode(raw)).toString().substring(0, 24);
    final readable = key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final short = readable.length > 48 ? readable.substring(0, 48) : readable;
    return '$short-$digest.json';
  }

  File _file(Directory dir, String scope, String key) {
    final safeScope = scope.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${dir.path}${Platform.pathSeparator}$safeScope${Platform.pathSeparator}${_fileName(scope, key)}');
  }

  Future<void> put(String scope, String key, Object? payload) async {
    if (scope.isEmpty) return;
    try {
      final encoded = jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': payload,
      });
      if (encoded.length > maxPayloadBytes) {
        debugPrint('[cache] ข้าม $key เพราะใหญ่เกิน $maxPayloadBytes bytes');
        return;
      }

      final file = _file(await _dir(), scope, key);
      await file.parent.create(recursive: true);
      await file.writeAsString(encoded, flush: true);
    } catch (e) {
      debugPrint('[cache] เขียน $key ไม่สำเร็จ: $e');
    }
  }

  Future<CachedEntry?> get(String scope, String key) async {
    if (scope.isEmpty) return null;
    try {
      final file = _file(await _dir(), scope, key);
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final savedAt = DateTime.tryParse('${decoded['savedAt']}');
      if (savedAt == null) return null;
      return CachedEntry(savedAt.toLocal(), decoded['payload']);
    } catch (e) {
      debugPrint('[cache] อ่าน $key ไม่สำเร็จ: $e');
      return null;
    }
  }

  Future<void> remove(String scope, String key) async {
    try {
      final file = _file(await _dir(), scope, key);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[cache] ลบ $key ไม่สำเร็จ: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      _root = null;
      _pendingRoot = null;
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}$_folder');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[cache] ล้าง cache ไม่สำเร็จ: $e');
    }
  }

  static String normaliseKey(List<Object?> parts) =>
      parts.map((p) => '$p').join('|');

  static String scopeFor(String? token) {
    if (token == null || token.isEmpty) return 'anon';
    return sha256
        .convert(utf8.encode(_subjectOf(token) ?? token))
        .toString()
        .substring(0, 16);
  }

  static String? _subjectOf(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (decoded is! Map) return null;
      final sub = decoded['sub'];
      if (sub is String && sub.isNotEmpty) return sub;
      return null;
    } catch (_) {
      return null;
    }
  }
}

class CachedEntry {
  final DateTime savedAt;
  final Object? payload;

  const CachedEntry(this.savedAt, this.payload);
}
