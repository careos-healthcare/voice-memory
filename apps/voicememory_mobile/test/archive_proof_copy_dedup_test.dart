import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_why_matters_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/low_effort_capture_copy_guard.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/helpful_action_appeared_copy.dart';
import 'package:voicememory_mobile/features/early_archive/positive_reinforcement_copy.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/early_evidence_timeline_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_copy.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_engine.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_engine.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_engine.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_copy.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_engine.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/features/pressure_retention/archive_proof_counter_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/archive_proof_counter_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/done_for_today_receipt_engine.dart';
import 'package:voicememory_mobile/features/post_save/post_save_completion_copy_gates.dart';
import 'package:voicememory_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/archive_proof_counter_card.dart';
import 'package:voicememory_mobile/widgets/record/done_for_today_receipt_card.dart';
import 'package:voicememory_mobile/widgets/record/first_proof_payoff_card.dart';
import 'package:voicememory_mobile/widgets/record/post_save_recorded_summary_card.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
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

List<JournalEntry> _fourRelatedEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

RepeatReturnCheckRecord _strongerRecord() => RepeatReturnCheckRecord(
      entryId: 'e4',
      choice: RepeatReturnCheckChoice.stronger,
      entryCountAtCapture: 4,
      createdAt: DateTime(2026, 6, 13),
    );

void main() {
  group('ArchiveProofSurfaceCopy dedup', () {
    test('confirmed repeat card alone keeps key phrases once', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );

      expect(
        ArchiveProofCopyDedup.phrasesWithinLimit(
          copyBlocks: blocks,
          onceOnlyPhrases: [
            EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
            EarlyFirstSignalCopy.evidenceHeading,
          ],
        ),
        isTrue,
      );
    });

    test('record stack with timeline and change proof dedupes repeat phrasing', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fourRelatedEntries(),
      );
      final changeProof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [_strongerRecord()],
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: true,
        changeProofVisible: true,
        proBridgeVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.recordReadyStack(
        layout: layout,
        timeline: timeline,
        changeProof: changeProof,
      );

      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
        ),
        0,
      );
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.evidenceHeading,
        ),
        1,
      );
      expect(blocks, contains(RepeatReturnCheckCopy.changeProofTitle));
      expect(blocks, contains(RepeatReturnCheckCopy.trendGettingLouder));
      expect(blocks, isNot(contains(RepeatReturnCheckCopy.changeProofSupportLine)));
      expect(blocks, contains(ArchiveBeliefThreadCopy.fullArchiveHistoryTitle));
      expect(blocks, contains(ArchiveBeliefThreadCopy.fullArchiveHistoryBody));
    });

    test('patterns stack with confirmed repeat hides timeline evidence heading', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
      );

      expect(
        ArchiveProofCopyDedup.phrasesWithinLimit(
          copyBlocks: ArchiveProofSurfaceCopy.patternsStack(
            layout: layout,
            confirmedRepeat: confirmed,
          ),
          onceOnlyPhrases: [EarlyFirstSignalCopy.evidenceHeading],
        ),
        isTrue,
      );
    });
    test('why matters copy stays distinct from proof phrases', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        whyMattersVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );

      expect(blocks, contains(ConfirmedRepeatWhyMattersCopy.title));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
        ),
        1,
      );
      expect(
        blocks.where((block) => block == ConfirmedRepeatWhyMattersCopy.title),
        hasLength(1),
      );
    });

    test('thought map copy stays distinct from proof phrases', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        whyMattersVisible: false,
        thoughtMapVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );

      expect(blocks, contains(ConfirmedRepeatThoughtMapCopy.title));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
        ),
        1,
      );
      expect(
        blocks.where((block) => block == ConfirmedRepeatThoughtMapCopy.title),
        hasLength(1),
      );
    });

    test('positive pattern copy stays distinct from confirmed repeat proof', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        positivePatternVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );

      expect(blocks, contains(PositivePatternCopy.title));
      expect(blocks, contains(PositivePatternCopy.body));
      expect(
        blocks.where((block) => block == PositivePatternCopy.title),
        hasLength(1),
      );
    });

    test('early repeat progress cue does not duplicate progress card copy', () {
      final progress = EarlyRepeatProgressEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
          _entry(
            id: 'e2',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
          ),
        ],
      );
      expect(progress, isNotNull);

      expect(progress!.nextMomentCue.body, isNot(equals(progress.title)));
      expect(progress.nextMomentCue.body, isNot(equals(progress.progressLabel)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          [
            progress.title,
            progress.body,
            progress.progressLabel,
            progress.nextMomentCue.label,
            progress.nextMomentCue.body,
            progress.nextMomentCue.footer,
          ].join('\n'),
          EarlyRepeatProgressCopy.twoRelatedTitle,
        ),
        1,
      );
      expect(
        ArchiveProofCopyDedup.countPhrase(
          [
            progress.title,
            progress.body,
            progress.progressLabel,
            progress.nextMomentCue.label,
            progress.nextMomentCue.body,
            progress.nextMomentCue.footer,
          ].join('\n'),
          EarlyRepeatProgressCopy.twoRelatedProgress,
        ),
        1,
      );
    });

    test('post-save handoff stays distinct from ready progress card copy', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'e2',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
      ];
      final handoff = PostSaveReturnHandoffEngine.build(entries: entries);
      final progress = EarlyRepeatProgressEngine.build(entries: entries);
      expect(handoff, isNotNull);
      expect(progress, isNotNull);

      expect(handoff!.title, isNot(equals(progress!.title)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          [
            handoff.title,
            handoff.body,
            handoff.footer,
            progress.title,
            progress.body,
            progress.progressLabel,
          ].join('\n'),
          PostSaveReturnHandoffCopy.afterSecondSaveRelatedTitle,
        ),
        1,
      );
      expect(
        ArchiveProofCopyDedup.countPhrase(
          [
            handoff.title,
            handoff.body,
            handoff.footer,
            progress.title,
            progress.body,
            progress.progressLabel,
          ].join('\n'),
          EarlyRepeatProgressCopy.twoRelatedTitle,
        ),
        1,
      );
    });

    test('first proof payoff stays distinct from archive summary copy', () {
      final entries = _threeRelatedRepeatEntries();
      final payoff = FirstProofPayoffEngine.build(entries: entries);
      expect(payoff, isNotNull);

      final blocks = [
        payoff!.headline,
        payoff.subhead,
        payoff.groundedPhrase,
        payoff.meaningLine,
        payoff.returnHook,
      ];
      expect(blocks, isNot(contains(ArchiveSummaryCopy.title)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          FirstProofPayoffCopy.headline,
        ),
        1,
      );
    });

    test('first week loop stays distinct from archive summary copy', () {
      final loop = FirstWeekLoopEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(loop, isNotNull);

      final blocks = [loop!.title, loop.body, loop.footer, loop.label];
      expect(blocks, isNot(contains(ArchiveSummaryCopy.title)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          FirstWeekLoopCopy.title,
        ),
        1,
      );
    });

    test('return check payoff stays distinct from archive summary copy', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _threeRelatedRepeatEntries()
          ..add(
            _entry(
              id: 'e4',
              transcript:
                  'I said yes again even though I had no capacity for one more ask today.',
              createdAt: DateTime(2026, 6, 13, 12),
            ),
          ),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13, 12),
          ),
        ],
      );
      expect(payoff, isNotNull);

      final blocks = [
        payoff!.title,
        payoff.body,
        payoff.footer,
        payoff.evidenceLabel,
      ];
      expect(blocks, isNot(contains(ArchiveSummaryCopy.title)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          ReturnCheckPayoffCopy.softerTitle,
        ),
        1,
      );
    });

    test('post save return check answer stays distinct from archive summary copy', () {
      final answer = PostSaveReturnCheckAnswerEngine.build(
        entries: _threeRelatedRepeatEntries()
          ..add(
            _entry(
              id: 'e4',
              transcript:
                  'I said yes again even though I had no capacity for one more ask today.',
              createdAt: DateTime(2026, 6, 13, 12),
            ),
          ),
        returnChecks: const [],
      );
      expect(answer, isNotNull);

      final blocks = [answer!.label, answer.title, answer.body, answer.footer];
      expect(blocks, isNot(contains(ArchiveSummaryCopy.title)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          PostSaveReturnCheckAnswerCopy.title,
        ),
        1,
      );
    });

    test('tester mission compact copy stays distinct from first-use prompt', () {
      final mission = TesterMissionEngine.build(
        entryCount: 0,
        entries: const [],
        compactAtEntryZero: true,
      );
      expect(mission.presentation.name, 'compact');
      expect(mission.body, isNot(equals(RecordFirstUsePromptCopy.body)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          [
            mission.title,
            mission.stepLabel,
            mission.body,
            mission.footer,
            RecordFirstUsePromptCopy.title,
            RecordFirstUsePromptCopy.body,
            RecordFirstUsePromptCopy.footer,
          ].join('\n'),
          TesterMissionCopy.title,
        ),
        1,
      );
    });

    test('tester mission step two shares low-effort guidance with early repeat progress', () {
      final mission = TesterMissionEngine.build(
        entryCount: 1,
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'A long enough transcript to count as a saved reflection for tests.',
          ),
        ],
        compactAtEntryZero: false,
      );
      final progress = EarlyRepeatProgressEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'A long enough transcript to count as a saved reflection for tests.',
          ),
        ],
      );
      expect(progress, isNotNull);
      expect(mission.body, TesterMissionCopy.entry1Body);
      expect(progress!.body, contains('Come back when something similar happens'));
      expect(mission.title, isNot(equals(progress.title)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          [
            mission.title,
            mission.body,
            mission.footer,
            progress.title,
            progress.body,
            progress.progressLabel,
          ].join('\n'),
          EarlyRepeatProgressCopy.oneMomentTitle,
        ),
        1,
      );
    });
  });

  group('Pattern memory differentiation', () {
    test('first proof payoff uses user-word evidence wording', () {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(payoff, isNotNull);
      final haystack = [
        payoff!.headline,
        payoff.evidenceLabel,
        payoff.meaningLine,
        payoff.returnHook,
      ].join(' ').toLowerCase();
      expect(haystack, contains('your words'));
      expect(haystack, contains('pattern'));
      expect(haystack, isNot(contains('chat memory')));
      expect(haystack, isNot(contains('ai remembers you')));
      expect(haystack, isNot(contains('i know you')));
    });

    test('archive summary differentiates from chat-memory framing', () {
      final joined = [
        ArchiveSummaryCopy.title,
        ArchiveSummaryCopy.promise,
        ArchiveSummaryCopy.keepsRepeatingLabel,
      ].join(' ').toLowerCase();
      expect(joined, contains('evidence'));
      expect(joined, contains('repeat'));
      expect(ArchiveSummaryCopy.promise, contains('not conversation history'));
      expect(joined, isNot(contains('chat memory')));
      expect(joined, isNot(contains('ai remembers you')));
    });

    test('key surfaces avoid chatbot memory language', () {
      final surfaces = [
        RecordScreenFramingCopy.emptyArchiveBody,
        RecordScreenFramingCopy.weakCompareFootnote,
        FirstProofPayoffCopy.headline,
        FirstProofPayoffCopy.patternLine,
        FirstProofPayoffCopy.truthLine,
        ArchiveSummaryCopy.promise,
      ].join('\n').toLowerCase();

      expect(surfaces, isNot(contains('chat memory')));
      expect(surfaces, isNot(contains('ai remembers you')));
      expect(surfaces, isNot(contains('i know you')));
    });
  });

  group('Longitudinal change differentiation', () {
    test('pro bridge explains longer proof trail and change tracking', () {
      final joined = [
        ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
        ArchiveBeliefThreadCopy.whyPro,
        ArchiveBeliefThreadCopy.proBridgeBody,
        ...ArchiveBeliefThreadCopy.fullArchiveHistoryBullets,
      ].join(' ').toLowerCase();

      expect(joined, contains('longer proof trail'));
      expect(joined, contains('changes'));
      expect(joined, contains('over time'));
      expect(joined, contains('evidence'));
    });

    test('post-save answer and payoff do not duplicate intensity labels', () {
      final payoff = ReturnCheckPayoffEngine.build(
        entries: _fourRelatedEntries(),
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.stronger,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 13),
          ),
        ],
      );
      expect(payoff, isNotNull);

      final answerBlock = [
        PostSaveReturnCheckAnswerCopy.title,
        PostSaveReturnCheckAnswerCopy.bodyFallback,
      ].join('\n');
      final payoffBlock = [
        payoff!.title,
        payoff.body,
        payoff.footer,
      ].join('\n');

      expect(
        ArchiveProofCopyDedup.countPhrase(
          '$answerBlock\n$payoffBlock'.toLowerCase(),
          'stronger',
        ),
        lessThanOrEqualTo(3),
      );
      expect(
        ArchiveProofCopyDedup.phrasesWithinLimit(
          copyBlocks: [answerBlock, payoffBlock],
          onceOnlyPhrases: [ReturnCheckPayoffCopy.strongerTitle],
        ),
        isTrue,
      );
    });
  });

  group('Evidence not advice', () {
    test('main proof surfaces avoid banned coaching phrases', () {
      for (final line in ProofSurfaceAdviceGuard.mainProofSurfaceCopyBlocks()) {
        for (final violation in ProofSurfaceAdviceGuard.violationsIn(line)) {
          fail('"$line" contains banned advice phrase "$violation"');
        }
      }
    });

    test('helpful action copy is evidence-based not prescriptive', () {
      final phraseBody =
          HelpfulActionAppearedCopy.bodyWithPhrase('walked outside');
      final joined = [
        HelpfulActionAppearedCopy.title,
        phraseBody,
        HelpfulActionAppearedCopy.footer,
        HelpfulActionAppearedCopy.evidenceLabel,
        PositiveReinforcementCopy.title,
        PositiveReinforcementCopy.body,
        ArchiveSummaryCopy.whatHelpsWithPhrase('walked outside'),
      ].join(' ').toLowerCase();

      expect(joined, contains('a helpful action appeared'));
      expect(joined, contains('evidence, not advice'));
      expect(joined, contains('this is not a suggestion'));
      expect(joined, contains('watching'));
      expect(joined, isNot(contains('try repeating')));
      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('do this again')));
    });
  });

  group('Post-save completion copy dedup', () {
    const doneEngine = DoneForTodayReceiptEngine();
    const counterEngine = ArchiveProofCounterEngine();

    Future<void> pumpCompletionStack(
      WidgetTester tester, {
      required int entryCount,
      required bool showFirstProofPayoff,
      bool justSavedFirst = false,
    }) async {
      final doneReceipt = doneEngine.build(
        saved: true,
        entryCount: entryCount,
      );
      final receipt = showFirstProofPayoff
          ? doneReceipt.copyWith(archiveLine: '')
          : doneReceipt;
      final counter = counterEngine.build(const [], savedToday: true);
      final suppressNoisy = FirstThreeSessionGates.suppressNoisyPostSaveCards(
        justSavedFirst: justSavedFirst,
        entryCount: entryCount,
      );
      final showDone = receipt.hasReceipt && !suppressNoisy;
      final showCounter = PostSaveCompletionCopyGates.showArchiveProofCounter(
        counterHasProof: counter.hasProof,
        doneReceiptVisible: showDone,
        suppressNoisyFirstSaveCards: suppressNoisy,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  if (showFirstProofPayoff)
                    FirstProofPayoffCard(
                      payoff: FirstProofPayoffEngine.build(
                        entries: _threeRelatedRepeatEntries(),
                      )!,
                      entryCount: 3,
                      onWatchThisNext: () {},
                    ),
                  if (showDone) DoneForTodayReceiptCard(receipt: receipt),
                  if (showCounter) ArchiveProofCounterCard(counter: counter),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    test('gate hides proof counter when done receipt is visible', () {
      expect(
        PostSaveCompletionCopyGates.showArchiveProofCounter(
          counterHasProof: true,
          doneReceiptVisible: true,
          suppressNoisyFirstSaveCards: false,
        ),
        isFalse,
      );
      expect(
        PostSaveCompletionCopyGates.showArchiveProofCounter(
          counterHasProof: true,
          doneReceiptVisible: false,
          suppressNoisyFirstSaveCards: false,
        ),
        isTrue,
      );
    });

    testWidgets('first save post-save has no duplicate completion copy', (
      tester,
    ) async {
      await pumpCompletionStack(
        tester,
        entryCount: 1,
        showFirstProofPayoff: false,
        justSavedFirst: true,
      );

      expect(find.byKey(const Key('done_for_today_receipt_card')), findsNothing);
      expect(find.byKey(const Key('archive_proof_counter_card')), findsNothing);
      expect(
        find.text(VisibleArchiveProofCopy.oneEntryAddedTodayLine),
        findsNothing,
      );
      expect(
        find.text(ArchiveProofCounter.onePieceTodayLine),
        findsNothing,
      );
    });

    testWidgets('third save first-proof post-save has no duplicate completion copy', (
      tester,
    ) async {
      await pumpCompletionStack(
        tester,
        entryCount: 3,
        showFirstProofPayoff: true,
      );

      expect(find.byKey(const Key('first_proof_payoff_card')), findsOneWidget);
      expect(find.byKey(const Key('done_for_today_receipt_card')), findsOneWidget);
      expect(find.text('That is enough for today.'), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.oneEntryAddedTodayLine),
        findsNothing,
      );
      expect(
        find.text(ArchiveProofCounter.onePieceTodayLine),
        findsNothing,
      );
      expect(find.byKey(const Key('archive_proof_counter_card')), findsNothing);
    });

    testWidgets('fourth related post-save has no duplicate completion copy', (
      tester,
    ) async {
      await pumpCompletionStack(
        tester,
        entryCount: 4,
        showFirstProofPayoff: false,
      );

      expect(find.byKey(const Key('done_for_today_receipt_card')), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.oneEntryAddedTodayLine),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveProofCounter.onePieceTodayLine),
        findsNothing,
      );
      expect(find.byKey(const Key('archive_proof_counter_card')), findsNothing);
    });

    testWidgets('fourth changed entry still shows What changed in summary', (
      tester,
    ) async {
      final entries = [
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
        ),
        _entry(
          id: 'c',
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
        ),
        _entry(
          id: 'd',
          transcript:
              'I paused before saying yes when they asked me to take on more work.',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PostSaveRecordedSummaryCard(
              entry: entries.last,
              allEntries: entries,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(PostSaveRecordedSummaryCopy.whatChangedTitle),
        findsOneWidget,
      );
    });

    test('first proof still appears after three related entries', () {
      expect(
        FirstProofPayoffEngine.build(entries: _threeRelatedRepeatEntries()),
        isNotNull,
      );
    });
  });

  group('Low-effort capture', () {
    test('main capture surfaces avoid chatbot and journaling friction', () {
      for (final line in LowEffortCaptureCopyGuard.mainCaptureCopyBlocks()) {
        for (final violation in LowEffortCaptureCopyGuard.violationsIn(line)) {
          fail('"$line" contains banned friction phrase "$violation"');
        }
      }
    });

    test('first-use prompt says no need to explain and ten seconds is enough', () {
      expect(
        RecordFirstUsePromptCopy.body.toLowerCase(),
        contains('no need to explain everything'),
      );
      expect(
        RecordFirstUsePromptCopy.footer,
        contains('Ten seconds is enough'),
      );
    });
  });
}
