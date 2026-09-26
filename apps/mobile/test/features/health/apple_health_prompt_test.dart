import 'package:archiveme_mobile/features/health/apple_health_prompt.dart';
import 'package:archiveme_mobile/features/health/health_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => HealthFactory.debugRequest = null);

  testWidgets('the system sheet waits until Allow', (tester) async {
    var calls = 0;
    HealthFactory.debugRequest = ({required bool update}) async {
      calls += 1;
      expect(update, isFalse);
      return true;
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmThenRequestAppleHealthRead(context),
            child: const Text('Sync'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sync'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text(appleHealthReadExplanation), findsOneWidget);

    await tester.tap(find.byKey(const Key('apple_health_allow')));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('Not now does not ask HealthKit', (tester) async {
    var calls = 0;
    HealthFactory.debugRequest = ({required bool update}) async {
      calls += 1;
      return true;
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmThenRequestAppleHealthRead(context),
            child: const Text('Sync'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('the write switch asks for an update only after Allow', (
    tester,
  ) async {
    var updates = 0;
    HealthFactory.debugRequest = ({required bool update}) async {
      if (update) updates += 1;
      return true;
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmThenRequestAppleHealthWrite(context),
            child: const Text('Write'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    expect(updates, 0);
    expect(find.text(appleHealthWriteExplanation), findsOneWidget);
    await tester.tap(find.byKey(const Key('apple_health_write_allow')));
    await tester.pumpAndSettle();
    expect(updates, 1);
  });
}
