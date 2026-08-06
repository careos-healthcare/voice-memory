import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/curiosity_hook.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  group('JournalEntry biomarkers', () {
    test('round trips biomarkers through json', () {
      final entry = JournalEntry(
        id: 'entry_1',
        createdAt: DateTime.utc(2026, 6, 12, 12),
        transcript: 'I said yes again even though I had no capacity.',
        durationSeconds: 30,
        reflection: const Reflection(
          mood: 'thoughtful',
          emotionalIntensity: 2,
          recurringThemes: ['work'],
          exactLanguagePattern: '',
          concreteObservation: 'Work pressure showed up again today.',
          repeatedSignal: '',
        ),
        biomarkers: const CognitiveBiomarkers(
          lexicalDiversity: 0.64,
          cohesionDrift: 0.22,
          emotionalVolatility: 0.37,
        ),
      );

      final restored = JournalEntry.fromJson(entry.toJson());

      expect(restored.biomarkers, entry.biomarkers);
    });

    test('missing biomarkers degrade gracefully to null', () {
      final restored = JournalEntry.fromJson({
        'id': 'entry_1',
        'createdAt': '2026-06-12T12:00:00.000Z',
        'transcript': 'Legacy entry without biomarkers.',
        'durationSeconds': 20,
        'reflection': {
          'mood': 'neutral',
          'emotionalIntensity': 1,
          'recurringThemes': [],
          'exactLanguagePattern': '',
          'concreteObservation': 'Legacy payload.',
          'repeatedSignal': '',
        },
      });

      expect(restored.biomarkers, isNull);
    });

    test('copyWith updates biomarkers', () {
      final entry = JournalEntry(
        id: 'entry_1',
        createdAt: DateTime.utc(2026, 6, 12, 12),
        transcript: 'Sample entry',
        durationSeconds: 20,
        reflection: const Reflection(
          mood: 'neutral',
          emotionalIntensity: 1,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: 'Sample observation.',
          repeatedSignal: '',
        ),
      );

      const biomarkers = CognitiveBiomarkers(
        lexicalDiversity: 0.5,
        cohesionDrift: 0.1,
        emotionalVolatility: 0.2,
      );

      final updated = entry.copyWith(biomarkers: biomarkers);

      expect(updated.biomarkers, biomarkers);
    });
  });

  group('CuriosityHook memory recall fields', () {
    test('round trips sourceEntryId and isMemoryRecallCheck', () {
      final hook = CuriosityHook(
        id: 'hook_1',
        entryId: 'entry_1',
        createdAt: DateTime.utc(2026, 6, 12, 12),
        primaryAnchor: 'said yes again',
        hookType: CuriosityHookType.blocker,
        dynamicPrompt:
            'What got in the way before "said yes again" showed up again?',
        sourceEntryId: 'entry_0',
        isMemoryRecallCheck: true,
      );

      final restored = CuriosityHook.fromJson(hook.toJson());

      expect(restored, isNotNull);
      expect(restored!.sourceEntryId, 'entry_0');
      expect(restored.isMemoryRecallCheck, isTrue);
    });

    test('legacy json without memory recall fields defaults safely', () {
      final restored = CuriosityHook.fromJson({
        'id': 'hook_1',
        'entryId': 'entry_1',
        'createdAt': '2026-06-12T12:00:00.000Z',
        'primaryAnchor': 'said yes again',
        'hookType': 'blocker',
        'dynamicPrompt': 'What got in the way?',
      });

      expect(restored, isNotNull);
      expect(restored!.sourceEntryId, isNull);
      expect(restored.isMemoryRecallCheck, isFalse);
    });
  });
}
