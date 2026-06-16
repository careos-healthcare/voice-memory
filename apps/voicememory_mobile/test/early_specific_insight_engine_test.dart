import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/record/early_specific_insight_copy.dart';
import 'package:voicememory_mobile/features/record/early_specific_insight_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

const _engine = EarlySpecificInsightEngine();

JournalEntry _entry({
  required String id,
  String transcript = '',
  String observation = '',
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
      transcript: transcript,
      durationSeconds: 30,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: observation,
        repeatedSignal: '',
      ),
    );

void main() {
  group('EarlySpecificInsightEngine', () {
    test('with 0 entries returns no insight', () {
      final insight = _engine.build(const []);
      expect(insight.shouldShow, isFalse);
    });

    test('with 1 entry makes no pattern claim', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript: 'I had no capacity but I said yes again to the meeting.',
        ),
      ]);
      expect(insight.shouldShow, isFalse);
    });

    test('with 2 entries sharing no capacity and said yes shows sharp repeat', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
      ]);

      expect(insight.shouldShow, isTrue);
      expect(insight.title, EarlySpecificInsightCopy.sharpTitle);
      expect(
        insight.oneLinePattern,
        'Both moments mention saying yes when you had no capacity.',
      );
      expect(insight.evidenceLine, contains('no capacity'));
      expect(insight.evidenceLine, contains('said yes'));
      expect(
        insight.nextQuestion,
        'Tomorrow, notice if this shows up before you agree to something.',
      );
      expect(insight.confidenceLabel, 'Early signal — based on 2 moments');
    });

    test('with 2 unrelated entries does not fake a repeat insight', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript:
              'Today I went for a long walk in the park near home after lunch.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'I cooked pasta for dinner and watched a film alone tonight.',
        ),
      ]);

      expect(insight.shouldShow, isFalse);
    });

    test('with 3 entries sharing work pressure language uses actual words', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript:
              'Work pressure hit again before the deadline this week at work.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'The work pressure showed up when my manager emailed late again.',
        ),
        _entry(
          id: 'c',
          createdAt: DateTime(2026, 6, 3, 12),
          transcript:
              'Another deadline and work pressure before I could rest tonight.',
        ),
      ]);

      expect(insight.shouldShow, isTrue);
      expect(
        insight.oneLinePattern,
        'Both moments mention work pressure showing up in what you said.',
      );
      expect(insight.evidenceLine.toLowerCase(), contains('work pressure'));
      expect(insight.confidenceLabel, 'Early signal — based on 3 moments');
    });

    test('consumer copy avoids banned terms and unsupported claims', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
      ]);

      final blob =
          '${insight.title} ${insight.oneLinePattern} ${insight.evidenceLine} '
                  '${insight.nextQuestion} ${insight.confidenceLabel}'
              .toLowerCase();

      expect(insight.shouldShow, isTrue);

      for (final banned in [
        'diagnosis',
        'therapy',
        'voicememory',
        'voice memory',
        'wellbeing',
        'your archive is learning',
      ]) {
        expect(blob, isNot(contains(banned)), reason: 'found banned: $banned');
      }
      expect(RegExp(r'\bai\b').hasMatch(blob), isFalse);
    });

    test('evidence line quotes or paraphrases saved words', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
      ]);

      expect(insight.evidenceLine, startsWith('You used the words'));
      expect(insight.evidenceLine, contains('\''));
    });

    test('next question is specific not generic', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
      ]);

      expect(insight.nextQuestion, isNot(contains('come back')));
      expect(insight.nextQuestion, isNot(contains('keep recording')));
      expect(insight.nextQuestion, contains('Tomorrow'));
      expect(insight.nextQuestion.length, greaterThan(20));
    });
  });
}
