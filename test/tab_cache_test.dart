import 'package:flutter_test/flutter_test.dart';
import 'package:rampart/services/tab_cache.dart';
import 'package:rampart/services/tab_refresh_bus.dart';

void main() {
  setUp(() => TabCache.instance.clear());
  tearDown(() => TabCache.instance.clear());

  group('อายุของ cache', () {
    test('คืนของเดิมภายใน 4 วินาที', () {
      TabCache.instance.store('dashboard', 'ของเดิม');

      expect(TabCache.instance.fresh<String>('dashboard'), 'ของเดิม');
    });

    test('หมดอายุเมื่อครบ 4 วินาที', () {
      final savedAt = DateTime.now();
      TabCache.instance.store('dashboard', 'ของเดิม', now: savedAt);

      DateTime after(Duration offset) => savedAt.add(offset);

      expect(
        TabCache.instance.fresh<String>(
          'dashboard',
          now: after(TabCache.ttl - const Duration(milliseconds: 1)),
        ),
        'ของเดิม',
      );
      expect(
        TabCache.instance.fresh<String>('dashboard', now: after(TabCache.ttl)),
        isNull,
      );
      expect(
        TabCache.instance.fresh<String>(
          'dashboard',
          now: after(const Duration(minutes: 5)),
        ),
        isNull,
      );
    });

    test('คืน null เมื่อไม่เคยเก็บ key นั้น', () {
      expect(TabCache.instance.fresh<String>('ไม่เคยมี'), isNull);
    });

    test('type ไม่ตรงถือว่าใช้ไม่ได้', () {
      TabCache.instance.store('dashboard', 'สตริง');
      expect(TabCache.instance.fresh<int>('dashboard'), isNull);
    });

    test('key ต่างกันไม่ปนกัน', () {
      TabCache.instance.store('a', 1);
      TabCache.instance.store('b', 2);

      expect(TabCache.instance.fresh<int>('a'), 1);
      expect(TabCache.instance.fresh<int>('b'), 2);
    });
  });

  group('เวลาที่ซิงก์ล่าสุด', () {
    test('อัปเดตทุกครั้งที่เก็บของใหม่', () {
      expect(TabCache.instance.lastSyncedAt.value, isNull);

      TabCache.instance.store('a', 1);
      final first = TabCache.instance.lastSyncedAt.value;
      expect(first, isNotNull);

      TabCache.instance.store('b', 2);
      expect(
        TabCache.instance.lastSyncedAt.value!.isBefore(first!),
        isFalse,
      );
    });

    test('clear ล้างทั้งของและเวลา', () {
      TabCache.instance.store('a', 1);
      TabCache.instance.clear();

      expect(TabCache.instance.fresh<int>('a'), isNull);
      expect(TabCache.instance.lastSyncedAt.value, isNull);
    });

    test('noteSync เลื่อนเวลาไปข้างหน้าแต่ไม่ย้อนกลับ', () {
      final older = DateTime.now().subtract(const Duration(minutes: 10));
      final newer = DateTime.now();

      TabCache.instance.noteSync(newer);
      TabCache.instance.noteSync(older);
      expect(TabCache.instance.lastSyncedAt.value, newer);

      final newest = newer.add(const Duration(minutes: 1));
      TabCache.instance.noteSync(newest);
      expect(TabCache.instance.lastSyncedAt.value, newest);
    });
  });

  group('TabRefreshBus', () {
    test('แจ้งทุกครั้งที่กดแท็บ แม้เป็นแท็บเดิม', () {
      var notifications = 0;
      void listener() => notifications++;
      TabRefreshBus.addListener(listener);
      addTearDown(() => TabRefreshBus.removeListener(listener));

      TabRefreshBus.select(TabRefreshBus.reportsTab);
      TabRefreshBus.select(TabRefreshBus.reportsTab);

      expect(notifications, 2);
      expect(TabRefreshBus.currentIndex, TabRefreshBus.reportsTab);
    });
  });
}
