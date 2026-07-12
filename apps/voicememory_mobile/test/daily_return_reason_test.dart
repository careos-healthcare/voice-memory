import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_copy.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_engine.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_gates.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_model.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_models.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/widgets/record/daily_return_reason_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

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

List<JournalEntry> _mixedRepeatAndWalkEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'w4',
        transcript: 'I walked outside before replying and it helped.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
      _entry(
        id: 'w5',
        transcript: 'Same week I walked outside again before the hard email.',
        createdAt: DateTime(2026, 6, 14, 12),
      ),
    ];

RepeatReturnCheckChangeProof _changeProof(RepeatReturnCheckChoice choice) =>
    RepeatReturnCheckChangeProof(
      title: RepeatReturnCheckCopy.changeProofTitle,
      body: switch (choice) {
        RepeatReturnCheckChoice.stronger =>
          RepeatReturnCheckCopy.trendGettingLouder,
        RepeatReturnCheckChoice.softer =>
          RepeatReturnCheckCopy.trendSofterThanBefore,
        RepeatReturnCheckChoice.same => RepeatReturnCheckCopy.trendSteady,
        RepeatReturnCheckChoice.changed => RepeatReturnCheckCopy.trendSteady,
      },
      latestChoice: choice,
    );

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

void main() {
  setUp(DailyReturnReasonAnalytics.resetForTest);

  group('DailyReturnReasonGates', () {
    test('hidden before three entries and while recording', () {
      expect(
        DailyReturnReasonGates.shouldShow(
          loaded: true,
          entryCount: 2,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasReason: true,
        ),
        isFalse,
      );
      expect(
        DailyReturnReasonGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: true,
          viewingConfirmedRepeatOrTimeline: true,
          hasReason: true,
        ),
        isFalse,
      );
      expect(
        DailyReturnReasonGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: false,
          hasReason: true,
        ),
        isFalse,
      );
      expect(
        DailyReturnReasonGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasReason: true,
        ),
        isTrue,
      );
    });

    test('record CTA hides when capture primary is visible', () {
      expect(
        DailyReturnReasonGates.showRecordCta(
          policy: const RecordCtaPolicyResolution(
            state: RecordCtaPolicyState.returning,
            primaryLabel: ConsumerUiCopy.recordMomentCta,
            showMainBottomCta: true,
            action: RecordCtaAction.startRecording,
          ),
          hideCardRecordButtons: true,
          promoteMicCaptureActions: false,
        ),
        isFalse,
      );
    });
  });

  group('DailyReturnReasonEngine', () {
    test('hidden without archive proof context', () {
      expect(
        DailyReturnReasonEngine.build(
          entries: _threeRelatedRepeatEntries(),
          viewingConfirmedRepeatOrTimeline: false,
        ),
        isNull,
      );
    });

    test('missing trigger chooses trigger prompt', () {
      final reason = DailyReturnReasonEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(reason, isNotNull);
      expect(reason!.kind, DailyReturnReasonKind.missingTrigger);
      expect(reason.body, DailyReturnReasonCopy.missingTriggerBody);
      expect(reason.prompt, DailyReturnReasonCopy.missingTriggerPrompt);
      expect(reason.targetSection, ThoughtMapSectionId.trigger);
    });

    test('missing thought chooses thought prompt after trigger is known', () {
      final entries = [
        ..._threeRelatedRepeatEntries(),
        _entry(
          id: 'e4',
          transcript:
              'The extra ask came in right before I said yes again without checking capacity.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ];
      final reason = DailyReturnReasonEngine.build(
        entries: entries,
        triggerCapturedMilestone: true,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(reason, isNotNull);
      if (reason!.kind == DailyReturnReasonKind.missingThought) {
        expect(reason.body, DailyReturnReasonCopy.missingThoughtBody);
        expect(reason.prompt, DailyReturnReasonCopy.missingThoughtPrompt);
        expect(reason.targetSection, ThoughtMapSectionId.thought);
      }
    });

    test('no change proof chooses change prompt after loop gaps filled', () {
      final reason = DailyReturnReasonEngine.build(
        entries: _threeRelatedRepeatEntries(),
        changeProof: null,
        triggerCapturedMilestone: true,
        helpfulActionCapturedMilestone: true,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(reason, isNotNull);
      if (reason!.kind == DailyReturnReasonKind.missingChange) {
        expect(reason.body, DailyReturnReasonCopy.missingChangeBody);
        expect(reason.prompt, DailyReturnReasonCopy.missingChangePrompt);
      }
    });

    test('no positive pattern chooses helped prompt when loop and change known', () {
      final reason = DailyReturnReasonEngine.build(
        entries: _threeRelatedRepeatEntries(),
        changeProof: _changeProof(RepeatReturnCheckChoice.same),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(reason, isNotNull);
      if (reason!.kind == DailyReturnReasonKind.missingPositive) {
        expect(reason.body, DailyReturnReasonCopy.missingPositiveBody);
        expect(reason.prompt, DailyReturnReasonCopy.missingPositivePrompt);
      }
    });

    test('complete archive chooses next real moment prompt', () {
      final reason = DailyReturnReasonEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
        changeProof: _changeProof(RepeatReturnCheckChoice.softer),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(reason, isNotNull);
      if (reason!.kind == DailyReturnReasonKind.complete) {
        expect(reason.body, DailyReturnReasonCopy.completeBody);
        expect(reason.prompt, DailyReturnReasonCopy.completePrompt);
      }
    });
  });

  group('DailyReturnReasonCopy', () {
    test('avoids therapy and diagnosis language', () {
      final lines = [
        DailyReturnReasonCopy.title,
        DailyReturnReasonCopy.missingTriggerBody,
        DailyReturnReasonCopy.missingTriggerPrompt,
        DailyReturnReasonCopy.missingThoughtBody,
        DailyReturnReasonCopy.missingThoughtPrompt,
        DailyReturnReasonCopy.missingActionBody,
        DailyReturnReasonCopy.missingActionPrompt,
        DailyReturnReasonCopy.missingResultBody,
        DailyReturnReasonCopy.missingResultPrompt,
        DailyReturnReasonCopy.missingChangeBody,
        DailyReturnReasonCopy.missingChangePrompt,
        DailyReturnReasonCopy.missingPositiveBody,
        DailyReturnReasonCopy.missingPositivePrompt,
        DailyReturnReasonCopy.completeBody,
        DailyReturnReasonCopy.completePrompt,
        DailyReturnReasonCopy.recordCta,
      ];
      final copy = lines.join(' ');
      _expectNoDiagnosticLanguage(copy);
      for (final line in lines) {
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('"$line": $reason');
        }
      }
    });
  });

  group('DailyReturnReasonCard', () {
    testWidgets('renders title body prompt and subtle CTA', (tester) async {
      final reason = DailyReturnReasonEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(reason, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyReturnReasonCard(
                reason: reason!,
                showRecordCta: true,
                onRecord: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text(DailyReturnReasonCopy.title), findsOneWidget);
      expect(find.text(reason.body), findsOneWidget);
      expect(find.text(reason.prompt), findsOneWidget);
      expect(find.text(DailyReturnReasonCopy.recordCta), findsOneWidget);
    });
  });

  group('DailyReturnReasonAnalytics', () {
    test('omits transcript text', () {
      Map<String, Object>? captured;
      DailyReturnReasonAnalytics.captureForTest = (event, props) {
        captured = props;
      };
      DailyReturnReasonAnalytics.recordTapped(
        kind: DailyReturnReasonKind.missingTrigger,
        surface: 'record',
        entryCount: 3,
      );
      expect(captured, isNotNull);
      expect(captured!.keys, containsAll(['kind', 'surface', 'entry_count']));
      expect(captured!.keys, isNot(contains('transcript')));
      expect(
        captured!.values.whereType<String>(),
        everyElement(isNot(contains('said yes'))),
      );
    });
  });

  group('DailyReturnReason archive proof', () {
    test('visible after confirmed repeat foundation', () {
      final entries = _threeRelatedRepeatEntries();
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );
      expect(
        DailyReturnReasonEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNotNull,
      );
    });
  });
}
