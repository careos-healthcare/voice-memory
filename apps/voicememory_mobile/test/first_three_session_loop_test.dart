import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_three_journey_engine.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_copy.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/features/archive_proof/low_effort_capture_copy_guard.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_engine.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_engine.dart';
import 'package:voicememory_mobile/features/activation/third_session_archive_usefulness_engine.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/activation/first_three_session_journey_indicator.dart';
import 'package:voicememory_mobile/widgets/activation/third_session_archive_usefulness_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:voicememory_mobile/widgets/onboarding/pro_archive_continuity_card.dart';
import 'package:voicememory_mobile/widgets/record/second_session_comparison_card.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });


  tearDown(() => sandbox.dispose());
  group('FirstThreeSessionGates', () {
    test(
      'early archive proof stays hidden until grounded repeat at two entries',
      () {
        final entries = [
          _entry('1', 'A quiet moment about lunch with a friend today.'),
          _entry('2', 'Another unrelated note about errands this afternoon.'),
        ];
        expect(
          FirstThreeSessionGates.suppressEarlyPatternClaimCards(
            entryCount: 2,
            hasGroundedRepeatMatch: const SecondSessionSignalEngine()
                .hasGroundedRepeatMatch(entries),
          ),
          isTrue,
        );
      },
    );
  });

  group('FirstThreeSessionCopy', () {
    test('session 1 lines match product loop', () {
      expect(RecordReturnProCopy.evidenceTitle, 'Saved.');
      expect(
        RecordReturnProCopy.evidenceBody,
        VisibleArchiveProofCopy.firstSavePostSaveBody,
      );
      expect(
        RecordReturnProCopy.evidenceSecondLine,
        VisibleArchiveProofCopy.firstSavePostSaveReassurance,
      );
      expect(
        RecordReturnProCopy.evidenceThirdLine,
        contains('Come back when this shows up again'),
      );
    });

    test('journey labels follow session path', () {
      expect(
        FirstThreeSessionCopy.journeyLabelForCount(0),
        'Start your archive',
      );
      expect(
        FirstThreeSessionCopy.journeyLabelForCount(1),
        'Notice what repeats',
      );
      expect(
        FirstThreeSessionCopy.journeyLabelForCount(2),
        'Notice what repeats',
      );
      expect(
        FirstThreeSessionCopy.journeyLabelForCount(3),
        'Watch what changes',
      );
    });

    test('early repeat copy is cautious', () {
      expect(
        FirstThreeSessionCopy.session2StartingToNoticeTitle,
        'ArchiveMe has two moments to compare.',
      );
      expect(
        FirstThreeSessionCopy.session2StartingToNoticeBody,
        contains('No clear repeat yet'),
      );
      expect(
        FirstThreeSessionCopy.session2NextAction,
        contains('thread clearer'),
      );
    });

    test('consumer copy avoids internal billing language', () {
      final haystack = [
        ...FirstThreeSessionCopy.session1Lines,
        ...FirstThreeSessionCopy.session3Lines,
        ...FirstThreeSessionCopy.proLines,
        ConsumerUiCopy.secondSessionPossibleRepeatTitle,
      ].join(' ').toLowerCase();

      for (final banned in FirstThreeSessionCopy.bannedInternalTerms) {
        expect(haystack, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('FirstThreeSessionGates', () {
    test('suppresses noisy cards on first save only', () {
      expect(
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: true,
          entryCount: 1,
        ),
        isTrue,
      );
      expect(
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: true,
          entryCount: 2,
        ),
        isFalse,
      );
    });

    test(
      'suppresses early pattern claims until grounded repeat or third entry',
      () {
        expect(
          FirstThreeSessionGates.suppressEarlyPatternClaimCards(
            entryCount: 2,
            hasGroundedRepeatMatch: false,
          ),
          isTrue,
        );
        expect(
          FirstThreeSessionGates.suppressEarlyPatternClaimCards(
            entryCount: 2,
            hasGroundedRepeatMatch: true,
          ),
          isFalse,
        );
        expect(
          FirstThreeSessionGates.suppressEarlyPatternClaimCards(
            entryCount: 3,
            hasGroundedRepeatMatch: false,
          ),
          isFalse,
        );
      },
    );

    test('Pro bridge waits until repeat value exists', () {
      expect(
        FirstThreeSessionGates.showSoftProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
      expect(
        FirstThreeSessionGates.showSoftProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: false,
        ),
        isFalse,
      );
      expect(
        FirstThreeSessionGates.showSoftProBridge(
          entryCount: 2,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isTrue,
      );
      expect(
        RecordReturnProGates.showProBridge(
          entryCount: 1,
          resolved: false,
          isPro: false,
          hasArchiveProof: true,
        ),
        isFalse,
      );
    });
  });

  group('Session 1 confirmation', () {
    testWidgets('first save evidence card shows focused copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
              onDoneForToday: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Saved.'), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.firstSavePostSaveBody),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.firstSavePostSaveReassurance),
        findsOneWidget,
      );
      expect(find.text('View archive'), findsOneWidget);
      expect(find.text('Record if it happens again'), findsOneWidget);
      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Your pressure loop'), findsNothing);
      expect(find.text('ArchiveMe found a possible repeat'), findsNothing);
    });
  });

  group('Session 2 cautious comparison', () {
    test('ungrounded two-entry save suppresses possible-repeat headline', () {
      final entries = [
        _entry('1', 'A quiet moment about lunch with a friend today.'),
        _entry('2', 'Another unrelated note about errands this afternoon.'),
      ];
      const engine = SecondSessionSignalEngine();
      expect(engine.hasGroundedRepeatMatch(entries), isFalse);
      expect(
        FirstThreeSessionGates.suppressEarlyPatternClaimCards(
          entryCount: 2,
          hasGroundedRepeatMatch: engine.hasGroundedRepeatMatch(entries),
        ),
        isTrue,
      );
      expect(
        engine.build(entries).title,
        ConsumerUiCopy.secondSessionPossibleRepeatTitle,
      );
    });
  });

  group('Session 2 possible repeat', () {
    test('second session engine surfaces possible repeat conservatively', () {
      final comparison = const SecondSessionSignalEngine().build([
        _entry(
          '1',
          'I said yes again even though I was already tired from work today.',
        ),
        _entry(
          '2',
          'I took responsibility again before asking anyone for help today.',
        ),
      ]);

      expect(comparison.hasEnoughData, isTrue);
      expect(comparison.title, 'ArchiveMe found a possible repeat');
      expect(comparison.possibleRepeat, isTrue);
    });

    testWidgets('comparison card shows repeat sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final comparison = const SecondSessionSignalEngine().build([
        _entry(
          '1',
          'I said yes again even though I was already tired from work today.',
        ),
        _entry(
          '2',
          'I took responsibility again before asking anyone for help today.',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecondSessionComparisonCard(
                comparison: comparison,
                onGoDeeper: () {},
                onRecordNextEvidence: () {},
                onNotTheSame: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ArchiveMe found a possible repeat'), findsOneWidget);
      expect(find.text('What repeated'), findsOneWidget);
      expect(find.text('What changed'), findsWidgets);
      expect(find.text('What ArchiveMe is watching next'), findsOneWidget);
    });
  });

  group('Session 3 archive usefulness', () {
    test('engine requires three entries', () {
      final two = const ThirdSessionArchiveUsefulnessEngine().build([
        _entry('1', 'First moment with enough words to count as evidence.'),
        _entry('2', 'Second moment with enough words to count as evidence.'),
      ]);
      expect(two.hasEnoughData, isFalse);

      final three = const ThirdSessionArchiveUsefulnessEngine().build([
        _entry(
          '1',
          'I said yes again even though I was already tired from work today.',
        ),
        _entry(
          '2',
          'I took responsibility again before asking anyone for help today.',
        ),
        _entry(
          '3',
          'I kept going again before checking whether I had room today.',
        ),
      ]);
      expect(three.hasEnoughData, isTrue);
    });

    testWidgets('patterns card shows thread copy', (tester) async {
      final usefulness = const ThirdSessionArchiveUsefulnessEngine().build([
        _entry(
          '1',
          'I said yes again even though I was already tired from work today.',
        ),
        _entry(
          '2',
          'I took responsibility again before asking anyone for help today.',
        ),
        _entry(
          '3',
          'I kept going again before checking whether I had room today.',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThirdSessionArchiveUsefulnessCard(usefulness: usefulness),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ArchiveMe found a possible repeat'), findsOneWidget);
      expect(find.text("Here's what keeps coming back."), findsOneWidget);
      expect(find.text("Here's what changed since last time."), findsOneWidget);
    });
  });

  group('Journey indicator', () {
    testWidgets('highlights the active step label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FirstThreeSessionJourneyIndicator(activeStepIndex: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Start your archive'), findsOneWidget);
      expect(find.text('Notice what repeats'), findsOneWidget);
      expect(find.text('Watch what changes'), findsOneWidget);
    });
  });

  group('Pro boundary', () {
    testWidgets('soft Pro card uses continuity copy after value', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProArchiveContinuityCard(
              entryCount: 2,
              source: 'archive',
              onSeePro: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'Free shows the first useful proof. Pro keeps the longer trail.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Free shows the first useful proof. Pro keeps older evidence and longer archive history.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Free keeps recent proof. Pro keeps the longer proof trail over time.',
        ),
        findsOneWidget,
      );
      expect(find.text('Upgrade required'), findsNothing);
      expect(find.text('RevenueCat'), findsNothing);
    });
  });

  group('FirstThreeJourneyEngine alignment', () {
    const engine = FirstThreeJourneyEngine();

    test('zero entries uses Start your archive title', () {
      final model = engine.build(reflectionCount: 0);
      expect(model.title, FirstThreeSessionCopy.session0Title);
      expect(model.journeyStepIndex, 0);
    });

    test('one entry does not claim a confirmed loop', () {
      final model = engine.build(reflectionCount: 1);
      expect(model.title, FirstThreeSessionCopy.session1CardTitle);
      expect(model.nextAction, FirstThreeSessionCopy.session1NextAction);
      expect(model.title.toLowerCase(), isNot(contains('pattern is')));
      expect(model.progressLabel, FirstThreeSessionCopy.journeyStep2);
      expect(model.journeyStepIndex, 1);
    });

    test(
      'two entries shows comparison payoff, not possible repeat headline',
      () {
        final model = engine.build(reflectionCount: 2);
        expect(model.title, 'ArchiveMe has two moments to compare.');
        expect(model.title, isNot(FirstThreeSessionCopy.session2RepeatTitle));
        expect(model.journeyStepIndex, 1);
        expect(model.progressLabel, FirstThreeSessionCopy.journeyStep2);
      },
    );

    test('three entries uses useful-archive title without invented repeat', () {
      final model = engine.build(
        reflectionCount: 3,
        entries: [
          _entry('a', 'A quiet moment about lunch with a friend today.'),
          _entry('b', 'Another unrelated note about errands this afternoon.'),
          _entry('c', 'A third unrelated note about reading before bed.'),
        ],
      );
      expect(model.title, FirstThreeSessionCopy.session3Title);
      expect(model.completed, isTrue);
      expect(model.journeyStepIndex, 2);
    });
  });

  group('First-three retention loop copy', () {
    test('entry 0 primary capture CTA is Save one moment', () {
      expect(VisibleArchiveProofCopy.firstUseCaptureCta, 'Record moment');
      expect(RecordReturnProCopy.recordOnceCta, 'Record one moment');
    });

    test('one entry ready explains second moment without pattern claim', () {
      final model = EarlyFirstSignalEngine.build(
        entries: [
          _entry('1', 'I felt pressure before saying yes again today.'),
        ],
      );
      expect(model!.kind, EarlyFirstSignalKind.oneEntryReceipt);
      expect(model.title, EarlyFirstSignalCopy.oneEntryTitle);
      expect(model.lines.single, EarlyFirstSignalCopy.oneEntryBody);
      expect(
        FirstThreeSessionGates.showEarlyFirstSignalCardPrimaryCta(model.kind),
        isFalse,
      );
    });

    test('two related entries use confirm-the-repeat copy and CTA', () {
      final entries = [
        _entry(
          '1',
          'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
        ),
      ];
      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.twoEntryFirstSignal);
      expect(model.title, EarlyFirstSignalCopy.twoEntryRelatedTitle);
      expect(model.lines.single, EarlyFirstSignalCopy.twoEntryRelatedBody);
      expect(model.primaryCta, EarlyFirstSignalCopy.confirmRepeatCta);
    });

    test('two unrelated entries do not claim a repeat', () {
      final entries = [
        _entry('1', 'A quiet moment about lunch with a friend today.'),
        _entry('2', 'Another unrelated note about errands this afternoon.'),
      ];
      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.twoEntryNoPattern);
      expect(
        '${model.title} ${model.lines.single}'.toLowerCase(),
        isNot(contains('confirmed repeat')),
      );
      expect(
        FirstThreeSessionGates.showEarlyFirstSignalCardPrimaryCta(model.kind),
        isFalse,
      );
    });

    test('three related entries show confirmed repeat payoff', () {
      final entries = [
        _entry(
          '1',
          'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
        ),
      ];
      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.threeEntryConfirmedRepeat);
      expect(model.title, EarlyFirstSignalCopy.threeEntryConfirmedTitle);
      expect(
        model.lines,
        contains(EarlyFirstSignalCopy.threeEntrySeenThreeTimes),
      );
      expect(EarlyRepeatProgressEngine.build(entries: entries), isNull);
    });

    test('early repeat progress copy tracks first-three loop', () {
      final one = EarlyRepeatProgressEngine.build(
        entries: [
          _entry('1', 'I felt pressure before saying yes again today.'),
        ],
      );
      expect(one!.progressLabel, isEmpty);

      final related = EarlyRepeatProgressEngine.build(
        entries: [
          _entry(
            '1',
            'I had no capacity but I said yes again to the extra meeting today.',
          ),
          _entry(
            '2',
            'Same thing — said yes when I had no capacity for one more thing.',
          ),
        ],
      );
      expect(
        related!.progressLabel,
        EarlyRepeatProgressCopy.twoRelatedProgress,
      );
      expect(related.claimsRepeatForming, isTrue);

      final unrelated = EarlyRepeatProgressEngine.build(
        entries: [
          _entry('1', 'A quiet moment about lunch with a friend today.'),
          _entry('2', 'Another unrelated note about errands this afternoon.'),
        ],
      );
      expect(unrelated!.claimsRepeatForming, isFalse);
      expect(unrelated.progressLabel, isNot(contains('first repeat proof')));
    });

    test(
      'post-save handoff mirrors first-three loop without progress card copy',
      () {
        final entries = [
          _entry(
            '1',
            'I had no capacity but I said yes again to the extra meeting today.',
          ),
          _entry(
            '2',
            'Same thing — said yes when I had no capacity for one more thing.',
          ),
        ];
        final handoff = PostSaveReturnHandoffEngine.build(entries: entries);
        final progress = EarlyRepeatProgressEngine.build(entries: entries);

        expect(
          handoff!.title,
          PostSaveReturnHandoffCopy.afterSecondSaveRelatedTitle,
        );
        expect(progress!.title, EarlyRepeatProgressCopy.twoRelatedTitle);
        expect(handoff.body, isNot(equals(progress.body)));
      },
    );

    test('first proof moment is the third-save emotional payoff', () {
      final entries = [
        _entry(
          '1',
          'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
        ),
      ];
      final moment = FirstProofMomentEngine.build(entries: entries);
      expect(moment!.primaryLabel, FirstProofMomentCopy.primaryLabel);
      expect(moment.title, FirstProofMomentCopy.title);
      expect(moment.body, FirstProofMomentCopy.bodyStrong);
      expect(moment.nextLine, FirstProofMomentCopy.nextLine);
      expect(
        EarlyRepeatProgressEngine.build(entries: entries.sublist(0, 2)),
        isNotNull,
      );
      expect(
        PostSaveReturnHandoffEngine.build(entries: entries.sublist(0, 2)),
        isNotNull,
      );
    });

    test('ipad smoke three related moments unlock first proof', () {
      final entries = [
        _entry(
          '1',
          'I said yes to helping with work even though I was already tired.',
        ),
        _entry('2', 'I agreed again before checking if I had enough time.'),
        _entry(
          '3',
          'I noticed I wanted to avoid disappointing them, so I said yes quickly.',
        ),
      ];
      final moment = FirstProofMomentEngine.build(entries: entries);
      expect(moment, isNotNull);
      expect(moment!.title, FirstProofMomentCopy.title);
      expect(moment.evidencePhrases, isNotEmpty);
      expect(
        moment.evidencePhrases.any((p) => p.toLowerCase().contains('said yes')),
        isTrue,
      );
    });

    test('first week loop follows first proof on ready state', () {
      final entries = [
        _entry(
          '1',
          'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
        ),
      ];
      final loop = FirstWeekLoopEngine.build(
        entries: entries,
        returnChecks: const [],
      );
      expect(loop!.title, FirstWeekLoopCopy.title);
      expect(loop.body, isNot(equals(FirstProofMomentCopy.title)));
    });

    test('daily map prompt suppressed during first-three loop', () {
      expect(FirstThreeSessionGates.suppressDailyMapPromptOnRecord(1), isTrue);
      expect(FirstThreeSessionGates.suppressDailyMapPromptOnRecord(3), isTrue);
      expect(FirstThreeSessionGates.suppressDailyMapPromptOnRecord(4), isFalse);
    });

    test('first proof copy uses evidence trail language not chat memory', () {
      final haystack = [
        FirstProofMomentCopy.primaryLabel,
        FirstProofMomentCopy.title,
        FirstProofMomentCopy.whyLine,
        FirstProofMomentCopy.evidenceLabel,
        FirstProofMomentCopy.nextLine,
      ].join(' ').toLowerCase();
      expect(haystack, contains('repeat'));
      expect(haystack, contains('evidence'));
      expect(haystack, contains('your words'));
      expect(haystack, isNot(contains('chat memory')));
      expect(haystack, isNot(contains('ai remembers you')));
      expect(haystack, isNot(contains('you should')));
      expect(haystack, isNot(contains('try this')));
    });

    test('confirmed repeat line uses evidence across moments wording', () {
      expect(
        EarlyFirstSignalCopy.threeEntrySeenThreeTimes.toLowerCase(),
        contains('your words'),
      );
      expect(
        EarlyFirstSignalCopy.threeEntrySeenThreeTimes.toLowerCase(),
        isNot(contains('chat history')),
      );
    });

    test('early loop copy stays low-effort not chatbot prompting', () {
      final joined = [
        PostSaveReturnHandoffCopy.afterFirstSaveBodyFallback,
        PostSaveReturnHandoffCopy.afterFirstSaveFooter,
        EarlyRepeatProgressCopy.oneMomentBody,
        FirstWeekLoopCopy.bodyFallback,
      ].join(' ').toLowerCase();

      expect(joined, anyOf(contains('short'), contains('ten seconds')));
      expect(joined, contains('compare'));
      expect(joined, isNot(contains('ask ai')));
      expect(joined, isNot(contains('journal every day')));

      for (final line in [
        PostSaveReturnHandoffCopy.afterFirstSaveBodyFallback,
        EarlyRepeatProgressCopy.oneMomentBody,
        FirstWeekLoopCopy.bodyFallback,
      ]) {
        expect(LowEffortCaptureCopyGuard.passes(line), isTrue, reason: line);
      }
    });

    test('record capture CTA stays capture-first', () {
      expect(VisibleArchiveProofCopy.firstUseCaptureCta, 'Record moment');
    });
  });
}
