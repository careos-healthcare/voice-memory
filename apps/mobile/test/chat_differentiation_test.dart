import 'package:archiveme_mobile/features/chat_differentiation/chat_differentiation_copy.dart';
import 'package:archiveme_mobile/features/chat_differentiation/chat_differentiation_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({required String id, required DateTime createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript:
          'I said yes again even though I had no capacity for one more ask.',
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
    );

void main() {
  group('ChatDifferentiationCopy', () {
    test('visible strings avoid attack language', () {
      final joined = ChatDifferentiationCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in ChatDifferentiationCopy.bannedAttackPhrases) {
        expect(joined, isNot(contains(banned)), reason: banned);
      }
      expect(joined, contains('saved moments'));
      expect(joined, contains('different times'));
      expect(joined, contains('what returns'));
    });
  });

  group('ChatDifferentiationEngine', () {
    test('builds three timeline rows from saved moments', () {
      final rows = ChatDifferentiationEngine.timelineFromEntries([
        _entry(id: 'e3', createdAt: DateTime(2026, 6, 12, 12)),
        _entry(id: 'e1', createdAt: DateTime(2026, 6, 10, 12)),
        _entry(id: 'e2', createdAt: DateTime(2026, 6, 11, 12)),
      ]);
      expect(rows, hasLength(3));
      expect(rows[0].label, ChatDifferentiationCopy.timelineFirstSavedLabel);
      expect(rows[1].label, ChatDifferentiationCopy.timelineCameBackLabel);
      expect(rows[2].label, ChatDifferentiationCopy.timelineRepeatedAgainLabel);
      expect(rows[0].dateLabel, contains('10 June 2026'));
      expect(rows[2].dateLabel, contains('12 June 2026'));
    });
  });
}