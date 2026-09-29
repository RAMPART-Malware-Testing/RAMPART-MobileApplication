import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rampart/services/fcm_service.dart';
import 'package:rampart/widgets/analysis_components.dart';

class _HarnessPage extends StatelessWidget {
  const _HarnessPage({required this.buttonKey, required this.onPressed});

  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: buttonKey,
          onPressed: onPressed,
          child: const Text('tap'),
        ),
      ),
    );
  }
}

Widget _harness() {
  return GetMaterialApp(
    getPages: [
      GetPage(
        name: '/start',
        page: () => _HarnessPage(
          buttonKey: const Key('open-second'),
          onPressed: () => Get.toNamed('/second'),
        ),
      ),
      GetPage(
        name: '/second',
        page: () => _HarnessPage(
          buttonKey: const Key('back'),
          onPressed: popAnalysisScreen,
        ),
      ),
      GetPage(
        name: '/home',
        page: () => _HarnessPage(
          buttonKey: const Key('home'),
          onPressed: () {},
        ),
      ),
    ],
    initialRoute: '/start',
  );
}

void main() {
  group('shouldSkipTaskPushNavigation', () {
    test('skips pushing the result when its progress screen is already open', () {
      expect(
        shouldSkipTaskPushNavigation(
          currentRoute: '/analysis-progress',
          currentArguments: 'task-1',
          taskId: 'task-1',
        ),
        isTrue,
      );
    });

    test('skips reopening progress over an open result of the same task', () {
      expect(
        shouldSkipTaskPushNavigation(
          currentRoute: '/analysis-result',
          currentArguments: 'task-1',
          taskId: 'task-1',
        ),
        isTrue,
      );
    });

    test('does not skip a different task', () {
      expect(
        shouldSkipTaskPushNavigation(
          currentRoute: '/analysis-result',
          currentArguments: 'task-1',
          taskId: 'task-2',
        ),
        isFalse,
      );
    });

    test('does not skip when another screen is on top', () {
      expect(
        shouldSkipTaskPushNavigation(
          currentRoute: '/home',
          currentArguments: null,
          taskId: 'task-1',
        ),
        isFalse,
      );
    });

    test('does not skip when the open screen has no task argument', () {
      expect(
        shouldSkipTaskPushNavigation(
          currentRoute: '/analysis-result',
          currentArguments: null,
          taskId: 'task-1',
        ),
        isFalse,
      );
    });
  });

  group('popAnalysisScreen', () {
    testWidgets('pops to the previous route like a normal back button', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.tap(find.byKey(const Key('open-second')));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, '/second');

      await tester.tap(find.byKey(const Key('back')));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, '/start');
    });

    testWidgets('never strands the user: falls back to /home when the stack '
        'has nothing to pop', (tester) async {
      // /second เป็น root ของสแตก — กดย้อนต้องไม่เงียบ ต้องพาไป /home
      await tester.pumpWidget(
        GetMaterialApp(
          getPages: [
            GetPage(
              name: '/second',
              page: () => _HarnessPage(
                buttonKey: const Key('back'),
                onPressed: popAnalysisScreen,
              ),
            ),
            GetPage(
              name: '/home',
              page: () => _HarnessPage(
                buttonKey: const Key('home'),
                onPressed: () {},
              ),
            ),
          ],
          initialRoute: '/second',
        ),
      );
      expect(Get.currentRoute, '/second');

      await tester.tap(find.byKey(const Key('back')));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, '/home');
    });
  });
}
