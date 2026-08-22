import 'package:archiveme_mobile/features/quick_help/quick_help_model.dart';
import 'package:archiveme_mobile/widgets/quick_help/quick_help_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  Future<void> Function()? onStartRecording,
  Future<void> Function(String)? onUseCheck,
  QuickHelpIntent? initialIntent,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuickHelpSheet(
          onStartRecording: onStartRecording ?? () async {},
          onUseCheck: onUseCheck ?? (_) async {},
          initialIntent: initialIntent,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('opens with five intents and a heading', (tester) async {
    await _pump(tester);

    expect(find.text('Need help now?'), findsOneWidget);
    expect(find.text('I do not know what to record'), findsOneWidget);
    expect(find.text('I need another perspective'), findsOneWidget);
    expect(find.text('I want something practical'), findsOneWidget);
    expect(find.text('I am being hard on myself'), findsOneWidget);
    expect(find.text('I want to know what to check next'), findsOneWidget);
  });

  testWidgets('selecting an intent shows one response', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('I do not know what to record'));
    await tester.pumpAndSettle();

    expect(find.text('Record one moment'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Back to options'), findsOneWidget);
    // The option list is gone now.
    expect(find.text('I want something practical'), findsNothing);
  });

  testWidgets('Start recording action fires', (tester) async {
    var started = false;
    await _pump(
      tester,
      onStartRecording: () async => started = true,
      initialIntent: QuickHelpIntent.whatToRecord,
    );

    await tester.tap(find.text('Start recording'));
    await tester.pumpAndSettle();

    expect(started, isTrue);
  });

  testWidgets('Use this check fires with the next check', (tester) async {
    String? used;
    await _pump(
      tester,
      onUseCheck: (q) async => used = q,
      initialIntent: QuickHelpIntent.practicalNextStep,
    );

    await tester.tap(find.text('Use this check'));
    await tester.pumpAndSettle();

    expect(used, 'What is one moment you can catch earlier?');
  });

  testWidgets('Back to options returns to the intent list', (tester) async {
    await _pump(tester, initialIntent: QuickHelpIntent.kinderAngle);

    expect(find.text('A kinder angle'), findsOneWidget);
    await tester.tap(find.text('Back to options'));
    await tester.pumpAndSettle();

    expect(find.text('I do not know what to record'), findsOneWidget);
  });
}