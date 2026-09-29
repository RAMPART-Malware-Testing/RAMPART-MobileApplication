import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// เก็บ response ดิบจากเซิร์ฟเวอร์ลงดิสก์ เพื่อให้หน้าจอยังแสดงผลได้ตอนไม่มีเน็ต
///
/// เก็บเป็น JSON ของ payload ที่ยังไม่ผ่านการ parse — ให้ `fromJson` เดิมของแต่ละโมเดล
/// เป็นคนแปลงตอนอ่านกลับ วิธีนี้ไม่ต้องเพิ่ม `toJson` ที่โมเดลใดเลย และตรรกะที่มีอยู่
/// ใน `test/dashboard_contract_test.dart` กับ `test/analysis_helpers_test.dart`
/// ยังครอบคลุมเส้นทางนี้อยู่
///
/// แยกโฟลเดอร์ตามผู้ใช้ (scope) เพื่อไม่ให้ผู้ใช้คนที่สองที่ล็อกอินบนเครื่องเดียวกัน
/// เห็นประวัติหรือรายงานของคนก่อน — เรียก [clearAll] ตอน logout เพื่อลบทิ้งทั้งหมด
class OfflineCache {
  OfflineCache._();

  static final OfflineCache instance = OfflineCache._();

  /// ใหญ่เกินนี้แล้วไม่ควรเขียนลงดิสก์ — ป้องกัน report ขนาดใหญ่ทำให้เครื่องเต็ม
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
      // ปล่อยให้ลองใหม่ได้ครั้งหน้า แทนที่จะค้างเป็น future ที่ล้มเหลวถาวร
      _pendingRoot = null;
      debugPrint('[cache] เตรียมโฟลเดอร์ cache ไม่ได้: $e');
      rethrow;
    }
  }

  /// เอา scope ที่อยู่ในพาธออก เหลือแต่ชื่อไฟล์ที่ปลอดภัยเสมอ
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

  /// เขียน payload ลงดิสก์พร้อมเวลาที่บันทึก
  ///
  /// ไม่โยน error ออกไปเด็ดขัด — การเขียน cache ไม่สำเร็จต้องไม่ทำให้แอปพัง
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

  /// อ่านของที่เคยบันทึกไว้ คืน null เมื่อไม่มีหรืออ่านไม่ได้
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

  /// ลบ cache ทั้งหมด — เรียกตอน logout เพื่อไม่ให้ข้อมูลคนก่อนค้างอยู่
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

  /// ทำให้ชื่อ key เป็นชื่อเดียวกันทุกครั้งไม่ว่าจะเรียง parameter อย่างไร
  static String normaliseKey(List<Object?> parts) =>
      parts.map((p) => '$p').join('|');

  /// แยกผู้ใช้ออกจากกันด้วย hash ของ "ตัวตนผู้ใช้" — ไม่เก็บ token จริงลงชื่อไฟล์
  ///
  /// ใช้ claim `sub` ใน JWT แทนตัว token ทั้งก้อน เพราะ token ถูกต่ออายุ (refresh)
  /// ได้ตลอดระหว่างใช้งาน — ถ้าใช้ตัว token เป็น scope ข้อมูลที่เขียนไว้ก่อน refresh
  /// จะกลายเป็นคนละ scope กับตอนอ่าน ทั้งที่เป็นผู้ใช้คนเดียวกัน แล้ว cache จะพลาด
  /// ทุกครั้งหลัง token หมุน (ซึ่งเกิดทุกครั้งที่ปลดล็อกด้วย PIN)
  static String scopeFor(String? token) {
    if (token == null || token.isEmpty) return 'anon';
    return sha256
        .convert(utf8.encode(_subjectOf(token) ?? token))
        .toString()
        .substring(0, 16);
  }

  /// อ่าน claim `sub` จาก JWT โดยไม่ตรวจลายเซ็น
  ///
  /// ใช้แยกผู้ใช้ในเครื่องเท่านั้น ไม่ได้ใช้ตัดสินสิทธิ์ — ค่าที่อ่านได้ไม่ผ่าน
  /// การตรวจสอบใด ๆ จึงไม่เป็นช่องโหว่ คืน null เมื่ออ่านไม่ได้ (ไม่ใช่ JWT)
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
