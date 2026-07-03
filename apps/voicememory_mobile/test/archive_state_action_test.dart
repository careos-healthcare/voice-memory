import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/next_action/archive_state_action_copy.dart';
import 'package:voicememory_mobile/features/next_action/archive_state_action_engine.dart';
import 'package:voicememory_mobile/features/next_action/archive_state_action_model.dart';
import 'package:voicememory_mobile/features/next_action/next_best_action_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 24,
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
}

List<JournalEntry> _threeRelatedRepeatEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _fourRelatedRepeatEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

List<JournalEntry> _fourRelatedRepeatWithHelpfulAction() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I paused before replying this time and it felt a bit softer.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

RepeatReturnCheckRecord _choiceRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) =>
    RepeatReturnCheckRecord(
      entryId: entryId,
      choice: choice,
      entryCountAtCapture: 4,
      createdAt: DateTime(2026, 6, 13, 12),
    );

void _expectNoAdviceLanguage(String copy) {
  for (final phrase in ProofSurfaceAdviceGuard.bannedAdvicePhrases) {
    expect(
      copy.toLowerCase(),
      isNot(contains(phrase)),
      reason: 'must not contain "$phrase"',
    );
  }
  expect(copy.toLowerCase(), isNot(contains('therapy')));
  expect(copy.toLowerCase(), isNot(contains('diagnosis')));
  expect(copy.toLowerCase(), isNot(contains('you always')));
}

void main() {
  group('ArchiveStateActionCopy', () {
    test('nextLine prefixes canonical actions for subordinate UI', () {
      expect(
        ArchiveStateActionCopy.nextLine(ArchiveStateActionCopy.noEntries),
        NextBestActionCopy.noEntriesTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(ArchiveStateActionCopy.oneEntry),
        NextBestActionCopy.oneEntryTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(ArchiveStateActionCopy.twoUnrelated),
        NextBestActionCopy.twoNoClearMatchTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(ArchiveStateActionCopy.twoRelated),
        NextBestActionCopy.twoRelatedTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(ArchiveStateActionCopy.firstProof),
        NextBestActionCopy.firstProofTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(
          ArchiveStateActionCopy.returnCheckUnanswered,
        ),
        NextBestActionCopy.returnCheckUnansweredTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(ArchiveStateActionCopy.returnCheckAnswered),
        NextBestActionCopy.returnCheckAnsweredTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(ArchiveStateActionCopy.patternChanged),
        NextBestActionCopy.patternChangedTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(
          ArchiveStateActionCopy.helpfulActionAppeared,
        ),
        NextBestActionCopy.helpfulActionTitle,
      );
      expect(
        ArchiveStateActionCopy.nextLine(
          ArchiveStateActionCopy.privateReportForming,
        ),
        NextBestActionCopy.privateReportFormingTitle,
      );
    });
  });

  group('ArchiveStateActionEngine', () {
    test('0 entries maps to record one real moment on Record capture', () {
      final result = ArchiveStateActionEngine.build(entries: const []);

      expect(result.kind, ArchiveStateActionKind.noEntries);
      expect(result.actionLabel, ArchiveStateActionCopy.noEntries);
      expect(
        result.baseDestination,
        ArchiveStateActionDestination.recordCapture,
      );
      expect(
        result.resolvedDestination(surface: ArchiveStateActionSurface.record),
        ArchiveStateActionDestination.recordCapture,
      );
    });

    test('1 entry maps to come back when similar on Record capture', () {
      final result = ArchiveStateActionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      expect(result.kind, ArchiveStateActionKind.oneEntry);
      expect(result.actionLabel, ArchiveStateActionCopy.oneEntry);
      expect(
        result.baseDestination,
        ArchiveStateActionDestination.recordCapture,
      );
    });

    test('2 unrelated maps to record next real moment on Record capture', () {
      final result = ArchiveStateActionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
          _entry(
            id: '2',
            transcript: 'Another unrelated note about errands this afternoon.',
          ),
        ],
      );

      expect(result.kind, ArchiveStateActionKind.twoUnrelated);
      expect(result.actionLabel, ArchiveStateActionCopy.twoUnrelated);
      expect(
        result.baseDestination,
        ArchiveStateActionDestination.recordCapture,
      );
    });

    test('2 related maps to record one more related moment on Record capture', () {
      final result = ArchiveStateActionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
          _entry(
            id: '2',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
          ),
        ],
      );

      expect(result.kind, ArchiveStateActionKind.twoRelated);
      expect(result.actionLabel, ArchiveStateActionCopy.twoRelated);
      expect(
        result.baseDestination,
        ArchiveStateActionDestination.recordCapture,
      );
    });

    test('first proof maps to record when it returns on Record capture', () {
      final result = ArchiveStateActionEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      expect(result.kind, ArchiveStateActionKind.firstProof);
      expect(result.actionLabel, ArchiveStateActionCopy.firstProof);
      expect(
        result.baseDestination,
        ArchiveStateActionDestination.recordCapture,
      );
    });

    test('return check unanswered routes to answer card when available', () {
      final result = ArchiveStateActionEngine.build(
        entries: _fourRelatedRepeatEntries(),
      );

      expect(result.kind, ArchiveStateActionKind.returnCheckUnanswered);
      expect(result.actionLabel, ArchiveStateActionCopy.returnCheckUnanswered);
      expect(
        result.resolvedDestination(
          surface: ArchiveStateActionSurface.record,
          postSaveReturnCheckAnswerAvailable: true,
        ),
        ArchiveStateActionDestination.returnCheckAnswer,
      );
      expect(
        result.resolvedDestination(
          surface: ArchiveStateActionSurface.patterns,
          postSaveReturnCheckAnswerAvailable: false,
        ),
        ArchiveStateActionDestination.patterns,
      );
    });

    test('return check answered routes to Patterns only after proof exists', () {
      final result = ArchiveStateActionEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
          ),
        ],
      );

      expect(result.kind, ArchiveStateActionKind.returnCheckAnswered);
      expect(result.actionLabel, ArchiveStateActionCopy.returnCheckAnswered);
      expect(
        result.baseDestination,
        ArchiveStateActionDestination.patterns,
      );
      expect(result.routesToPatterns, isTrue);
    });

    test('pattern changed maps to record when it returns on Record capture', () {
      final entries = [
        ..._threeRelatedRepeatEntries(),
        _entry(
          id: 'e4',
          transcript:
              'I said yes again even though I had no capacity for one more ask today.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ];
      final result = ArchiveStateActionEngine.build(
        entries: entries,
        returnChecks: [
          _choiceRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
      );

      expect(result.kind, ArchiveStateActionKind.patternChanged);
      expect(result.actionLabel, ArchiveStateActionCopy.patternChanged);
      expect(
        result.baseDestination,
        ArchiveStateActionDestination.recordCapture,
      );
    });

    test('helpful action maps to watch whether it appears again on Patterns', () {
      final result = ArchiveStateActionEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
      );

      expect(result.kind, ArchiveStateActionKind.helpfulActionAppeared);
      expect(result.actionLabel, ArchiveStateActionCopy.helpfulActionAppeared);
      expect(
        result.resolvedDestination(surface: ArchiveStateActionSurface.patterns),
        ArchiveStateActionDestination.patternsOrTimeline,
      );
    });

    test('private report forming routes by surface', () {
      final result = ArchiveStateActionEngine.build(
        entries: _threeRelatedRepeatEntries(),
        privateReportForming: true,
      );

      expect(result.kind, ArchiveStateActionKind.privateReportForming);
      expect(result.actionLabel, ArchiveStateActionCopy.privateReportForming);
      expect(
        result.resolvedDestination(surface: ArchiveStateActionSurface.record),
        ArchiveStateActionDestination.recordCapture,
      );
      expect(
        result.resolvedDestination(surface: ArchiveStateActionSurface.patterns),
        ArchiveStateActionDestination.proPreview,
      );
    });

    test('each build returns one canonical action label', () {
      final scenarios = [
        ArchiveStateActionEngine.build(entries: const []),
        ArchiveStateActionEngine.build(
          entries: [_entry(id: '1', transcript: 'One saved moment today.')],
        ),
        ArchiveStateActionEngine.build(
          entries: [
            _entry(id: '1', transcript: 'Lunch with a friend today.'),
            _entry(id: '2', transcript: 'Errands this afternoon.'),
          ],
        ),
        ArchiveStateActionEngine.build(entries: _threeRelatedRepeatEntries()),
        ArchiveStateActionEngine.build(
          entries: _fourRelatedRepeatEntries(),
          returnChecks: [
            _choiceRecord(
              entryId: 'e4',
              choice: RepeatReturnCheckChoice.softer,
            ),
          ],
        ),
      ];

      for (final result in scenarios) {
        expect(result.actionLabel, isNotEmpty);
        expect(
          ArchiveStateActionCopy.allActionLabels,
          contains(result.actionLabel),
        );
      }
    });

    test('early states do not route to Patterns before proof value exists', () {
      for (final result in [
        ArchiveStateActionEngine.build(entries: const []),
        ArchiveStateActionEngine.build(
          entries: [_entry(id: '1', transcript: 'One saved moment today.')],
        ),
        ArchiveStateActionEngine.build(
          entries: [
            _entry(id: '1', transcript: 'Lunch with a friend today.'),
            _entry(id: '2', transcript: 'Errands this afternoon.'),
          ],
        ),
      ]) {
        expect(result.routesToPatterns, isFalse);
        expect(
          result.resolvedDestination(surface: ArchiveStateActionSurface.record),
          ArchiveStateActionDestination.recordCapture,
        );
      }
    });

    test('no transcript phrase or user content in action labels', () {
      final entries = _fourRelatedRepeatWithHelpfulAction();
      final privateText = entries.last.transcript;
      final result = ArchiveStateActionEngine.build(entries: entries);

      expect(result.actionLabel, isNot(contains(privateText)));
      expect(result.actionLabel, isNot(contains('said yes again')));
    });

    test('copy avoids advice coaching and therapy language', () {
      for (final text in ArchiveStateActionCopy.allActionLabels) {
        _expectNoAdviceLanguage(text);
      }
      for (final text in NextBestActionCopy.allVisibleStrings) {
        _expectNoAdviceLanguage(text);
      }
    });
  });
}
