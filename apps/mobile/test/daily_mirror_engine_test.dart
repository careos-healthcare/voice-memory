import 'package:archiveme_mobile/features/record/daily_mirror_copy.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_engine.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_stage.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

const _engine = DailyMirrorEngine();

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
  group('DailyMirrorEngine', () {
    test('0 entries returns emptyArchive and no evidence', () {
      final result = _engine.build(const []);

      expect(result.stage, DailyMirrorStage.emptyArchive);
      expect(result.heroTitle, DailyMirrorCopy.emptyTitle);
      expect(result.heroBody, DailyMirrorCopy.emptySubtitle);
      expect(result.primaryCta, DailyMirrorCopy.emptyPrimaryCta);
      expect(result.hasGroundedEvidence, isFalse);
      expect(result.evidenceTerms, isEmpty);
      expect(result.evidenceEntryIds, isEmpty);
    });

    test('1 entry returns heardFirstMoment', () {
      final result = _engine.build([
        _entry(
          id: 'a',
          transcript:
              'A long enough transcript to count as a saved reflection for tests.',
        ),
      ]);

      expect(result.stage, DailyMirrorStage.heardFirstMoment);
      expect(result.heroTitle, DailyMirrorCopy.heardHeroTitle);
      expect(result.heroBody, DailyMirrorCopy.heardHeroBody);
      expect(result.primaryCta, DailyMirrorCopy.heardPrimaryCta);
      expect(result.hasGroundedEvidence, isFalse);
    });

    test('2 capacity entries stay weak-started until a third usable moment', () {
      final result = _engine.build([
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

      expect(result.stage, DailyMirrorStage.heardFirstMoment);
      expect(result.hasGroundedEvidence, isFalse);
      expect(result.heroTitle, DailyMirrorCopy.weakStartedHeroTitle);
      expect(result.heroBody, DailyMirrorCopy.weakStartedHeroBody);
      expect(result.evidenceLine, isNull);
      expect(result.evidenceTerms, isEmpty);
      expect(result.nextQuestion, isNull);
      expect(result.primaryCta, DailyMirrorCopy.heardPrimaryCta);
    });

    test('3 work pressure entries returns possibleLoop', () {
      final result = _engine.build([
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

      expect(result.stage, DailyMirrorStage.possibleLoop);
      expect(result.hasGroundedEvidence, isTrue);
      expect(result.heroBody.toLowerCase(), contains('work pressure'));
    });

    test(
      '4 entries where latest pauses before saying yes after capacity loop returns whatChanged',
      () {
        final result = _engine.build([
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
          _entry(
            id: 'c',
            createdAt: DateTime(2026, 6, 3, 12),
            transcript:
                'I said yes again even though I had no capacity for one more ask.',
          ),
          _entry(
            id: 'd',
            createdAt: DateTime(2026, 6, 4, 12),
            transcript:
                'I paused before saying yes when they asked me to take on more work.',
          ),
        ]);

        expect(result.stage, DailyMirrorStage.whatChanged);
        expect(result.hasChange, isTrue);
        expect(result.hasGroundedEvidence, isTrue);
        expect(result.heroTitle, DailyMirrorCopy.whatChangedHeroTitle);
        expect(result.heroBody, DailyMirrorCopy.whatChangedCaughtBody);
        expect(result.evidenceLine, isNotNull);
        expect(result.evidenceLine, contains('→'));
        expect(result.nextQuestion, DailyMirrorCopy.whatChangedNextQuestion);
      },
    );

    test('unrelated entries do not fabricate a loop or change', () {
      final two = _engine.build([
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

      expect(two.stage, DailyMirrorStage.heardFirstMoment);
      expect(two.hasGroundedEvidence, isFalse);
      expect(two.hasChange, isFalse);

      final four = _engine.build([
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
        _entry(
          id: 'c',
          createdAt: DateTime(2026, 6, 3, 12),
          transcript:
              'The weather was sunny and I read a book on the balcony today.',
        ),
        _entry(
          id: 'd',
          createdAt: DateTime(2026, 6, 4, 12),
          transcript:
              'I called a friend and we talked about movies for a while tonight.',
        ),
      ]);

      expect(four.stage, DailyMirrorStage.heardFirstMoment);
      expect(four.hasGroundedEvidence, isFalse);
      expect(four.hasChange, isFalse);
      expect(four.heroBody, DailyMirrorCopy.safeDeepArchiveHeroBody);
    });

    test('consumer copy does not say VoiceMemory', () {
      final cases = [
        _engine.build(const []),
        _engine.build([
          _entry(
            id: 'a',
            transcript:
                'A long enough transcript to count as a saved reflection for tests.',
          ),
        ]),
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
      ];

      for (final result in cases) {
        final blob =
            '${result.heroTitle} ${result.heroBody} ${result.evidenceLine ?? ''} '
                    '${result.nextQuestion ?? ''} ${result.primaryCta}'
                .toLowerCase();
        for (final banned in const ['voicememory', 'voice memory']) {
          expect(blob, isNot(contains(banned.trim())));
        }
      }
    });
  });
}