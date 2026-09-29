import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rampart/screens/reset_password_screen.dart';
import 'package:rampart/theme/app_theme.dart';

/// ตรวจว่าหน้าเปลี่ยนรหัสผ่านกันข้อมูลผิดตั้งแต่ฝั่งแอป
/// และแสดงข้อความจากเซิร์ฟเวอร์เมื่อเปลี่ยนไม่สำเร็จ
void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    Future<Map<String, dynamic>> Function(String) submit,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GetMaterialApp(
        // หน้าจออ่าน CustomColors จาก theme — ต้องมีธีมจริงเหมือนตอนรันแอป
        theme: AppTheme.darkTheme,
        home: ResetPasswordScreen(submit: submit),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String newPassword, String confirm) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), newPassword);
    await tester.enterText(fields.at(1), confirm);
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('บันทึกรหัสผ่านใหม่'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกรหัสผ่านใหม่'));
    await tester.pumpAndSettle();
  }

  testWidgets('รหัสผ่านสั้นเกินไปต้องไม่ยิงเซิร์ฟเวอร์', (tester) async {
    var calls = 0;
    await pumpScreen(tester, (_) async {
      calls++;
      return {'success': true};
    });

    await fill(tester, 'Ab1!', 'Ab1!');
    await tapSave(tester);

    expect(find.text('รหัสผ่านยังไม่ครบเงื่อนไขด้านล่าง'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('รหัสผ่านไม่ตรงกันต้องไม่ยิงเซิร์ฟเวอร์', (tester) async {
    var calls = 0;
    await pumpScreen(tester, (_) async {
      calls++;
      return {'success': true};
    });

    await fill(tester, 'Rampart123!', 'Rampart124!');
    await tapSave(tester);

    expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('รหัสผ่านครบเงื่อนไขแล้วส่งค่าไปตามที่พิมพ์', (tester) async {
    String? sent;
    await pumpScreen(tester, (password) async {
      sent = password;
      return {'success': true, 'status': 'PASSWORD_RESET_SUCCESS'};
    });

    await fill(tester, 'Rampart123!', 'Rampart123!');
    await tapSave(tester);

    expect(sent, 'Rampart123!');
    expect(find.textContaining('เปลี่ยนรหัสผ่านสำเร็จ'), findsOneWidget);
  });

  testWidgets('เซิร์ฟเวอร์ปฏิเสธต้องแสดงข้อความและอยู่หน้าเดิม', (tester) async {
    await pumpScreen(
      tester,
      (_) async => {
        'success': false,
        'status': 'RATE_LIMITED',
        'message': 'ทำรายการบ่อยเกินไป กรุณาลองใหม่ภายหลัง',
      },
    );

    await fill(tester, 'Rampart123!', 'Rampart123!');
    await tapSave(tester);

    expect(find.text('ทำรายการบ่อยเกินไป กรุณาลองใหม่ภายหลัง'), findsOneWidget);
    expect(find.text('บันทึกรหัสผ่านใหม่'), findsOneWidget);
  });

  testWidgets('เช็กลิสต์เงื่อนไขติดทีละข้อตามที่พิมพ์', (tester) async {
    await pumpScreen(tester, (_) async => {'success': true});

    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'Rampart123!');
    await tester.pump();

    // ครบทั้ง 4 ข้อ
    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
  });
}
