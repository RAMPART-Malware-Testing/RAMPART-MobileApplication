import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:rampart/services/offline_cache.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rampart_cache_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    // OfflineCache เป็น singleton ที่จำโฟลเดอร์ไว้ตลอดชีวิตของโปรเซส
    // clearAll คือทางเดียวที่ทำให้มันลืม path เดิมแล้วหยิบ path ของ tmp ใหม่
    await OfflineCache.instance.clearAll();
  });

  tearDown(() async {
    await OfflineCache.instance.clearAll();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('put/get', () {
    test('คืนค่าเดิมทุกชนิดข้อมูลหลังผ่าน JSON', () async {
      final payload = {
        'success': true,
        'status': 200,
        'data': [
          {'id': 'abc', 'score': 87.5, 'flag': true, 'note': null},
        ],
      };

      await OfflineCache.instance.put('scopeA', 'dashboard.summary', payload);
      final cached = await OfflineCache.instance.get('scopeA', 'dashboard.summary');

      expect(cached, isNotNull);
      expect(cached!.payload, isA<Map>());
      final map = Map<String, dynamic>.from(cached.payload as Map);
      expect(map['success'], isTrue);
      expect(map['status'], 200);

      final rows = List<Map<String, dynamic>>.from(map['data'] as List);
      expect(rows.single['id'], 'abc');
      expect(rows.single['score'], 87.5);
      expect(rows.single['flag'], isTrue);
      expect(rows.single['note'], isNull);
    });

    test('คืน null เมื่อยังไม่เคยบันทึก key นั้น', () async {
      expect(await OfflineCache.instance.get('scopeA', 'ไม่เคยเขียน'), isNull);
    });

    test('เขียนทับของเดิมได้', () async {
      await OfflineCache.instance.put('scopeA', 'k', {'v': 1});
      await OfflineCache.instance.put('scopeA', 'k', {'v': 2});

      final cached = await OfflineCache.instance.get('scopeA', 'k');
      expect((cached!.payload as Map)['v'], 2);
    });

    test('บันทึกเวลาที่เขียนไว้', () async {
      final before = DateTime.now();
      await OfflineCache.instance.put('scopeA', 'k', {'v': 1});
      final cached = await OfflineCache.instance.get('scopeA', 'k');

      expect(cached!.savedAt.isBefore(before.subtract(const Duration(minutes: 1))), isFalse);
      expect(cached.savedAt.isAfter(DateTime.now().add(const Duration(minutes: 1))), isFalse);
    });
  });

  group('แยกผู้ใช้', () {
    test('คนละ scope มองไม่เห็นของกัน', () async {
      await OfflineCache.instance.put('userA', 'history', {'items': ['ของA']});

      expect(await OfflineCache.instance.get('userB', 'history'), isNull);
      expect(await OfflineCache.instance.get('userA', 'history'), isNotNull);
    });

    test('scopeFor ผลิตค่าคนละตัวต่อคนละ token และคงที่กับ token เดิม', () {
      final a1 = OfflineCache.scopeFor('token-1');
      final a2 = OfflineCache.scopeFor('token-1');
      final b = OfflineCache.scopeFor('token-2');

      expect(a1, a2);
      expect(a1, isNot(b));
    });

    test('scopeFor ไม่เก็บ token จริงไว้ในชื่อ', () {
      expect(OfflineCache.scopeFor('secret-token-value'), isNot(contains('secret')));
    });

    test('token ที่ถูกต่ออายุของผู้ใช้คนเดิมได้ scope เดิม', () {
      // JWT จริงมี sub = รหัสผู้ใช้ และ iat/exp เปลี่ยนทุกครั้งที่ refresh
      String jwt(String sub, int iat) {
        String seg(Map<String, dynamic> claims) => base64Url
            .encode(utf8.encode(jsonEncode(claims)))
            .replaceAll('=', '');
        return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.'
            '${seg({'sub': sub, 'type': 'access', 'iat': iat})}.signature';
      }

      expect(
        OfflineCache.scopeFor(jwt('user-1', 1000)),
        OfflineCache.scopeFor(jwt('user-1', 2000)),
      );
      expect(
        OfflineCache.scopeFor(jwt('user-1', 1000)),
        isNot(OfflineCache.scopeFor(jwt('user-2', 1000))),
      );
    });

    test('token ที่ไม่ใช่ JWT ยังใช้ได้ (ย้อนไป hash ทั้งก้อน)', () {
      expect(OfflineCache.scopeFor('token-1'), OfflineCache.scopeFor('token-1'));
      expect(
        OfflineCache.scopeFor('token-1'),
        isNot(OfflineCache.scopeFor('token-2')),
      );
    });

    test('token ว่างใช้ scope ร่วมกัน', () {
      expect(OfflineCache.scopeFor(null), 'anon');
      expect(OfflineCache.scopeFor(''), 'anon');
    });

    test('scope ว่างไม่เขียนและไม่อ่าน', () async {
      await OfflineCache.instance.put('', 'k', {'v': 1});
      expect(await OfflineCache.instance.get('', 'k'), isNull);
    });
  });

  group('ความทนทาน', () {
    test('ไฟล์เสียต้องคืน null ไม่ใช่ throw', () async {
      await OfflineCache.instance.put('scopeA', 'k', {'v': 1});

      final dir = Directory('${tmp.path}${Platform.pathSeparator}rampart_cache');
      final files = dir.listSync(recursive: true).whereType<File>().toList();
      expect(files, isNotEmpty);
      await files.first.writeAsString('นี่ไม่ใช่ JSON');

      expect(await OfflineCache.instance.get('scopeA', 'k'), isNull);
    });

    test('ข้ามการเขียนเมื่อ payload ใหญ่เกินกำหนด', () async {
      final huge = {'blob': 'x' * (OfflineCache.maxPayloadBytes + 1024)};
      await OfflineCache.instance.put('scopeA', 'huge', huge);

      expect(await OfflineCache.instance.get('scopeA', 'huge'), isNull);
    });

    test('key ที่มีอักขระแปลกปลอมยังใช้ได้', () async {
      await OfflineCache.instance.put('scope/A', 'history?q=1&x=2', {'v': 1});
      expect(await OfflineCache.instance.get('scope/A', 'history?q=1&x=2'), isNotNull);
    });

    test('remove ลบเฉพาะ key ที่ระบุ', () async {
      await OfflineCache.instance.put('scopeA', 'a', {'v': 1});
      await OfflineCache.instance.put('scopeA', 'b', {'v': 2});

      await OfflineCache.instance.remove('scopeA', 'a');

      expect(await OfflineCache.instance.get('scopeA', 'a'), isNull);
      expect(await OfflineCache.instance.get('scopeA', 'b'), isNotNull);
    });
  });

  group('clearAll', () {
    test('ลบของทุก scope', () async {
      await OfflineCache.instance.put('userA', 'k', {'v': 1});
      await OfflineCache.instance.put('userB', 'k', {'v': 2});

      await OfflineCache.instance.clearAll();

      expect(await OfflineCache.instance.get('userA', 'k'), isNull);
      expect(await OfflineCache.instance.get('userB', 'k'), isNull);
    });

    test('เรียกซ้ำโดยไม่มีของอยู่แล้วต้องไม่พัง', () async {
      await OfflineCache.instance.clearAll();
      await OfflineCache.instance.clearAll();
    });
  });

  group('normaliseKey', () {
    test('เรียง parameter เดิมได้ key เดิมเสมอ', () {
      final a = OfflineCache.normaliseKey(['analysis.history', 1, 10, null, null]);
      final b = OfflineCache.normaliseKey(['analysis.history', 1, 10, null, null]);
      expect(a, b);
    });

    test('parameter ต่างกันได้คนละ key', () {
      final a = OfflineCache.normaliseKey(['analysis.history', 1, 10, null]);
      final b = OfflineCache.normaliseKey(['analysis.history', 2, 10, null]);
      expect(a, isNot(b));
    });

    test('null กับค่าว่างไม่ถือว่าเหมือนกัน', () {
      final a = OfflineCache.normaliseKey(['x', null]);
      final b = OfflineCache.normaliseKey(['x', '']);
      expect(a, isNot(b));
    });
  });
}
