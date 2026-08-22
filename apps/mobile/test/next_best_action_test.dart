import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:archiveme_mobile/features/next_action/next_best_action_copy.dart';
import 'package:archiveme_mobile/features/next_action/next_best_action_engine.dart';
import 'package:archiveme_mobile/features/next_action/next_best_action_gates.dart';
import 'package:archiveme_mobile/features/next_action/next_best_action_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/next_action/next_best_action_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    transcript: 'I paused before replying this time and it felt a bit softer.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

RepeatReturnCheckRecord _choiceRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) => RepeatReturnCheckRecord(
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
  group('NextBestActionEngine', () {
    test('0 entries shows record one real moment', () {
      final result = NextBestActionEngine.build(entries: const []);

      expect(result.kind, NextBestActionKind.noEntries);
      expect(result.titleLine, NextBestActionCopy.noEntriesTitle);
      expect(result.helperLine, NextBestActionCopy.noEntriesHelper);
    });

    test('1 entry shows come back when similar happens', () {
      final result = NextBestActionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      expect(result.kind, NextBestActionKind.oneEntry);
      expect(result.titleLine, NextBestActionCopy.oneEntryTitle);
      expect(result.helperLine, NextBestActionCopy.oneEntryHelper);
    });

    test('2 unrelated shows record next real moment', () {
      final result = NextBestActionEngine.build(
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

      expect(result.kind, NextBestActionKind.twoNoClearMatch);
      expect(result.titleLine, NextBestActionCopy.twoNoClearMatchTitle);
    });

    test('2 related shows one more related moment', () {
      final result = NextBestActionEngine.build(
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

      expect(result.kind, NextBestActionKind.twoRelated);
      expect(result.titleLine, NextBestActionCopy.twoRelatedTitle);
    });

    test('first proof shows record when this comes back', () {
      final result = NextBestActionEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      expect(result.kind, NextBestActionKind.firstProof);
      expect(result.titleLine, NextBestActionCopy.firstProofTitle);
      expect(result.helperLine, NextBestActionCopy.firstProofHelper);
    });

    test('return check unanswered shows answer return check', () {
      final entries = _fourRelatedRepeatEntries();
      final result = NextBestActionEngine.build(
        entries: entries,
      );

      expect(result.kind, NextBestActionKind.returnCheckUnanswered);
      expect(result.titleLine, NextBestActionCopy.returnCheckUnansweredTitle);
      expect(result.helperLine, NextBestActionCopy.returnCheckUnansweredHelper);
    });

    test('return check answered points to Patterns', () {
      final result = NextBestActionEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.softer),
        ],
      );

      expect(result.kind, NextBestActionKind.returnCheckAnswered);
      expect(result.titleLine, NextBestActionCopy.returnCheckAnsweredTitle);
      expect(result.helperLine, NextBestActionCopy.returnCheckAnsweredHelper);
    });

    test('pattern changed says watch whether shift holds', () {
      final entries = [
        ..._threeRelatedRepeatEntries(),
        _entry(
          id: 'e4',
          transcript:
              'I said yes again even though I had no capacity for one more ask today.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ];
      final result = NextBestActionEngine.build(
        entries: entries,
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.changed),
        ],
      );

      expect(result.kind, NextBestActionKind.patternChanged);
      expect(result.titleLine, NextBestActionCopy.patternChangedTitle);
      expect(result.helperLine, NextBestActionCopy.patternChangedHelper);
    });

    test('helpful action says evidence not advice', () {
      final result = NextBestActionEngine.build(
        entries: _fourRelatedRepeatWithHelpfulAction(),
      );

      expect(result.kind, NextBestActionKind.helpfulActionAppeared);
      expect(result.titleLine, NextBestActionCopy.helpfulActionTitle);
      expect(result.helperLine, NextBestActionCopy.helpfulActionHelper);
    });

    test('private report forming shows keep evidence trail going', () {
      final result = NextBestActionEngine.build(
        entries: _threeRelatedRepeatEntries(),
        privateReportForming: true,
      );

      expect(result.kind, NextBestActionKind.privateReportForming);
      expect(result.titleLine, NextBestActionCopy.privateReportFormingTitle);
    });

    test('no transcript phrase or user content in output', () {
      final entries = _fourRelatedRepeatWithHelpfulAction();
      final privateText = entries.last.transcript;
      final result = NextBestActionEngine.build(entries: entries);

      expect(result.titleLine, isNot(contains(privateText)));
      expect(result.helperLine, isNot(contains(privateText)));
      expect(result.titleLine, isNot(contains('said yes again')));
    });

    test('copy avoids advice coaching and therapy language', () {
      NextBestActionCopy.allVisibleStrings.forEach(_expectNoAdviceLanguage);
    });
  });

  group('NextBestActionGates', () {
    test('hides early stage when early repeat progress card is visible', () {
      final action = NextBestActionEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      expect(
        NextBestActionGates.shouldShow(
          action: action,
          surface: NextBestActionSurface.record,
          showEarlyRepeatProgress: true,
          showPostSaveReturnCheckAnswer: false,
          repeatReturnCheckOfferVisible: false,
          showPatternChangedCard: false,
          showHelpfulActionCard: false,
          showPrivateArchiveReportCard: false,
        ),
        isFalse,
      );
    });

    test('hides return check unanswered when answer card is visible', () {
      final action = NextBestActionEngine.build(
        entries: _fourRelatedRepeatEntries(),
      );

      expect(
        NextBestActionGates.shouldShow(
          action: action,
          surface: NextBestActionSurface.record,
          showEarlyRepeatProgress: false,
          showPostSaveReturnCheckAnswer: true,
          repeatReturnCheckOfferVisible: false,
          showPatternChangedCard: false,
          showHelpfulActionCard: false,
          showPrivateArchiveReportCard: false,
        ),
        isFalse,
      );
    });

    test('does not duplicate early repeat progress body copy', () {
      expect(
        NextBestActionCopy.twoRelatedHelper,
        isNot(contains(EarlyRepeatProgressCopy.twoRelatedBody)),
      );
      expect(
        NextBestActionCopy.oneEntryTitle.toLowerCase(),
        isNot(equals(EarlyRepeatProgressCopy.oneMomentBody.toLowerCase())),
      );
    });

    test('hides open Patterns on Patterns surface', () {
      final action = NextBestActionEngine.build(
        entries: _fourRelatedRepeatEntries(),
        returnChecks: [
          _choiceRecord(entryId: 'e4', choice: RepeatReturnCheckChoice.same),
        ],
      );

      expect(
        NextBestActionGates.shouldShow(
          action: action,
          surface: NextBestActionSurface.patterns,
          showEarlyRepeatProgress: false,
          showPostSaveReturnCheckAnswer: false,
          repeatReturnCheckOfferVisible: false,
          showPatternChangedCard: false,
          showHelpfulActionCard: false,
          showPrivateArchiveReportCard: false,
        ),
        isFalse,
      );
    });
  });

  group('NextBestActionLine', () {
    testWidgets('renders title and helper without buttons', (tester) async {
      const action = NextBestActionResult(
        kind: NextBestActionKind.noEntries,
        titleLine: NextBestActionCopy.noEntriesTitle,
        helperLine: NextBestActionCopy.noEntriesHelper,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NextBestActionLine(
              action: action,
              surface: NextBestActionSurface.record,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('next_best_action_line_record_noEntries')),
        findsOneWidget,
      );
      expect(find.text(NextBestActionCopy.noEntriesTitle), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}