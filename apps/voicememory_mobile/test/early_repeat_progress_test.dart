import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_gates.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_model.dart';
import 'package:voicememory_mobile/features/early_archive/record_proof_stack_policy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/record/early_repeat_progress_card.dart';

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
}
