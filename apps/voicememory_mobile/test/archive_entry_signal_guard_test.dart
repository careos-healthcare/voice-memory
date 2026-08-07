import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_entry_signal_guard.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  String transcript = '',
  String observation = '',
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 20,
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: observation,
    repeatedSignal: '',
  ),
);

void main() {
  group('ArchiveEntrySignalGuard', () {
    test('flags placeholder one-word entries', () {
      for (final word in ['test', 'Test', 'hello', 'ok', 'asdf']) {
        expect(
          ArchiveEntrySignalGuard.isLowSignalText(word),
          isTrue,
          reason: word,
        );
      }
    });

    test('flags very short text under 20 meaningful characters', () {
      expect(ArchiveEntrySignalGuard.isLowSignalText('Test'), isTrue);
      expect(
        ArchiveEntrySignalGuard.isLowSignalText('Wanted to go home.'),
        isTrue,
      );
    });

    test('accepts meaningful repeated-entry text', () {
      expect(
        ArchiveEntrySignalGuard.isLowSignalText(
          'I had no capacity but I said yes again to the extra meeting today.',
        ),
        isFalse,
      );
    });

    test('uses transcript not AI observation for guard decision', () {
      final entry = _entry(
        id: 'e1',
        transcript: 'Test',
        observation:
            'You keep saying yes when you had no capacity at work today.',
      );
      expect(ArchiveEntrySignalGuard.isLowSignalEntry(entry), isTrue);
    });

    test('newestEntryIsLowSignal checks latest save only', () {
      final entries = [
        _entry(id: 'new', transcript: 'Test'),
        _entry(
          id: 'old',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
      ];
      expect(ArchiveEntrySignalGuard.newestEntryIsLowSignal(entries), isTrue);
    });
  });
}
