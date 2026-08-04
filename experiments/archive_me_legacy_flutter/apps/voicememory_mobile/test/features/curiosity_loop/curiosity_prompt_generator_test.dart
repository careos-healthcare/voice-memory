import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/curiosity_prompt_generator.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  const generator = DefaultCuriosityPromptGenerator();

  const reflection = Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  );

  CuriosityHook hook({
    required String id,
    String primaryAnchor = 'work pressure',
    bool isMemoryRecallCheck = false,
    String dynamicPrompt = '',
    CuriosityHookType hookType = CuriosityHookType.anchorFollowUp,
  }) {
    return CuriosityHook(
      id: id,
      entryId: 'entry_$id',
      createdAt: DateTime.utc(2026, 6, 12, 12),
      primaryAnchor: primaryAnchor,
      hookType: hookType,
      dynamicPrompt: dynamicPrompt,
      isMemoryRecallCheck: isMemoryRecallCheck,
      sourceEntryId: isMemoryRecallCheck ? 'source_$id' : null,
    );
  }

  JournalEntry sourceEntry({
    required String id,
    CognitiveBiomarkers? biomarkers,
    String transcript = 'Work pressure showed up again today.',
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 6, 11, 12),
      transcript: transcript,
      durationSeconds: 20,
      reflection: reflection,
      biomarkers: biomarkers,
    );
  }

  group('CuriosityPromptGenerator', () {
    test(
      'memory recall with low lexical diversity uses low-cognitive-load syntax',
      () async {
        final prompt = await generator.generatePrompt(
          hook: hook(
            id: 'recall_low',
            isMemoryRecallCheck: true,
            primaryAnchor: 'work pressure',
          ),
          sourceEntry: sourceEntry(
            id: 'source_recall_low',
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.42,
              cohesionDrift: 0.2,
              emotionalVolatility: 0.3,
            ),
          ),
        );

        expect(
          prompt,
          contains(DefaultCuriosityPromptGenerator.lowCognitiveLoadLeadIn),
        );
        expect(prompt, contains('work pressure'));
        expect(prompt, contains('recently'));
        expect(prompt, contains('How does it look right now?'));
        expect(
          prompt,
          contains(DefaultCuriosityPromptGenerator.lowCognitiveLoadTail),
        );
        expect(
          prompt,
          isNot(contains(DefaultCuriosityPromptGenerator.advancedRecallLeadIn)),
        );
      },
    );

    test(
      'memory recall with stable biomarkers uses advanced recall bridge',
      () async {
        final prompt = await generator.generatePrompt(
          hook: hook(
            id: 'recall_stable',
            isMemoryRecallCheck: true,
            primaryAnchor: 'work pressure',
          ),
          sourceEntry: sourceEntry(
            id: 'source_recall_stable',
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.72,
              cohesionDrift: 0.18,
              emotionalVolatility: 0.41,
            ),
          ),
        );

        expect(
          prompt,
          contains(DefaultCuriosityPromptGenerator.advancedRecallLeadIn),
        );
        expect(prompt, contains('work pressure'));
        expect(
          prompt,
          contains(DefaultCuriosityPromptGenerator.advancedRecallTail),
        );
      },
    );

    test(
      'standard hook with high cohesion drift produces grounding prompt',
      () async {
        final prompt = await generator.generatePrompt(
          hook: hook(id: 'grounding'),
          sourceEntry: sourceEntry(
            id: 'source_grounding',
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.7,
              cohesionDrift: 0.81,
              emotionalVolatility: 0.4,
            ),
          ),
        );

        expect(
          prompt,
          contains(DefaultCuriosityPromptGenerator.groundingLeadIn),
        );
        expect(
          prompt,
          contains(DefaultCuriosityPromptGenerator.groundingQuestion),
        );
      },
    );

    test(
      'standard hook defaults to forward-looking curiosity question',
      () async {
        final prompt = await generator.generatePrompt(
          hook: hook(
            id: 'forward',
            primaryAnchor: 'said yes again',
            hookType: CuriosityHookType.blocker,
          ),
          sourceEntry: sourceEntry(
            id: 'source_forward',
            biomarkers: const CognitiveBiomarkers(
              lexicalDiversity: 0.7,
              cohesionDrift: 0.2,
              emotionalVolatility: 0.3,
            ),
          ),
        );

        expect(prompt, contains('said yes again'));
        expect(prompt.toLowerCase(), contains('watch for'));
        expect(
          prompt,
          isNot(contains(DefaultCuriosityPromptGenerator.groundingLeadIn)),
        );
      },
    );

    test(
      'memory recall without source entry falls back to hook prompt',
      () async {
        const fallbackPrompt =
            'Before "work pressure" showed up again, what got in the way?';

        final prompt = await generator.generatePrompt(
          hook: hook(
            id: 'recall_fallback',
            isMemoryRecallCheck: true,
            dynamicPrompt: fallbackPrompt,
          ),
        );

        expect(prompt, fallbackPrompt);
      },
    );

    test(
      'memory recall without source entry or dynamic prompt uses forward fallback',
      () async {
        final prompt = await generator.generatePrompt(
          hook: hook(
            id: 'recall_empty',
            isMemoryRecallCheck: true,
            primaryAnchor: 'work pressure',
            hookType: CuriosityHookType.anchorFollowUp,
          ),
        );

        expect(prompt, contains('work pressure'));
        expect(prompt.toLowerCase(), contains('notice'));
      },
    );
  });
}
