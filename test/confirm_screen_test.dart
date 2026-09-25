import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rampart/screens/confirm_screen.dart';

void main() {
  testWidgets('OTP screen uses one input and editable boxes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GetMaterialApp(home: ConfirmScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    final thirdBox = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'ช่อง OTP หลักที่ 3',
    );
    await tester.tap(thirdBox);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '129456',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(find.text('9'), findsOneWidget);

    await tester.tap(thirdBox);
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '12945',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();
    expect(find.text('6'), findsNothing);
  });
}
