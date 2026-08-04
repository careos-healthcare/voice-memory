import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/cold_start/cold_start_engine.dart';
import 'package:voicememory_mobile/features/cold_start/cold_start_seed_survey.dart';
import 'package:voicememory_mobile/features/cold_start/guided_spark_prompts.dart';
import 'package:voicememory_mobile/features/memory_graph/memory_graph_canvas.dart';

Future<void> _saveOptionalContext(WidgetTester tester) async {
  final save = find.byKey(const Key('cold_start_seed_continue'));
  await tester.scrollUntilVisible(
    save,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(
    tester.element(save),
    alignment: 0.5,
    duration: const Duration(milliseconds: 1),
  );
  await tester.pumpAndSettle();
  await tester.tap(save);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('optional context accepts two people and complete fields', (
    tester,
  ) async {
    ColdStartSeedData? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: ColdStartSeedSurvey(
          persistData: (_) async {},
          onComplete: (value) => completed = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('cold_start_people_input')),
      'Maya, Jordan',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('cold_start_focus_health')),
    );
    await tester.tap(find.byKey(const Key('cold_start_focus_health')));
    await tester.ensureVisible(find.byKey(const Key('cold_start_goal_input')));
    await tester.enterText(
      find.byKey(const Key('cold_start_goal_input')),
      'Protect time for recovery',
    );
    await tester.pump();
    await _saveOptionalContext(tester);

    expect(completed?.people, ['Maya', 'Jordan']);
    expect(completed?.focus, ColdStartFocus.health);
    expect(completed?.goalOrChallenge, 'Protect time for recovery');
  });

  testWidgets(
    'optional context accepts zero people and blank optional fields',
    (tester) async {
      ColdStartSeedData? completed;
      await tester.pumpWidget(
        MaterialApp(
          home: ColdStartSeedSurvey(
            persistData: (_) async {},
            onComplete: (value) => completed = value,
          ),
        ),
      );

      await _saveOptionalContext(tester);

      expect(completed?.people, isEmpty);
      expect(completed?.focus, isNull);
      expect(completed?.goalOrChallenge, isEmpty);
    },
  );

  testWidgets('optional context accepts one person', (tester) async {
    ColdStartSeedData? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: ColdStartSeedSurvey(
          persistData: (_) async {},
          onComplete: (value) => completed = value,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('cold_start_people_input')),
      'Maya',
    );
    await _saveOptionalContext(tester);

    expect(completed?.people, ['Maya']);
    expect(completed?.focus, isNull);
    expect(completed?.goalOrChallenge, isEmpty);
  });

  testWidgets('optional context exposes a non-blocking skip action', (
    tester,
  ) async {
    var skipped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ColdStartSeedSurvey(
          persistData: (_) async {},
          onSkip: () => skipped = true,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('cold_start_people_input')),
      'Maya',
    );
    await tester.tap(find.byKey(const Key('cold_start_seed_skip')));
    await tester.pump();

    expect(skipped, isTrue);
  });

  testWidgets('Not now pops back to the calling screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open_optional_context'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ColdStartSeedSurvey(persistData: (_) async {}),
                ),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_optional_context')));
    await tester.pumpAndSettle();
    expect(find.text('Add personal context'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cold_start_seed_skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open_optional_context')), findsOneWidget);
    expect(find.text('Add personal context'), findsNothing);
  });

  test('partial and empty stored context remain valid', () {
    final empty = ColdStartSeedData.fromJson(const <String, Object?>{});
    expect(empty, isNotNull);
    expect(empty!.people, isEmpty);
    expect(empty.focus, isNull);
    expect(empty.goalOrChallenge, isEmpty);
    expect(empty.hasContext, isFalse);
    expect(empty.toJson(), isEmpty);

    final partial = ColdStartSeedData.fromJson({
      'people': ['Maya'],
      'focus': null,
      'goalOrChallenge': '',
    });
    expect(partial?.people, ['Maya']);
    expect(partial?.focus, isNull);
    expect(partial?.goalOrChallenge, isEmpty);
    expect(partial?.hasContext, isTrue);
  });

  for (final configuration in <({Size size, double textScale})>[
    (size: const Size(320, 568), textScale: 1),
    (size: const Size(390, 844), textScale: 1),
    (size: const Size(390, 844), textScale: 2),
  ]) {
    testWidgets(
      'optional context fits ${configuration.size} at ${configuration.textScale}x text',
      (tester) async {
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue =
            configuration.textScale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          MaterialApp(
            home: ColdStartSeedSurvey(persistData: (_) async {}, onSkip: () {}),
          ),
        );
        await tester.pump();

        expect(find.text('Not now'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('SparkCard dispatches its selected prompt', (tester) async {
    final spark = GuidedSparkPrompts.forEntryCount(0)!;
    GuidedSparkPrompt? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SparkCard(
            spark: spark,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('guided_spark_card_day_1')));
    expect(selected?.prompt, spark.prompt);
  });

  testWidgets('first-entry graph burst shows the magic-moment banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: const InstantGraphBurst())),
    );

    expect(find.byKey(const Key('instant_graph_burst_banner')), findsOneWidget);
    expect(find.textContaining('Your Memory Graph is alive'), findsOneWidget);
  });
}
