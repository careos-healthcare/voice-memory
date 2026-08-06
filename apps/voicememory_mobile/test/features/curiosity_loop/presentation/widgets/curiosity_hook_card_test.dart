import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart'
    as domain;
import 'package:voicememory_mobile/features/curiosity_loop/presentation/widgets/curiosity_hook_card.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/widgets/grounding_breath_spacer.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/cognitive_baseline_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

class _FakeBaselineStore implements CognitiveBaselineStore {
  const _FakeBaselineStore(this.snapshot);

  final CognitiveBaselineSnapshot? snapshot;

  @override
  Future<CognitiveBaselineSnapshot?> loadSnapshot() async => snapshot;

  @override
  Future<bool> saveSnapshot(CognitiveBaselineSnapshot snapshot) async => true;
}

domain.CuriosityHook _domainHook({required String prompt}) {
  return domain.CuriosityHook(
    id: 'hook_1',
    entryId: 'entry_1',
    createdAt: DateTime.utc(2026, 6, 12, 12),
    primaryAnchor: 'work pressure',
    hookType: domain.CuriosityHookType.blocker,
    dynamicPrompt: prompt,
  );
}

void main() {
  group('CuriosityHookCard Adaptive Layout Tests', () {
    testWidgets('renders standard exploratory layout correctly', (
      WidgetTester tester,
    ) async {
      const standardHook = CuriosityHook(
        id: '1',
        prompt:
            'Reflecting back on your notes regarding architecture—what structural changes have occurred?',
        isMemoryRecallCheck: false,
        isLowCognitiveLoad: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuriosityHookCard(hook: standardHook, onSubmit: _noopSubmit),
          ),
        ),
      );

      expect(find.byKey(const Key('curiosity_hook_prompt')), findsOneWidget);
      expect(
        find.byKey(const Key('curiosity_hook_response_input')),
        findsOneWidget,
      );
      expect(find.text('Commit Response Telemetry'), findsOneWidget);
      expect(find.text('Follow the Breath to Unlock Input'), findsNothing);
    });

    testWidgets('renders breath gate when low cognitive load is active', (
      WidgetTester tester,
    ) async {
      const groundingHook = CuriosityHook(
        id: '2',
        prompt:
            "Let's focus on right now. What is one clear thing you finished today?",
        isMemoryRecallCheck: true,
        isLowCognitiveLoad: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuriosityHookCard(hook: groundingHook, onSubmit: _noopSubmit),
          ),
        ),
      );

      expect(find.byKey(const Key('grounding_breath_spacer')), findsOneWidget);
      expect(
        find.byKey(const Key('curiosity_hook_response_input')),
        findsNothing,
      );
      expect(find.text('Follow the Breath to Unlock Input'), findsOneWidget);

      final disabledButton = tester.widget<FilledButton>(
        find.byKey(const Key('curiosity_hook_submit_action')),
      );
      expect(disabledButton.onPressed, isNull);
    });

    testWidgets(
      'enables grounded response interaction after pacing completes',
      (WidgetTester tester) async {
        const groundingHook = CuriosityHook(
          id: '3',
          prompt: 'What is one clear thing you finished today?',
          isMemoryRecallCheck: true,
          isLowCognitiveLoad: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CuriosityHookCard(
                hook: groundingHook,
                onSubmit: _noopSubmit,
                groundingPacingDuration: Duration.zero,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(
          find.byKey(const Key('curiosity_hook_response_input')),
          findsOneWidget,
        );
        expect(find.text('Commit Response Telemetry'), findsOneWidget);

        final gatedOpenButton = tester.widget<FilledButton>(
          find.byKey(const Key('curiosity_hook_submit_action')),
        );
        expect(gatedOpenButton.onPressed, isNotNull);

        await tester.enterText(
          find.byKey(const Key('curiosity_hook_response_input')),
          'I finished the report.',
        );
        await tester.pump();

        final activeButton = tester.widget<FilledButton>(
          find.byKey(const Key('curiosity_hook_submit_action')),
        );
        expect(activeButton.onPressed, isNotNull);
      },
    );

    testWidgets('submits grounded responses with wasGrounded metadata', (
      WidgetTester tester,
    ) async {
      String? submittedResponse;
      var submittedWasGrounded = false;

      const groundingHook = CuriosityHook(
        id: '4',
        prompt: 'What feels most worth noticing right now?',
        isMemoryRecallCheck: true,
        isLowCognitiveLoad: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CuriosityHookCard(
              hook: groundingHook,
              groundingPacingDuration: Duration.zero,
              onSubmit: (response, {required wasGrounded}) {
                submittedResponse = response;
                submittedWasGrounded = wasGrounded;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('curiosity_hook_response_input')),
        'The meeting went better than expected.',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('curiosity_hook_submit_action')));
      await tester.pump();

      expect(submittedResponse, 'The meeting went better than expected.');
      expect(submittedWasGrounded, isTrue);
    });
  });

  group('CuriosityHookCard Interactive State Machine Validation', () {
    testWidgets(
      'Overloaded configuration locks input area and disables submit button elements',
      (tester) async {
        const overloadPresentation = CuriosityHookPresentation(
          id: 'h_1',
          prompt: 'Stress load high verification.',
          isMemoryRecallCheck: false,
          isLowCognitiveLoad: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CuriosityHookCard(
                presentation: overloadPresentation,
                onSubmit: (_, {required wasGrounded}) {},
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsNothing);
        expect(find.byType(GroundingBreathSpacer), findsOneWidget);

        final buttonWidget = tester.widget<FilledButton>(
          find.byType(FilledButton),
        );
        expect(
          buttonWidget.onPressed,
          isNull,
          reason: 'Action button must remain unclickable during active pacing!',
        );
      },
    );

    testWidgets(
      'Completing grounding sequence soft-reveals text areas and enables interactions',
      (tester) async {
        const overloadPresentation = CuriosityHookPresentation(
          id: 'h_2',
          prompt: 'Transition check layout pass.',
          isMemoryRecallCheck: false,
          isLowCognitiveLoad: true,
        );

        var targetSubmitTriggered = false;
        var targetGroundedFlagValue = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CuriosityHookCard(
                presentation: overloadPresentation,
                onSubmit: (text, {required wasGrounded}) {
                  targetSubmitTriggered = true;
                  targetGroundedFlagValue = wasGrounded;
                },
              ),
            ),
          ),
        );

        final spacerWidget = tester.widget<GroundingBreathSpacer>(
          find.byType(GroundingBreathSpacer),
        );
        spacerWidget.onPacingComplete();
        await tester.pumpAndSettle();

        expect(find.byType(GroundingBreathSpacer), findsNothing);
        expect(find.byType(TextField), findsOneWidget);

        await tester.enterText(
          find.byType(TextField),
          'Calm structured recovery.',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pump();

        expect(targetSubmitTriggered, isTrue);
        expect(
          targetGroundedFlagValue,
          isTrue,
          reason:
              'Telemetry records failed to append the structural wasGrounded value context property!',
        );
      },
    );
  });

  group('ConnectedCuriosityHookCard', () {
    testWidgets(
      'loads baseline metrics and renders grounded layout on overload',
      (tester) async {
        final sourceEntry = JournalEntry(
          id: 'entry_1',
          createdAt: DateTime.utc(2026, 6, 12, 12),
          transcript: 'Work pressure showed up again today.',
          durationSeconds: 20,
          reflection: const Reflection(
            mood: 'thoughtful',
            emotionalIntensity: 2,
            recurringThemes: ['work'],
            exactLanguagePattern: '',
            concreteObservation: 'Work pressure showed up again today.',
            repeatedSignal: '',
          ),
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.42,
            cohesionDrift: 0.36,
            emotionalVolatility: 0.41,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ConnectedCuriosityHookCard.fromDomain(
                hook: _domainHook(
                  prompt: 'What feels most worth noticing right now?',
                ),
                sourceEntry: sourceEntry,
                baselineStore: _FakeBaselineStore(
                  CognitiveBaselineSnapshot(
                    baseline: const CognitiveBiomarkers(
                      lexicalDiversity: 0.55,
                      cohesionDrift: 0.35,
                      emotionalVolatility: 0.40,
                    ),
                    lastEntryId: 'entry_1',
                    updatedAt: DateTime.utc(2026, 6, 12, 12),
                    observationCount: 3,
                  ),
                ),
                onSubmit: _noopSubmit,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.text('Follow the Breath to Unlock Input'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('curiosity_hook_submit_action')),
              )
              .onPressed,
          isNull,
        );
      },
    );
  });
}

void _noopSubmit(String responseText, {required bool wasGrounded}) {}
