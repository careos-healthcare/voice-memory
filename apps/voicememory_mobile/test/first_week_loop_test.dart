import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gates.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_copy.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_engine.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_gates.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_model.dart';
import 'package:voicememory_mobile/features/early_archive/record_proof_stack_policy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/features/early_archive/first_week_loop_analytics.dart';
import 'package:voicememory_mobile/widgets/record/first_week_loop_card.dart';

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

List<JournalEntry> _threeRelatedRepeatEntries() => [
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

RepeatReturnCheckRecord _answeredRecord(RepeatReturnCheckChoice choice) =>
    RepeatReturnCheckRecord(
      entryId: 'e4',
      choice: choice,
      entryCountAtCapture: 4,
      createdAt: DateTime(2026, 6, 13),
    );

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
  expect(lower, isNot(contains('you always')));
  expect(lower, isNot(contains('we know you')));
  expect(lower, isNot(contains('mental health')));
}

void main() {
  setUp(() async {
    EarlyArchiveProofAnalytics.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_fwl.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('FirstWeekLoopEngine', () {
    test('hidden below entryCount 3', () {
      expect(
        FirstWeekLoopEngine.build(
          entries: [_entry('1', 'I said yes again today.')],
          returnChecks: const [],
        ),
        isNull,
      );
      expect(
        FirstWeekLoopEngine.build(
          entries: [
            _entry('1', 'I said yes again today.'),
            _entry('2', 'Same — said yes again today.'),
          ],
          returnChecks: const [],
        ),
        isNull,
      );
    });

    test('shown at entryCount 3+ with confirmed repeat', () {
      final loop = FirstWeekLoopEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(loop!.title, FirstWeekLoopCopy.title);
      expect(loop.hasConfirmedRepeat, isTrue);
    });

    test('hidden after return check answered', () {
      expect(
        FirstWeekLoopEngine.build(
          entries: [
            ..._threeRelatedRepeatEntries(),
            _entry('4', 'I said yes again even though I had no capacity today.'),
          ],
          returnChecks: [_answeredRecord(RepeatReturnCheckChoice.stronger)],
        ),
        isNull,
      );
    });

    test('hidden for unrelated weak repeat', () {
      expect(
        FirstWeekLoopEngine.build(
          entries: [
            _entry('1', 'A quiet moment about lunch with a friend today.'),
            _entry('2', 'Another unrelated note about errands this afternoon.'),
            _entry('3', 'A calm evening walk before bed tonight.'),
          ],
          returnChecks: const [],
        ),
        isNull,
      );
    });

    test('phrase body uses concrete phrase when available', () {
      final loop = FirstWeekLoopEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(loop!.usesPhraseBody, isTrue);
      expect(loop.body, contains('said yes'));
    });

    test('fallback body when phrase unavailable', () {
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
      final loop = FirstWeekLoopEngine.build(
        entries: entries,
        returnChecks: const [],
      );
      if (loop == null) return;
      if (!loop.usesPhraseBody) {
        expect(loop.body, FirstWeekLoopCopy.bodyFallback);
      }
    });
  });

  group('FirstWeekLoopGates', () {
    test('hidden at entryCount 0, 1, 2', () {
      const loop = FirstWeekLoop(
        title: FirstWeekLoopCopy.title,
        body: FirstWeekLoopCopy.bodyFallback,
        label: FirstWeekLoopCopy.label,
        footer: FirstWeekLoopCopy.footer,
        cta: FirstWeekLoopCopy.recordCta,
        hasPhrase: false,
        hasConfirmedRepeat: true,
        usesPhraseBody: false,
      );
      for (final count in [0, 1, 2]) {
        expect(
          FirstWeekLoopGates.shouldShow(
            loaded: true,
            entryCount: count,
            isReady: true,
            isRecording: false,
            isPostSave: false,
            isProRequirementGated: false,
            policyAllows: true,
            loop: loop,
          ),
          isFalse,
        );
      }
    });

    test('hidden on post-save done surface', () {
      final loop = FirstWeekLoopEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(
        FirstWeekLoopGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: false,
          isRecording: false,
          isPostSave: true,
          isProRequirementGated: false,
          policyAllows: true,
          loop: loop,
        ),
        isFalse,
      );
    });

    test('hidden when pro requirement gated', () {
      final loop = FirstWeekLoopEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      );
      expect(
        FirstWeekLoopGates.isProRequirementGated(
          valueMomentProBridgeVisible: true,
          purchaseIntentReturnCueVisible: false,
        ),
        isTrue,
      );
      expect(
        FirstWeekLoopGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isProRequirementGated: true,
          policyAllows: true,
          loop: loop,
        ),
        isFalse,
      );
    });

    test('card CTA hidden when primary record CTA is visible', () {
      const policy = RecordCtaPolicyResolution(
        state: RecordCtaPolicyState.returning,
        primaryLabel: ConsumerUiCopy.recordMomentCta,
        showMainBottomCta: true,
        action: RecordCtaAction.startRecording,
      );
      expect(
        FirstWeekLoopGates.showRecordCta(
          policy: policy,
          hideCardRecordButtons: false,
          promoteMicCaptureActions: true,
        ),
        isFalse,
      );
      expect(
        ArchiveBetaMissionGates.capturePrimaryCtaVisible(
          policy: policy,
          hideCardRecordButtons: false,
          promoteMicCaptureActions: true,
        ),
        isTrue,
      );
    });
  });

  group('RecordProofStackPolicy first week loop', () {
    test('drops pro bridge before first week loop when cap exceeded', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: false,
        hasEarlyEvidenceTimeline: false,
        patternChangedVisible: true,
        dailyReturnReasonEligible: false,
        weeklyReviewEligible: false,
        privateReportEligible: false,
        whyMattersEligible: false,
        thoughtMapEligible: false,
        positiveReinforcementEligible: false,
        changeProofEligible: false,
        firstWeekLoopEligible: true,
        proBridgeEligible: true,
      );

      expect(decision.proofCardCount, 3);
      expect(decision.showFirstWeekLoop, isTrue);
      expect(decision.showProBridge, isFalse);
      expect(decision.showPatternChanged, isTrue);
      expect(decision.showArchiveSummary, isTrue);
    });

    test('drops first week loop when pattern changed overflows cap', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: false,
        hasEarlyEvidenceTimeline: false,
        patternChangedVisible: true,
        dailyReturnReasonEligible: true,
        weeklyReviewEligible: false,
        privateReportEligible: false,
        whyMattersEligible: false,
        thoughtMapEligible: false,
        positiveReinforcementEligible: false,
        changeProofEligible: false,
        firstWeekLoopEligible: true,
        proBridgeEligible: true,
      );

      expect(decision.proofCardCount, lessThanOrEqualTo(3));
      expect(decision.showPatternChanged, isTrue);
      expect(decision.showArchiveSummary, isTrue);
      expect(decision.showFirstWeekLoop, isFalse);
      expect(decision.showProBridge, isFalse);
    });
  });

  group('FirstWeekLoopCard', () {
    testWidgets('invokes record callback on CTA tap', (tester) async {
      var tapped = false;
      final loop = FirstWeekLoopEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstWeekLoopCard(
              loop: loop,
              entryCount: 3,
              showRecordCta: true,
              onRecord: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('first_week_loop_record_cta')));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('hides CTA when showRecordCta is false', (tester) async {
      final loop = FirstWeekLoopEngine.build(
        entries: _threeRelatedRepeatEntries(),
        returnChecks: const [],
      )!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FirstWeekLoopCard(
              loop: loop,
              entryCount: 3,
              showRecordCta: false,
              onRecord: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('first_week_loop_record_cta')), findsNothing);
    });
  });

  group('FirstWeekLoopAnalytics', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) => captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    test('seen metadata omits transcript and phrase text', () {
      FirstWeekLoopAnalytics.seen(
        entryCount: 3,
        hasPhrase: true,
        hasConfirmedRepeat: true,
      );

      expect(captured, hasLength(1));
      final payload = captured.single.properties;
      expect(captured.single.event, EarlyArchiveProofAnalytics.firstWeekLoopSeenEvent);
      expect(payload['entry_count'], 3);
      expect(payload['source'], 'record');
      expect(payload['has_phrase'], 1);
      expect(payload['has_confirmed_repeat'], 1);
      expect(payload.values.whereType<String>(), isNot(contains('said yes again')));
    });

    test('record tapped metadata omits transcript and phrase text', () {
      FirstWeekLoopAnalytics.recordTapped(
        entryCount: 4,
        hasPhrase: true,
        hasConfirmedRepeat: true,
      );

      expect(captured, hasLength(1));
      final payload = captured.single.properties;
      expect(
        captured.single.event,
        EarlyArchiveProofAnalytics.firstWeekLoopRecordTappedEvent,
      );
      expect(payload['entry_count'], 4);
      expect(payload['source'], 'record');
      expect(payload.values.whereType<String>(), isNot(contains('said yes again')));
    });
  });

  group('FirstWeekLoopCopy guard', () {
    test('copy avoids therapy diagnosis and personality claims', () {
      const copy = [
        FirstWeekLoopCopy.title,
        FirstWeekLoopCopy.bodyFallback,
        FirstWeekLoopCopy.label,
        FirstWeekLoopCopy.footer,
        FirstWeekLoopCopy.recordCta,
      ];
      for (final line in copy) {
        _expectNoDiagnosticLanguage(line);
      }
      _expectNoDiagnosticLanguage(
        FirstWeekLoopCopy.bodyWithPhrase('said yes again'),
      );
    });

    test('first proof copy stays distinct from first week loop', () {
      expect(FirstProofMomentCopy.title, isNot(FirstWeekLoopCopy.title));
      expect(FirstWeekLoopCopy.title, isNot(contains('first repeat')));
    });

    test('explains why recording again matters after first proof', () {
      final joined = [
        FirstWeekLoopCopy.bodyFallback,
        FirstWeekLoopCopy.footer,
        FirstWeekLoopCopy.bodyWithPhrase('said yes again'),
      ].join(' ').toLowerCase();

      expect(joined, contains('first proof'));
      expect(joined, contains('stronger'));
      expect(joined, contains('softer'));
      expect(joined, contains('about the same'));
      expect(joined, contains('what changed'));
      expect(joined, contains('when it returns'));
      expect(joined, isNot(contains('you are')));
      expect(joined, isNot(contains('you should')));
    });
  });

  group('Patterns screen isolation', () {
    test('archive belief screen does not import first week loop card', () {
      final source = File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      expect(source.contains('first_week_loop'), isFalse);
      expect(source.contains('FirstWeekLoopCard'), isFalse);
    });
  });
}
