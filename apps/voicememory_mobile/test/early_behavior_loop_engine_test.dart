import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/record/early_behavior_loop_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

const _engine = EarlyBehaviorLoopEngine();

JournalEntry _entry({
  required String id,
  String transcript = '',
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
  transcript: transcript,
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

void main() {
  group('EarlyBehaviorLoopEngine', () {
    test('2 entries with said yes and no capacity produce capacity loop', () {
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
      expect(insight.title, 'This looks like a capacity loop');
      expect(
        insight.loopLine,
        'Pressure shows up, then you say yes before checking your capacity.',
      );
      expect(insight.triggerLine, contains('Trigger:'));
      expect(insight.behaviorLine, contains('What you do:'));
      expect(insight.costLine, contains('Cost:'));
      expect(insight.evidenceLine.toLowerCase(), contains('said yes'));
      expect(insight.evidenceLine.toLowerCase(), contains('no capacity'));
      expect(
        insight.nextCheckLine,
        'Tomorrow, notice the moment before you agree.',
      );
    });

    test('2 entries with work deadline pressure produce work pressure loop', () {
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
      ]);

      expect(insight.shouldShow, isTrue);
      expect(insight.title, 'This looks like a work pressure loop');
      expect(insight.loopLine, contains('Work pressure builds'));
      expect(insight.nextCheckLine, contains('work is still in your head'));
    });

    test('2 entries with avoid delayed stuck produce avoidance loop', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript:
              'I put off the hard conversation again until later this week.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'I delayed starting the report and felt stuck before I could begin.',
        ),
      ]);

      expect(insight.shouldShow, isTrue);
      expect(insight.title, 'This looks like an avoidance loop');
      expect(insight.loopLine, contains('delay it until it feels heavier'));
      expect(insight.nextCheckLine, contains('avoid starting'));
    });

    test('2 unrelated entries produce no loop', () {
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

    test('1 weak keyword only produces no loop', () {
      final insight = _engine.build([
        _entry(
          id: 'a',
          transcript: 'Work was busy today and that was about it really.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript: 'I said I was fine when someone asked how I was.',
        ),
      ]);

      expect(insight.shouldShow, isFalse);
    });

    test('evidence line uses actual words when grounded', () {
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
      expect(insight.evidenceLine, startsWith('Your words included'));
      expect(insight.evidenceLine, contains('\''));
    });

    test('consumer copy avoids banned terms', () {
      final cases = [
        _engine.build([
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
        ]),
        _engine.build([
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
        ]),
      ];

      for (final insight in cases) {
        expect(insight.shouldShow, isTrue);
        final blob =
            '${insight.title} ${insight.loopLine} ${insight.evidenceLine} '
                    '${insight.nextCheckLine}'
                .toLowerCase();
        for (final banned in [
          'diagnosis',
          'therapy',
          'disorder',
          'voicememory',
          'voice memory',
        ]) {
          expect(blob, isNot(contains(banned)));
        }
        expect(RegExp(r'\bai\b').hasMatch(blob), isFalse);
      }
    });
  });
}
