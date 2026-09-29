import 'package:flutter/foundation.dart';

/// แคชผลลัพธ์ล่าสุดของแต่ละแท็บไว้ในหน่วยความจำ พร้อมเวลาที่ดึงจากเซิร์ฟเวอร์สำเร็จ
///
/// ทำไมต้องมี: ทุกแท็บถูกสร้างค้างไว้ใน `IndexedStack` (R6) จึงไม่ยิงข้อมูลใหม่เอง
/// เมื่อผู้ใช้สลับแท็บ แต่การยิงใหม่ทุกครั้งที่กดแท็บก็เปลืองโดยใช่เหตุ — [ttl] คือ
/// ช่วงเวลาที่ผลลัพธ์เดิมยังถือว่า "สดพอ" ที่จะใช้ซ้ำได้
///
/// ต่างจาก [OfflineCache] ตรงที่ตัวนี้เก็บ *ของที่แปลงเป็นโมเดลแล้ว* ในหน่วยความจำ
/// และหายไปเมื่อปิดแอป — หน้าที่ของมันคือกันการยิงซ้ำ ไม่ใช่รองรับโหมดออฟไลน์
/// (โหมดออฟไลน์ยังใช้ [OfflineCache] ที่เก็บลงดิสก์ตามเดิม)
class TabCache {
  TabCache._();

  static final TabCache instance = TabCache._();

  /// อายุของ cache ที่ยอมให้ใช้ซ้ำได้เมื่อผู้ใช้กดแท็บ
  static const Duration ttl = Duration(seconds: 4);

  final Map<String, _Entry> _entries = {};

  /// เวลาที่ดึงข้อมูลจากเซิร์ฟเวอร์สำเร็จครั้งล่าสุด — แบนเนอร์ออฟไลน์ใช้บอกผู้ใช้ว่า
  /// ข้อมูลที่กำลังเห็นเก่าแค่ไหน (null = ยังไม่เคยดึงสำเร็จในรอบการใช้งานนี้)
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);

  /// ของที่เคยเก็บไว้ ถ้ายังไม่ครบ [ttl] — คืน null เมื่อต้องยิงใหม่
  ///
  /// [now] มีไว้ให้เทสต์เลื่อนเวลาได้โดยไม่ต้องรอจริง
  T? fresh<T>(String key, {DateTime? now}) {
    final entry = _entries[key];
    if (entry == null) return null;
    if ((now ?? DateTime.now()).difference(entry.savedAt) >= ttl) return null;
    final value = entry.value;
    return value is T ? value : null;
  }

  /// เก็บผลลัพธ์ที่เพิ่งดึงจากเซิร์ฟเวอร์สำเร็จ
  ///
  /// [now] มีไว้ให้เทสต์กำหนดเวลาเองได้
  void store(String key, Object? value, {DateTime? now}) {
    final at = now ?? DateTime.now();
    _entries[key] = _Entry(at, value);
    lastSyncedAt.value = at;
  }

  /// แจ้งเวลาที่ข้อมูลชุดนั้นถูกดึงจากเซิร์ฟเวอร์สำเร็จ — ใช้เมื่อหยิบของเก่าจากดิสก์
  /// ตอนออฟไลน์ เพราะตอนเปิดแอปใหม่จะยังไม่มีอะไรถูก [store] ในรอบนี้เลย
  /// เลื่อนเวลาไปข้างหน้าเท่านั้น ไม่ย้อนกลับ
  void noteSync(DateTime at) {
    final current = lastSyncedAt.value;
    if (current == null || at.isAfter(current)) lastSyncedAt.value = at;
  }

  /// ล้างทั้งหมด — เรียกตอน logout ไม่ให้ข้อมูลของผู้ใช้คนก่อนค้างอยู่
  void clear() {
    _entries.clear();
    lastSyncedAt.value = null;
  }
}

class _Entry {
  const _Entry(this.savedAt, this.value);

  final DateTime savedAt;
  final Object? value;
}
