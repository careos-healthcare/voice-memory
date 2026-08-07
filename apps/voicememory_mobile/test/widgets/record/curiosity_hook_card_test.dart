import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart'
    as domain;
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/curiosity_prompt_generator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/widgets/curiosity_hook_card.dart';

domain.CuriosityHook _hook({
  required String prompt,
  bool isMemoryRecallCheck = false,
  String? sourceEntryId,
}) {
  return domain.CuriosityHook(
    id: 'hook_1',
    entryId: 'entry_1',
    createdAt: DateTime.utc(2026, 6, 12, 12),
    primaryAnchor: 'work pressure',
    hookType: domain.CuriosityHookType.blocker,
    dynamicPrompt: prompt,
    isMemoryRecallCheck: isMemoryRecallCheck,
    sourceEntryId: sourceEntryId,
  );
}

JournalEntry _sourceEntry({required CognitiveBiomarkers biomarkers}) {
  return JournalEntry(
    id: 'source_entry',
    createdAt: DateTime.utc(2026, 6, 11, 12),
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
    biomarkers: biomarkers,
  );
}

void main() {
  group('CuriosityHookPresentation', () {
    test('marks low cognitive load from source lexical diversity', () {
      final presentation = CuriosityHookPresentation.fromDomain(
        _hook(
          prompt: 'You touched on work pressure recently.',
          isMemoryRecallCheck: true,
          sourceEntryId: 'source_entry',
        ),
        sourceLexicalDiversity: 0.42,
      );

      expect(presentation.isLowCognitiveLoad, isTrue);
    });

    test('marks low cognitive load from synthesized prompt copy', () {
      final presentation = CuriosityHookPresentation.fromDomain(
        _hook(
          prompt:
              'You touched on work pressure recently. How does it look right now? '
              '${DefaultCuriosityPromptGenerator.lowCognitiveLoadTail}',
          isMemoryRecallCheck: true,
        ),
      );

      expect(presentation.isLowCognitiveLoad, isTrue);
    });

    test(
      'uses anomaly detector when current and baseline metrics are provided',
      () {
        const baselineMetrics = CognitiveBiomarkers(
          lexicalDiversity: 0.55,
          cohesionDrift: 0.35,
          emotionalVolatility: 0.40,
        );

        final overloadPresentation = CuriosityHookPresentation.fromDomain(
          _hook(
            prompt:
                'Reflecting back on your notes regarding work pressure—what changed?',
            isMemoryRecallCheck: false,
          ),
          currentMetrics: const CognitiveBiomarkers(
            lexicalDiversity: 0.42,
            cohesionDrift: 0.36,
            emotionalVolatility: 0.41,
          ),
          baselineMetrics: baselineMetrics,
        );

        expect(overloadPresentation.isLowCognitiveLoad, isTrue);

        final normalPresentation = CuriosityHookPresentation.fromDomain(
          _hook(
            prompt:
                'Reflecting back on your notes regarding work pressure—what changed?',
            isMemoryRecallCheck: false,
          ),
          currentMetrics: const CognitiveBiomarkers(
            lexicalDiversity: 0.50,
            cohesionDrift: 0.42,
            emotionalVolatility: 0.43,
          ),
          baselineMetrics: baselineMetrics,
        );

        expect(normalPresentation.isLowCognitiveLoad, isFalse);
      },
    );

    test(
      'maps drift overload to low cognitive load regardless of prompt copy',
      () {
        final presentation = CuriosityHookPresentation.fromDomain(
          _hook(
            prompt: 'What feels most worth noticing right now?',
            isMemoryRecallCheck: false,
          ),
          currentMetrics: const CognitiveBiomarkers(
            lexicalDiversity: 0.54,
            cohesionDrift: 0.52,
            emotionalVolatility: 0.41,
          ),
          baselineMetrics: const CognitiveBiomarkers(
            lexicalDiversity: 0.55,
            cohesionDrift: 0.35,
            emotionalVolatility: 0.40,
          ),
        );

        expect(presentation.isLowCognitiveLoad, isTrue);
      },
    );
  });

  group('CuriosityHookCard.fromDomain', () {
    testWidgets('renders breath gate for low cognitive load', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CuriosityHookCard.fromDomain(
              hook: _hook(
                prompt:
                    'You touched on work pressure recently. How does it look right now? '
                    '${DefaultCuriosityPromptGenerator.lowCognitiveLoadTail}',
                isMemoryRecallCheck: true,
              ),
              sourceEntry: _sourceEntry(
                biomarkers: const CognitiveBiomarkers(
                  lexicalDiversity: 0.42,
                  cohesionDrift: 0.2,
                  emotionalVolatility: 0.3,
                ),
              ),
              onSubmit: (_, {required wasGrounded}) {},
            ),
          ),
        ),
      );

      expect(find.text('Follow the Breath to Unlock Input'), findsOneWidget);
      expect(find.byKey(const Key('grounding_breath_spacer')), findsOneWidget);
    });

    testWidgets('renders immediate input for standard recall hooks', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CuriosityHookCard.fromDomain(
              hook: _hook(
                prompt:
                    'Reflecting back on your notes regarding work pressure—'
                    'what structural changes have occurred since that moment?',
                isMemoryRecallCheck: true,
              ),
              sourceEntry: _sourceEntry(
                biomarkers: const CognitiveBiomarkers(
                  lexicalDiversity: 0.72,
                  cohesionDrift: 0.18,
                  emotionalVolatility: 0.41,
                ),
              ),
              onSubmit: (_, {required wasGrounded}) {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('curiosity_hook_response_input')),
        findsOneWidget,
      );
      expect(find.text('Commit Response Telemetry'), findsOneWidget);
      expect(find.text('Follow the Breath to Unlock Input'), findsNothing);
    });

    testWidgets('disables submit button when callback is not provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CuriosityHookCard.fromDomain(
              hook: _hook(prompt: 'What feels most worth noticing right now?'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('curiosity_hook_prompt')), findsOneWidget);
      expect(
        find.byKey(const Key('curiosity_hook_submit_action')),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('curiosity_hook_submit_action')),
      );
      expect(button.onPressed, isNull);
    });
  });
}
