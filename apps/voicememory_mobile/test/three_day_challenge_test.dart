import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_gates.dart';
import 'package:voicememory_mobile/features/three_day_challenge/three_day_challenge_copy.dart';
import 'package:voicememory_mobile/features/three_day_challenge/three_day_challenge_engine.dart';
import 'package:voicememory_mobile/features/three_day_challenge/three_day_challenge_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/record/three_day_challenge_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 24,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        '1',
        _strongRepeat,
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        '2',
        'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        '3',
        'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

void main() {
  group('ThreeDayChallengeEngine day states', () {
    test('zero entries shows day 1', () {
      final challenge = ThreeDayChallengeEngine.build(entries: []);
      expect(challenge, isNotNull);
      expect(challenge!.day, ThreeDayChallengeDay.day1);
      expect(challenge.title, ThreeDayChallengeCopy.day1Title);
      expect(challenge.body, ThreeDayChallengeCopy.day1Body);
      expect(challenge.entryCount, 0);
    });

    test('one entry shows day 2', () {
      final challenge = ThreeDayChallengeEngine.build(
        entries: [
          _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 12, 12)),
        ],
      );
      expect(challenge, isNotNull);
      expect(challenge!.day, ThreeDayChallengeDay.day2);
      expect(challenge.title, ThreeDayChallengeCopy.day2Title);
      expect(challenge.body, ThreeDayChallengeCopy.day2Body);
    });

    test('two entries across days shows day 3', () {
      final challenge = ThreeDayChallengeEngine.build(
        entries: [
          _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 11, 12)),
          _entry(
            '2',
            'Same thing — said yes when I had no capacity for one more thing.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );
      expect(challenge, isNotNull);
      expect(challenge!.day, ThreeDayChallengeDay.day3);
      expect(challenge.title, ThreeDayChallengeCopy.day3Title);
      expect(challenge.body, ThreeDayChallengeCopy.day3Body);
      expect(challenge.distinctDayCount, 2);
    });

    test('two entries on the same day stays on day 2', () {
      final challenge = ThreeDayChallengeEngine.build(
        entries: [
          _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 12, 9)),
          _entry(
            '2',
            'Same thing — said yes when I had no capacity for one more thing.',
            createdAt: DateTime(2026, 6, 12, 18),
          ),
        ],
      );
      expect(challenge?.day, ThreeDayChallengeDay.day2);
    });

    test('three entries marks completion and hides on record ready', () {
      final entries = _threeRelatedEntries();
      final challenge = ThreeDayChallengeEngine.build(entries: entries);
      expect(challenge, isNotNull);
      expect(challenge!.day, ThreeDayChallengeDay.complete);
      expect(challenge.body, ThreeDayChallengeCopy.completionBody);
      expect(
        ThreeDayChallengeGates.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          challenge: challenge,
        ),
        isFalse,
      );
    });

    test('comparison-ready repeat foundation completes without faking proof', () {
      final entries = _threeRelatedEntries();
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );

      final challenge = ThreeDayChallengeEngine.build(entries: entries);
      expect(challenge?.isComplete, isTrue);
      expect(challenge?.body, ThreeDayChallengeCopy.completionBody);
      expect(challenge!.entryCount, 3);
      expect(
        ThreeDayChallengeGates.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          challenge: challenge,
        ),
        isFalse,
      );
    });
  });

  group('ThreeDayChallengeGates', () {
    test('hidden during post-save first proof', () {
      final entries = _threeRelatedEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries);
      expect(payoff, isNotNull);
      expect(
        FirstProofPayoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: entries.length,
          isDegradedPostSave: false,
          payoff: payoff,
        ),
        isTrue,
      );

      final challenge = ThreeDayChallengeEngine.build(entries: entries);
      expect(
        ThreeDayChallengeGates.shouldShow(
          isReady: false,
          isRecording: false,
          isPostSave: true,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: true,
          challenge: challenge,
        ),
        isFalse,
      );
    });

    test('hidden during degraded transcript', () {
      final degraded = _entry(
        'd1',
        _placeholder,
        createdAt: DateTime(2026, 6, 12, 12),
      );
      expect(
        ThreeDayChallengeEngine.shouldHideForDegradedTranscript([degraded]),
        isTrue,
      );
      expect(
        ThreeDayChallengeEngine.build(entries: [degraded]),
        isNull,
      );
      expect(
        ThreeDayChallengeGates.shouldShow(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: true,
          firstProofPayoffVisible: false,
          challenge: const ThreeDayChallengeState(
            day: ThreeDayChallengeDay.day2,
            title: ThreeDayChallengeCopy.day2Title,
            body: ThreeDayChallengeCopy.day2Body,
            entryCount: 1,
            distinctDayCount: 1,
            isComplete: false,
          ),
        ),
        isFalse,
      );
    });

    test('hidden for non-early users', () {
      final entries = List.generate(
        8,
        (index) => _entry(
          'e$index',
          _strongRepeat,
          createdAt: DateTime(2026, 6, 1 + index, 12),
        ),
      );
      expect(ThreeDayChallengeEngine.build(entries: entries), isNull);
    });
  });

  group('ThreeDayChallenge copy guard', () {
    test('no fake proof or medical therapy claims', () {
      final blob = ThreeDayChallengeCopy.all.join(' ').toLowerCase();
      expect(blob, isNot(contains('pattern found')));
      expect(blob, isNot(contains('confirmed repeat')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('medical treatment')));
      expect(blob, isNot(contains('guaranteed')));
      expect(blob, contains('save one small moment'));
      expect(blob, contains('see what returned'));
      expect(blob, contains('come back when something stands out'));
      expect(blob, contains('no daily journal required'));
    });
  });

  group('ThreeDayChallengeCard', () {
    testWidgets('renders day title and day body without CTA', (tester) async {
      const challenge = ThreeDayChallengeState(
        day: ThreeDayChallengeDay.day1,
        title: ThreeDayChallengeCopy.day1Title,
        body: ThreeDayChallengeCopy.day1Body,
        entryCount: 0,
        distinctDayCount: 0,
        isComplete: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThreeDayChallengeCard(challenge: challenge),
          ),
        ),
      );

      expect(find.byKey(const Key('three_day_challenge_card')), findsOneWidget);
      expect(find.text(ThreeDayChallengeCopy.day1Title), findsOneWidget);
      expect(find.text(ThreeDayChallengeCopy.day1Body), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
