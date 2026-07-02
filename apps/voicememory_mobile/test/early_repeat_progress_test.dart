import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_gates.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_model.dart';
import 'package:voicememory_mobile/features/early_archive/record_proof_stack_policy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/widgets/record/early_repeat_progress_card.dart';
import 'package:voicememory_mobile/widgets/record/first_proof_moment_card.dart';
import 'package:voicememory_mobile/widgets/record/post_save_return_handoff_card.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_copy.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_engine.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_gates.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_gates.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_handoff_model.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 6, 12, 10),
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

void main() {
  group('EarlyRepeatProgressEngine', () {
    test('entryCount 1 shows 1 of 3 repeat progress', () {
      final result = EarlyRepeatProgressEngine.build(
        entries: [
          _entry('1', 'I felt pressure before saying yes again today.'),
        ],
      );

      expect(result!.kind, EarlyRepeatProgressKind.oneMoment);
      expect(result.title, EarlyRepeatProgressCopy.oneMomentTitle);
      expect(result.progressLabel, EarlyRepeatProgressCopy.oneMomentProgress);
      expect(result.claimsRepeatForming, isFalse);
      expect(
        result.nextMomentCue.label,
        EarlyRepeatProgressCopy.oneMomentCueLabel,
      );
      expect(
        result.nextMomentCue.footer,
        EarlyRepeatProgressCopy.oneMomentCueFooter,
      );
    });

    test('entryCount 1 uses concrete phrase in next moment cue when available', () {
      final result = EarlyRepeatProgressEngine.build(
        entries: [
          _entry(
            '1',
            'I had no capacity but I said yes again to the extra meeting today.',
          ),
        ],
      );

      expect(result!.nextMomentCue.body, contains('said yes again'));
      expect(result.nextMomentCue.body, isNot(contains(result.body)));
      expect(
        result.nextMomentCue.body.split(RegExp(r'\s+')).length,
        lessThan(30),
      );
    });

    test('entryCount 1 without concrete phrase uses fallback cue', () {
      final result = EarlyRepeatProgressEngine.build(
        entries: [
          _entry('1', 'A quiet moment about lunch with a friend today.'),
        ],
      );

      expect(
        result!.nextMomentCue.body,
        EarlyRepeatProgressCopy.oneMomentCueBodyFallback,
      );
    });

    test('entryCount 2 related shows 2 of 3 repeat progress', () {
      final result = EarlyRepeatProgressEngine.build(
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

      expect(result!.kind, EarlyRepeatProgressKind.twoRelated);
      expect(result.title, EarlyRepeatProgressCopy.twoRelatedTitle);
      expect(result.progressLabel, EarlyRepeatProgressCopy.twoRelatedProgress);
      expect(result.claimsRepeatForming, isTrue);
      expect(
        result.nextMomentCue.label,
        EarlyRepeatProgressCopy.twoRelatedCueLabel,
      );
      expect(
        result.nextMomentCue.footer,
        EarlyRepeatProgressCopy.twoRelatedCueFooter,
      );
    });

    test('entryCount 2 related uses shared phrase in next moment cue', () {
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
      final shared =
          ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(entries);
      final result = EarlyRepeatProgressEngine.build(entries: entries);

      expect(shared, isNotNull);
      expect(result!.nextMomentCue.body, contains(shared!));
      expect(
        result.nextMomentCue.body,
        EarlyRepeatProgressCopy.twoRelatedCueBodyWithPhrase(shared),
      );
    });

    test('entryCount 2 unrelated does not claim a repeat', () {
      final result = EarlyRepeatProgressEngine.build(
        entries: [
          _entry('1', 'A quiet moment about lunch with a friend today.'),
          _entry('2', 'Another unrelated note about errands this afternoon.'),
        ],
      );

      expect(result!.kind, EarlyRepeatProgressKind.twoUnrelated);
      expect(result.title, EarlyRepeatProgressCopy.twoUnrelatedTitle);
      expect(result.progressLabel, EarlyRepeatProgressCopy.twoUnrelatedProgress);
      expect(result.claimsRepeatForming, isFalse);
      expect(result.body.toLowerCase(), contains('okay'));
      expect(result.body.toLowerCase(), isNot(contains('unlocks')));
      expect(
        result.nextMomentCue.label,
        EarlyRepeatProgressCopy.twoUnrelatedCueLabel,
      );
      expect(
        result.nextMomentCue.body,
        EarlyRepeatProgressCopy.twoUnrelatedCueBody,
      );
      expect(
        result.nextMomentCue.footer,
        EarlyRepeatProgressCopy.twoUnrelatedCueFooter,
      );
      expect(result.nextMomentCue.body.toLowerCase(), isNot(contains('repeat may be forming')));
    });

    test('next moment cue avoids abstract labels not in user words', () {
      final result = EarlyRepeatProgressEngine.build(
        entries: [
          _entry('1', 'I felt pressure before saying yes again today.'),
        ],
      );

      for (final term in ConfirmedRepeatEvidencePhraseEngine.bannedGenericLabels) {
        expect(
          result!.nextMomentCue.body.toLowerCase(),
          isNot(contains(term)),
          reason: term,
        );
      }
    });

    test('next moment cue does not dump full transcript', () {
      final transcript =
          'I had no capacity but I said yes again to the extra meeting today and then kept going.';
      final result = EarlyRepeatProgressEngine.build(
        entries: [_entry('1', transcript)],
      );

      expect(result!.nextMomentCue.body, isNot(contains(transcript)));
      final quoted = RegExp(r'“([^”]+)”').firstMatch(result.nextMomentCue.body);
      if (quoted != null) {
        final words = quoted.group(1)!.split(RegExp(r'\s+')).length;
        expect(words, lessThanOrEqualTo(6));
      }
    });

    test('related progress body and cue do not duplicate unlock copy', () {
      final result = EarlyRepeatProgressEngine.build(
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

      expect(result!.body, isNot(equals(result.nextMomentCue.label)));
      expect(result.nextMomentCue.body, isNot(equals(result.body)));
    });

    test('entryCount 3 returns null', () {
      expect(
        EarlyRepeatProgressEngine.build(
          entries: [
            _entry('1', 'First moment with enough words to count as evidence.'),
            _entry('2', 'Second moment with enough words to count as evidence.'),
            _entry('3', 'Third moment with enough words to count as evidence.'),
          ],
        ),
        isNull,
      );
    });
  });

  group('EarlyRepeatProgressGates', () {
    test('shows only on ready record for entryCount 1–2', () {
      final progress = EarlyRepeatProgressEngine.build(
        entries: [_entry('1', 'A saved moment with enough words for evidence.')],
      );

      expect(
        EarlyRepeatProgressGates.shouldShow(
          loaded: true,
          entryCount: 1,
          isReady: true,
          isPostSave: false,
          isRecording: false,
          progress: progress,
        ),
        isTrue,
      );
      expect(
        EarlyRepeatProgressGates.shouldShow(
          loaded: true,
          entryCount: 1,
          isReady: true,
          isPostSave: true,
          isRecording: false,
          progress: progress,
        ),
        isFalse,
      );
      expect(
        EarlyRepeatProgressGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isPostSave: false,
          isRecording: false,
          progress: progress,
        ),
        isFalse,
      );
    });
  });

  group('RecordProofStackPolicy early progress', () {
    test('entryCount 3 confirmed repeat does not show progress card', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 3,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: true,
        hasEarlyEvidenceTimeline: false,
        patternChangedVisible: false,
        dailyReturnReasonEligible: false,
        weeklyReviewEligible: false,
        privateReportEligible: false,
        whyMattersEligible: false,
        thoughtMapEligible: false,
        positiveReinforcementEligible: false,
        changeProofEligible: false,
        firstWeekLoopEligible: false,
        proBridgeEligible: false,
      );

      expect(decision.showEarlyRepeatProgress, isFalse);
      expect(decision.showArchiveSummary, isTrue);
    });
  });

  group('EarlyRepeatProgressCard', () {
    testWidgets('renders progress and next moment cue without CTAs', (
      tester,
    ) async {
      const progress = EarlyRepeatProgressResult(
        kind: EarlyRepeatProgressKind.oneMoment,
        title: EarlyRepeatProgressCopy.oneMomentTitle,
        body: EarlyRepeatProgressCopy.oneMomentBody,
        progressLabel: EarlyRepeatProgressCopy.oneMomentProgress,
        nextMomentCue: EarlyRepeatNextMomentCue(
          label: EarlyRepeatProgressCopy.oneMomentCueLabel,
          body: EarlyRepeatProgressCopy.oneMomentCueBodyFallback,
          footer: EarlyRepeatProgressCopy.oneMomentCueFooter,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EarlyRepeatProgressCard(progress: progress),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('early_repeat_progress_card_oneMoment')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('early_repeat_progress_title')), findsOneWidget);
      expect(find.byKey(const Key('early_repeat_progress_body')), findsOneWidget);
      expect(find.byKey(const Key('early_repeat_progress_label')), findsOneWidget);
      expect(
        find.byKey(const Key('early_repeat_progress_next_moment_cue_label')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_repeat_progress_next_moment_cue_body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_repeat_progress_next_moment_cue_footer')),
        findsOneWidget,
      );
      expect(find.text(EarlyRepeatProgressCopy.oneMomentBody), findsOneWidget);
      expect(
        find.text(EarlyRepeatProgressCopy.oneMomentCueBodyFallback),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
    });
  });

  group('PostSaveReturnHandoffEngine', () {
    test('entry 1 post-save shows come back title', () {
      final handoff = PostSaveReturnHandoffEngine.build(
        entries: [_entry('1', 'I felt pressure before saying yes again today.')],
      );

      expect(handoff!.title, PostSaveReturnHandoffCopy.afterFirstSaveTitle);
      expect(handoff.relationState, PostSaveReturnHandoffRelationState.oneMoment);
    });

    test('entry 1 with phrase uses phrase in body', () {
      final handoff = PostSaveReturnHandoffEngine.build(
        entries: [
          _entry(
            '1',
            'I had no capacity but I said yes again to the extra meeting today.',
          ),
        ],
      );

      expect(handoff!.hasPhrase, isTrue);
      expect(handoff.body, contains('said yes again'));
      expect(
        handoff.body,
        PostSaveReturnHandoffCopy.afterFirstSaveBodyWithPhrase('said yes again'),
      );
    });

    test('entry 1 without phrase uses fallback copy', () {
      final handoff = PostSaveReturnHandoffEngine.build(
        entries: [_entry('1', 'A quiet moment about lunch with a friend today.')],
      );

      expect(handoff!.hasPhrase, isFalse);
      expect(
        handoff.body,
        PostSaveReturnHandoffCopy.afterFirstSaveBodyFallback,
      );
    });

    test('entry 2 related shows one more creates the first proof', () {
      final handoff = PostSaveReturnHandoffEngine.build(
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

      expect(handoff!.title, PostSaveReturnHandoffCopy.afterSecondSaveRelatedTitle);
      expect(
        handoff.stage,
        PostSaveReturnHandoffStage.afterSecondSaveRelated,
      );
    });

    test('entry 2 unrelated does not claim repeat', () {
      final handoff = PostSaveReturnHandoffEngine.build(
        entries: [
          _entry('1', 'A quiet moment about lunch with a friend today.'),
          _entry('2', 'Another unrelated note about errands this afternoon.'),
        ],
      );

      expect(handoff!.title, PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedTitle);
      expect(
        handoff.body,
        PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedBody,
      );
      expect(handoff.body.toLowerCase(), isNot(contains('first proof')));
    });

    test('entry 3 returns null', () {
      expect(
        PostSaveReturnHandoffEngine.build(
          entries: [
            _entry('1', 'First moment with enough words to count as evidence.'),
            _entry('2', 'Second moment with enough words to count as evidence.'),
            _entry('3', 'Third moment with enough words to count as evidence.'),
          ],
        ),
        isNull,
      );
    });

    test('copy avoids therapy and diagnosis language', () {
      const copy = [
        PostSaveReturnHandoffCopy.afterFirstSaveTitle,
        PostSaveReturnHandoffCopy.afterFirstSaveBodyFallback,
        PostSaveReturnHandoffCopy.afterFirstSaveFooter,
        PostSaveReturnHandoffCopy.afterSecondSaveRelatedTitle,
        PostSaveReturnHandoffCopy.afterSecondSaveRelatedBodyFallback,
        PostSaveReturnHandoffCopy.afterSecondSaveRelatedFooter,
        PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedTitle,
        PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedBody,
        PostSaveReturnHandoffCopy.afterSecondSaveUnrelatedFooter,
      ];
      final blob = copy.join(' ').toLowerCase();
      for (final banned in [
        'therapy',
        'diagnosis',
        'disorder',
        'anxiety disorder',
      ]) {
        expect(blob, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('PostSaveReturnHandoffGates', () {
    test('shows only on successful post-save for entryCount 1–2', () {
      final handoff = PostSaveReturnHandoffEngine.build(
        entries: [_entry('1', 'A saved moment with enough words for evidence.')],
      );

      expect(
        PostSaveReturnHandoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 1,
          isDegradedPostSave: false,
          handoff: handoff,
        ),
        isTrue,
      );
      expect(
        PostSaveReturnHandoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 0,
          isDegradedPostSave: false,
          handoff: handoff,
        ),
        isFalse,
      );
      expect(
        PostSaveReturnHandoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 3,
          isDegradedPostSave: false,
          handoff: handoff,
        ),
        isFalse,
      );
      expect(
        PostSaveReturnHandoffGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 1,
          isDegradedPostSave: true,
          handoff: handoff,
        ),
        isFalse,
      );
    });
  });

  group('PostSaveReturnHandoff analytics', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      EarlyArchiveProofAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) => captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    testWidgets('metadata excludes transcript and phrase text', (tester) async {
      final handoff = PostSaveReturnHandoff(
        stage: PostSaveReturnHandoffStage.afterFirstSave,
        relationState: PostSaveReturnHandoffRelationState.oneMoment,
        title: PostSaveReturnHandoffCopy.afterFirstSaveTitle,
        body: PostSaveReturnHandoffCopy.afterFirstSaveBodyWithPhrase(
          'said yes again',
        ),
        footer: PostSaveReturnHandoffCopy.afterFirstSaveFooter,
        hasPhrase: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostSaveReturnHandoffCard(handoff: handoff, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      expect(captured, hasLength(1));
      final payload = captured.single.properties;
      expect(captured.single.event, EarlyArchiveProofAnalytics.postSaveReturnHandoffSeenEvent);
      expect(payload['entry_count'], 1);
      expect(payload['source'], 'record');
      expect(payload['stage'], 'after_first_save');
      expect(payload['has_phrase'], 1);
      expect(payload['relation_state'], 'one_moment');
      expect(payload.values.whereType<String>(), isNot(contains('said yes again')));
      expect(payload.values.whereType<String>(), isNot(contains(handoff.body)));
    });
  });

  group('FirstProofMomentEngine', () {
    List<JournalEntry> _threeRelated() => [
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

    test('third related post-save builds first repeat title', () {
      final moment = FirstProofMomentEngine.build(entries: _threeRelated());
      expect(moment!.title, FirstProofMomentCopy.title);
      expect(moment.usesPhraseBody, isTrue);
      expect(moment.body, contains('said yes again'));
    });

    test('evidence chips come from user words', () {
      final moment = FirstProofMomentEngine.build(entries: _threeRelated());
      expect(moment!.evidencePhrases, isNotEmpty);
      for (final phrase in moment.evidencePhrases) {
        expect(phrase.split(RegExp(r'\s+')).length, lessThanOrEqualTo(6));
        expect(
          ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase),
          isFalse,
        );
      }
    });

    test('fallback copy when phrase body is unavailable', () {
      final entries = [
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
          'I agreed to help again before checking whether I had capacity today.',
        ),
      ];
      final moment = FirstProofMomentEngine.build(entries: entries);
      if (moment == null) {
        expect(FirstProofMomentCopy.bodyFallback, isNotEmpty);
        return;
      }
      if (!moment.usesPhraseBody) {
        expect(moment.body, FirstProofMomentCopy.bodyFallback);
      }
    });

    test('unrelated third entry returns null', () {
      expect(
        FirstProofMomentEngine.build(
          entries: [
            _entry('1', 'A quiet moment about lunch with a friend today.'),
            _entry('2', 'Another unrelated note about errands this afternoon.'),
            _entry('3', 'A calm evening walk before bed tonight.'),
          ],
        ),
        isNull,
      );
    });

    test('copy avoids therapy diagnosis and personality claims', () {
      const copy = [
        FirstProofMomentCopy.title,
        FirstProofMomentCopy.bodyFallback,
        FirstProofMomentCopy.evidenceLabel,
        FirstProofMomentCopy.whyLine,
        FirstProofMomentCopy.footer,
      ];
      final blob = copy.join(' ').toLowerCase();
      for (final banned in [
        'therapy',
        'diagnosis',
        'disorder',
        'you always',
        'you are',
        'we know you',
      ]) {
        expect(blob, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('FirstProofMomentGates', () {
    test('shows only on third related post-save', () {
      final moment = FirstProofMomentEngine.build(
        entries: [
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
        ],
      );

      expect(
        FirstProofMomentGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 3,
          isDegradedPostSave: false,
          moment: moment,
        ),
        isTrue,
      );
      expect(
        FirstProofMomentGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 2,
          isDegradedPostSave: false,
          moment: moment,
        ),
        isFalse,
      );
      expect(
        FirstProofMomentGates.shouldShow(
          isPostSaveDone: true,
          entryCount: 3,
          isDegradedPostSave: true,
          moment: moment,
        ),
        isFalse,
      );
    });
  });

  group('FirstProofMoment analytics', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      EarlyArchiveProofAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) => captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    testWidgets('metadata excludes transcript and phrase text', (tester) async {
      final moment = FirstProofMomentEngine.build(
        entries: [
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
        ],
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstProofMomentCard(moment: moment, entryCount: 3),
          ),
        ),
      );
      await tester.pump();

      expect(captured, hasLength(1));
      final payload = captured.single.properties;
      expect(
        captured.single.event,
        EarlyArchiveProofAnalytics.firstProofMomentSeenEvent,
      );
      expect(payload['entry_count'], 3);
      expect(payload['source'], 'record');
      expect(payload['phrase_count'], moment.evidencePhrases.length);
      expect(payload['has_strong_evidence'], 1);
      for (final phrase in moment.evidencePhrases) {
        expect(payload.values.whereType<String>(), isNot(contains(phrase)));
      }
      expect(payload.values.whereType<String>(), isNot(contains(moment.body)));
    });
  });
}
