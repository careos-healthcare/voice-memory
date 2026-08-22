import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/curiosity_prompt_resolver.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final resolver = CuriosityPromptResolver();

  const reflection = Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  );

  CuriosityHook hook({
    bool isMemoryRecallCheck = false,
    String dynamicPrompt = 'Stored prompt fallback.',
  }) {
    return CuriosityHook(
      id: 'hook_1',
      entryId: 'entry_1',
      createdAt: DateTime.utc(2026, 6, 12, 12),
      primaryAnchor: 'work pressure',
      hookType: CuriosityHookType.blocker,
      dynamicPrompt: dynamicPrompt,
      isMemoryRecallCheck: isMemoryRecallCheck,
      sourceEntryId: isMemoryRecallCheck ? 'source_entry' : null,
    );
  }

  JournalEntry entry({required String id, CognitiveBiomarkers? biomarkers}) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 6, 11, 12),
      transcript: 'Work pressure showed up again today.',
      durationSeconds: 20,
      reflection: reflection,
      biomarkers: biomarkers,
    );
  }

  group('CuriosityPromptResolver', () {
    test('uses hook entry context for standard hooks', () async {
      final prompt = await resolver.resolveDisplayPrompt(
        hook: hook(),
        hookEntry: entry(
          id: 'entry_1',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.7,
            cohesionDrift: 0.81,
            emotionalVolatility: 0.3,
          ),
        ),
      );

      expect(prompt, contains("Let's focus on right now."));
    });

    test('uses source entry context for memory recall hooks', () async {
      final prompt = await resolver.resolveDisplayPrompt(
        hook: hook(isMemoryRecallCheck: true),
        sourceEntry: entry(
          id: 'source_entry',
          biomarkers: const CognitiveBiomarkers(
            lexicalDiversity: 0.42,
            cohesionDrift: 0.2,
            emotionalVolatility: 0.3,
          ),
        ),
        hookEntry: entry(id: 'entry_1'),
      );

      expect(prompt, contains('You touched on work pressure recently.'));
      expect(prompt, contains('Short thoughts are perfect.'));
    });

    test(
      'falls back to stored hook prompt when synthesis context is missing',
      () async {
        const fallback = 'Stored prompt fallback.';
        final prompt = await resolver.resolveDisplayPrompt(
          hook: hook(isMemoryRecallCheck: true),
        );

        expect(prompt, fallback);
      },
    );
  });
}