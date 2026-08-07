import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/curiosity_prompt_generator.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/models/curiosity_hook_presentation.dart';

CuriosityHook _hook({
  required String prompt,
  bool isMemoryRecallCheck = false,
}) {
  return CuriosityHook(
    id: 'hook_1',
    entryId: 'entry_1',
    createdAt: DateTime.utc(2026, 6, 12, 12),
    primaryAnchor: 'work pressure',
    hookType: CuriosityHookType.blocker,
    dynamicPrompt: prompt,
    isMemoryRecallCheck: isMemoryRecallCheck,
  );
}

void main() {
  group('CuriosityHookPresentation.fromDomain', () {
    const baselineMetrics = CognitiveBiomarkers(
      lexicalDiversity: 0.55,
      cohesionDrift: 0.35,
      emotionalVolatility: 0.40,
    );

    test('maps overload relative to baseline to low cognitive load', () {
      final presentation = CuriosityHookPresentation.fromDomain(
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

      expect(presentation.isLowCognitiveLoad, isTrue);
    });

    test('maps normal metrics relative to baseline to standard load', () {
      final presentation = CuriosityHookPresentation.fromDomain(
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

      expect(presentation.isLowCognitiveLoad, isFalse);
    });

    test(
      'uses anomaly detector regardless of prompt copy when metrics are provided',
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
          baselineMetrics: baselineMetrics,
        );

        expect(presentation.isLowCognitiveLoad, isTrue);
      },
    );

    test(
      'falls back to legacy lexical diversity rule when baseline is missing',
      () {
        final presentation = CuriosityHookPresentation.fromDomain(
          _hook(
            prompt: 'You touched on work pressure recently.',
            isMemoryRecallCheck: true,
          ),
          sourceLexicalDiversity: 0.42,
        );

        expect(presentation.isLowCognitiveLoad, isTrue);
      },
    );

    test('falls back to legacy prompt tail when baseline is missing', () {
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
      'falls back to legacy checks when only baseline metrics are provided',
      () {
        final presentation = CuriosityHookPresentation.fromDomain(
          _hook(
            prompt: 'What feels most worth noticing right now?',
            isMemoryRecallCheck: false,
          ),
          baselineMetrics: baselineMetrics,
        );

        expect(presentation.isLowCognitiveLoad, isFalse);
      },
    );
  });
}
