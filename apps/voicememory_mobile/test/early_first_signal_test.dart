import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_evidence_milestone_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_quality_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_why_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_quality_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_feedback_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_feedback_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_feedback_models.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_insight_feedback_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_return_reminder_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_return_reminder_gates.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_return_reminder_service.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_return_reminder_session.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_return_reminder_store.dart';
import 'package:voicememory_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:voicememory_mobile/features/early_archive/early_evidence_timeline_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_archive_proof_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/early_evidence_timeline_demo.dart';
import 'package:voicememory_mobile/features/early_archive/early_evidence_timeline_demo_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_evidence_timeline_engine.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_why_matters_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_why_matters_gates.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_why_matters_store.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_analytics.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_engine.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_gates.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_models.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_store.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gates.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_helpful_action_capture.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_trigger_capture.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_record_routes.dart';
import 'package:voicememory_mobile/features/first_session/first_session_coordinator.dart';
import 'package:voicememory_mobile/features/record/record_empty_archive_gates.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/widgets/patterns/early_evidence_timeline_demo_section.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_empty_view.dart';
import 'package:voicememory_mobile/widgets/record/confirmed_repeat_change_notice_card.dart';
import 'package:voicememory_mobile/widgets/record/confirmed_repeat_helpful_action_payoff_card.dart';
import 'package:voicememory_mobile/widgets/record/confirmed_repeat_trigger_payoff_card.dart';
import 'package:voicememory_mobile/widgets/record/early_archive_insight_feedback_row.dart';
import 'package:voicememory_mobile/widgets/record/early_archive_return_reminder_card.dart';
import 'package:voicememory_mobile/widgets/record/early_evidence_timeline_card.dart';
import 'package:voicememory_mobile/widgets/record/early_archive_insight_why_section.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/widgets/record/confirmed_repeat_why_matters_card.dart';
import 'package:voicememory_mobile/widgets/record/confirmed_repeat_thought_map_card.dart';
import 'package:voicememory_mobile/widgets/record/early_first_signal_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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

const _bannedStrongBelief = [
  'your archive believes',
  'pattern found',
  'confirmed belief',
  'working hypothesis',
];

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

List<JournalEntry> _fourEntriesWithTriggerCapture() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'The extra ask came in right before I said yes again without checking capacity.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _fourEntriesWithSofterRelatedReturn() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'Same yes pattern came back but it felt less urgent and easier to stop this time.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _fourEntriesWithNormalRelatedReturn() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I said yes again even though I had no capacity for one more ask today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _fourEntriesWithUnrelatedSofterEntry() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'Weather was nice on my walk through the park and felt calmer outside.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _fiveEntriesWithHelpfulActionCapture() => [
  ..._fourEntriesWithSofterRelatedReturn(),
  _entry(
    id: 'e5',
    transcript:
        'I paused before saying yes and asked for help, which made it easier to stop.',
    createdAt: DateTime(2026, 6, 14, 12),
  ),
];

List<JournalEntry> _threeCheckingUncertaintyEntries() => [
  _entry(
    id: 'e1',
    transcript: 'I kept checking my phone when things felt uncertain today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript: 'Same checking came back when everything still felt uncertain.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I was checking again because things felt uncertain about the decision.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _fiveEntriesWithWaitingHelpfulAction() => [
  ..._fourEntriesWithSofterRelatedReturn(),
  _entry(
    id: 'e5',
    transcript:
        'I waited two minutes before responding and that helped me stop.',
    createdAt: DateTime(2026, 6, 14, 12),
  ),
];

void _expectNoDiagnosticLanguage(String joined) {
  final lower = joined.toLowerCase();
  expect(lower, isNot(contains('you have anxiety')));
  expect(lower, isNot(contains('proves you')));
  expect(lower, isNot(contains('confirmed trigger')));
  expect(lower, isNot(contains('you fixed')));
  expect(lower, isNot(contains('healed')));
  expect(lower, isNot(contains('pattern was detected')));
}

void main() {
  setUp(() {
    ConfirmedRepeatTriggerCapture.resetSessionForTest();
    ConfirmedRepeatHelpfulActionCapture.resetSessionForTest();
    EarlyEvidenceMilestoneStore.resetForTest();
  });
  group('RecordEmptyArchiveGates.showEarlyFirstSignalCard', () {
    test('hidden at zero entries', () {
      expect(
        RecordEmptyArchiveGates.showEarlyFirstSignalCard(
          loaded: true,
          entryCount: 0,
          isPostSave: false,
        ),
        isFalse,
      );
    });

    test('shown at one through three entries when not post-save', () {
      for (final count in [1, 2, 3]) {
        expect(
          RecordEmptyArchiveGates.showEarlyFirstSignalCard(
            loaded: true,
            entryCount: count,
            isPostSave: false,
          ),
          isTrue,
        );
      }
    });

    test('hidden during post-save and after three entries', () {
      expect(
        RecordEmptyArchiveGates.showEarlyFirstSignalCard(
          loaded: true,
          entryCount: 1,
          isPostSave: true,
        ),
        isFalse,
      );
      expect(
        RecordEmptyArchiveGates.showEarlyFirstSignalCard(
          loaded: true,
          entryCount: 4,
          isPostSave: false,
        ),
        isFalse,
      );
    });
  });

  group('EarlyFirstSignalEngine', () {
    test('returns null at zero entries — no fake pattern', () {
      expect(EarlyFirstSignalEngine.build(entries: const []), isNull);
    });

    test('one entry is a heard receipt without pattern language', () {
      final model = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );

      expect(model, isNotNull);
      expect(model!.kind, EarlyFirstSignalKind.oneEntryReceipt);
      expect(model.title, EarlyFirstSignalCopy.oneEntryTitle);
      expect(model.lines.single, EarlyFirstSignalCopy.oneEntryBody);
      expect(model.showsPatternLanguage, isFalse);
      for (final banned in _bannedStrongBelief) {
        expect(
          '${model.title} ${model.lines.join(' ')}'.toLowerCase(),
          isNot(contains(banned)),
        );
      }
    });

    test('two unrelated entries do not force a pattern', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript: 'A quiet moment about lunch with a friend today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e2',
          transcript: 'Another unrelated note about errands this afternoon.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(entries),
        isFalse,
      );

      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.twoEntryNoPattern);
      expect(model.title, EarlyFirstSignalCopy.twoEntryNoPatternTitle);
      expect(model.lines.single, EarlyFirstSignalCopy.twoEntryNoPatternBody);
      expect(model.showsPatternLanguage, isFalse);
      expect(
        '${model.title} ${model.lines.join(' ')}',
        isNot(contains('start of a pattern')),
      );
    });

    test('two related entries show cautious first-signal copy', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e2',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(
        const SecondSessionSignalEngine().hasGroundedRepeatMatch(entries),
        isTrue,
      );

      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.twoEntryFirstSignal);
      expect(model.title, EarlyFirstSignalCopy.twoEntryRelatedTitle);
      expect(model.lines.single, EarlyFirstSignalCopy.twoEntryRelatedBody);
      expect(model.primaryCta, EarlyFirstSignalCopy.confirmRepeatCta);
      expect(model.showsConfirmedRepeat, isFalse);
    });

    test('three related entries show confirmed repeat with evidence', () {
      final entries = [
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

      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(entries),
        isTrue,
      );

      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.threeEntryConfirmedRepeat);
      expect(model.title, EarlyFirstSignalCopy.threeEntryConfirmedTitle);
      expect(
        model.lines,
        contains(EarlyFirstSignalCopy.threeEntrySeenThreeTimes),
      );
      expect(model.evidenceHeading, EarlyFirstSignalCopy.evidenceHeading);
      expect(model.evidencePhrases.length, greaterThanOrEqualTo(2));
      expect(model.evidencePhrases.length, lessThanOrEqualTo(3));
      expect(
        model.evidenceSupportLine,
        EarlyFirstSignalCopy.evidenceSupportLine,
      );
      expect(model.evidenceRows, isEmpty);
      expect(model.primaryCta, EarlyFirstSignalCopy.recordWhatHappensNextCta);
      expect(model.secondaryCta, EarlyFirstSignalCopy.viewEvidenceCta);
      expect(model.showsConfirmedRepeat, isTrue);
      expect(model.returnPrompt, isNotNull);
      expect(model.returnPrompt!.title, EarlyFirstSignalCopy.returnPromptTitle);
      expect(model.returnPrompt!.body, EarlyFirstSignalCopy.returnPromptBody);
      expect(
        model.returnPrompt!.cta,
        EarlyFirstSignalCopy.recordTriggerNextTimeCta,
      );
      expect(
        model.returnPrompt!.guidedRecordPrompt,
        EarlyFirstSignalCopy.recordTriggerGuidedPrompt,
      );
    });

    test('three unrelated entries do not show confirmed repeat', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript: 'A quiet moment about lunch with a friend today.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'e2',
          transcript: 'Another unrelated note about errands this afternoon.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e3',
          transcript: 'Weather was nice on my walk through the park today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(EarlyFirstSignalEngine.build(entries: entries), isNull);
      expect(
        '${entries.map((e) => e.transcript).join(' ')}',
        isNot(contains('confirmed repeat')),
      );
    });

    test('one and two entry models omit return prompt', () {
      final one = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript: 'I felt pressure before saying yes again today.',
          ),
        ],
      );
      expect(one!.returnPrompt, isNull);

      final two = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'I said yes again even though I was already tired from work today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _entry(
            id: 'e2',
            transcript:
                'I took responsibility again before asking anyone for help today.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );
      expect(two!.returnPrompt, isNull);
    });

    test('two related entries stay first signal not confirmed repeat', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript:
              'I said yes again even though I was already tired from work today.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e2',
          transcript:
              'I took responsibility again before asking anyone for help today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      final model = EarlyFirstSignalEngine.build(entries: entries);
      expect(model!.kind, EarlyFirstSignalKind.twoEntryFirstSignal);
      expect(model.showsConfirmedRepeat, isFalse);
      expect(model.title, isNot(EarlyFirstSignalCopy.threeEntryConfirmedTitle));
      expect(model.returnPrompt, isNull);
    });

    test('return prompt record route prefills guided trigger capture', () {
      final route = EarlyFirstSignalRecordRoutes.routeWithTriggerPrompt();
      expect(
        route,
        contains(
          Uri.encodeComponent(EarlyFirstSignalCopy.recordTriggerGuidedPrompt),
        ),
      );
      expect(route, startsWith('/record?prompt='));
    });
  });

  group('EarlyFirstSignalCard', () {
    testWidgets('renders first-signal lines for grounded two entries', (
      tester,
    ) async {
      final model = EarlyFirstSignalEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'I said yes again even though I was already tired from work today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _entry(
            id: 'e2',
            transcript:
                'I took responsibility again before asking anyone for help today.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyFirstSignalCard(signal: model!, onPrimary: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('early_first_signal_card_twoEntryFirstSignal')),
        findsOneWidget,
      );
      expect(
        find.text(EarlyFirstSignalCopy.twoEntryRelatedTitle),
        findsOneWidget,
      );
      expect(
        find.text(EarlyFirstSignalCopy.twoEntryRelatedBody),
        findsOneWidget,
      );
      expect(find.text(EarlyFirstSignalCopy.confirmRepeatCta), findsOneWidget);
    });

    testWidgets('renders confirmed repeat with evidence and view CTA', (
      tester,
    ) async {
      final model = EarlyFirstSignalEngine.build(
        entries: [
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
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyFirstSignalCard(
                signal: model!,
                onPrimary: () {},
                onViewEvidence: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          const Key('early_first_signal_card_threeEntryConfirmedRepeat'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(EarlyFirstSignalCopy.threeEntryConfirmedTitle),
        findsOneWidget,
      );
      expect(find.text(EarlyFirstSignalCopy.evidenceHeading), findsOneWidget);
      expect(
        find.byKey(const Key('early_first_signal_evidence_phrases')),
        findsOneWidget,
      );
      expect(find.text('Jun 10'), findsNothing);
      expect(find.text(EarlyFirstSignalCopy.viewEvidenceCta), findsOneWidget);
      expect(
        find.byKey(const Key('confirmed_repeat_return_prompt')),
        findsNothing,
      );
    });

    testWidgets('renders return prompt for confirmed repeat and fires CTA', (
      tester,
    ) async {
      final model = EarlyFirstSignalEngine.build(
        entries: [
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
        ],
      );

      var returnPromptTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyFirstSignalCard(
                signal: model!,
                onPrimary: () {},
                onViewEvidence: () {},
                onReturnPrompt: () => returnPromptTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('confirmed_repeat_return_prompt')),
        findsOneWidget,
      );
      expect(find.text(EarlyFirstSignalCopy.returnPromptTitle), findsOneWidget);
      expect(find.text(EarlyFirstSignalCopy.returnPromptBody), findsOneWidget);
      expect(
        find.text(EarlyFirstSignalCopy.recordTriggerNextTimeCta),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('confirmed_repeat_return_prompt_cta')),
      );
      await tester.tap(
        find.byKey(const Key('confirmed_repeat_return_prompt_cta')),
      );
      await tester.pump();

      expect(returnPromptTapped, isTrue);
    });
  });

  group('ConfirmedRepeatTriggerCapture payoff', () {
    test('saving from trigger guided prompt shows trigger payoff', () {
      ConfirmedRepeatTriggerCapture.armForNextSave();
      expect(
        ConfirmedRepeatTriggerCapture.resolveSave(
          capturePrompt: EarlyFirstSignalCopy.recordTriggerGuidedPrompt,
        ),
        isTrue,
      );

      final payoff = EarlyFirstSignalEngine.buildTriggerCapturePayoff(
        entries: _fourEntriesWithTriggerCapture(),
        savedFromTriggerPrompt: true,
      );

      expect(payoff, isNotNull);
      expect(payoff!.title, EarlyFirstSignalCopy.triggerPayoffTitle);
      expect(payoff.body, contains('trigger seems to be'));
      expect(payoff.body, contains('stronger evidence'));
      expect(payoff.evidenceLines.first, contains('keeps coming back'));
      expect(payoff.evidenceLines.last, contains('trigger seems to be'));
      expect(payoff.primaryCta, EarlyFirstSignalCopy.triggerPayoffPrimaryCta);
      expect(payoff.secondaryCta, EarlyFirstSignalCopy.viewEvidenceCta);
    });

    test('normal fourth entry save does not show trigger payoff', () {
      expect(
        ConfirmedRepeatTriggerCapture.resolveSave(capturePrompt: null),
        isFalse,
      );

      final payoff = EarlyFirstSignalEngine.buildTriggerCapturePayoff(
        entries: _fourEntriesWithTriggerCapture(),
        savedFromTriggerPrompt: false,
      );

      expect(payoff, isNull);
    });

    test('armed save without trigger prompt does not show payoff', () {
      ConfirmedRepeatTriggerCapture.armForNextSave();
      expect(
        ConfirmedRepeatTriggerCapture.resolveSave(
          capturePrompt: 'Some other recording prompt entirely.',
        ),
        isFalse,
      );

      expect(
        EarlyFirstSignalEngine.buildTriggerCapturePayoff(
          entries: _fourEntriesWithTriggerCapture(),
          savedFromTriggerPrompt: false,
        ),
        isNull,
      );
    });

    test('copy says captured once not confirmed trigger', () {
      final payoff = EarlyFirstSignalEngine.buildTriggerCapturePayoff(
        entries: _fourEntriesWithTriggerCapture(),
        savedFromTriggerPrompt: true,
      );

      final joined = [
        payoff!.title,
        payoff.body,
        ...payoff.evidenceLines,
      ].join(' ').toLowerCase();

      expect(joined, contains('seems'));
      expect(joined, isNot(contains('confirmed trigger')));
    });
  });

  group('ConfirmedRepeatTriggerPayoffCard', () {
    testWidgets('view evidence CTA routes via callback', (tester) async {
      final payoff = EarlyFirstSignalEngine.buildTriggerCapturePayoff(
        entries: _fourEntriesWithTriggerCapture(),
        savedFromTriggerPrompt: true,
      );

      var viewEvidenceTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatTriggerPayoffCard(
              payoff: payoff!,
              onKeepWatching: () {},
              onViewEvidence: () => viewEvidenceTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const Key('confirmed_repeat_trigger_payoff_view_evidence_cta'),
        ),
      );
      await tester.pump();

      expect(viewEvidenceTapped, isTrue);
      expect(find.text(EarlyFirstSignalCopy.viewEvidenceCta), findsOneWidget);
    });
  });

  group('ConfirmedRepeatChangeNotice', () {
    test(
      'confirmed repeat plus softer later entry shows change noticed card',
      () {
        final notice = EarlyFirstSignalEngine.buildChangeNotice(
          entries: _fourEntriesWithSofterRelatedReturn(),
        );

        expect(notice, isNotNull);
        expect(notice!.title, EarlyFirstSignalCopy.changeNoticeTitle);
        expect(notice.body, contains('came back'));
        expect(notice.body, contains('less urgent'));
        expect(notice.evidenceLines.first, contains('keeps coming back'));
        expect(notice.evidenceLines.last, contains('less urgent'));
        expect(notice.primaryCta, EarlyFirstSignalCopy.recordWhatHelpedCta);
        expect(notice.secondaryCta, EarlyFirstSignalCopy.viewEvidenceCta);
      },
    );

    test(
      'confirmed repeat plus normal later entry does not show change card',
      () {
        expect(
          EarlyFirstSignalEngine.buildChangeNotice(
            entries: _fourEntriesWithNormalRelatedReturn(),
          ),
          isNull,
        );
      },
    );

    test('unrelated softer entry does not show change noticed card', () {
      expect(
        EarlyFirstSignalEngine.buildChangeNotice(
          entries: _fourEntriesWithUnrelatedSofterEntry(),
        ),
        isNull,
      );
    });

    test('copy uses cautious may have been softer language', () {
      final notice = EarlyFirstSignalEngine.buildChangeNotice(
        entries: _fourEntriesWithSofterRelatedReturn(),
      );

      final joined = [
        notice!.title,
        notice.body,
        ...notice.evidenceLines,
      ].join(' ').toLowerCase();

      expect(joined, contains('less urgent'));
      expect(joined, isNot(contains('fixed')));
      expect(joined, isNot(contains('healed')));
    });

    test('record what helped CTA route prefills guided prompt', () {
      final route = EarlyFirstSignalRecordRoutes.routeWithWhatHelpedPrompt();
      expect(
        route,
        contains(
          Uri.encodeComponent(
            EarlyFirstSignalCopy.recordWhatHelpedGuidedPrompt,
          ),
        ),
      );
      expect(route, startsWith('/record?prompt='));
    });
  });

  group('ConfirmedRepeatChangeNoticeCard', () {
    testWidgets('record what helped CTA fires callback', (tester) async {
      final notice = EarlyFirstSignalEngine.buildChangeNotice(
        entries: _fourEntriesWithSofterRelatedReturn(),
      );

      var recordWhatHelpedTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatChangeNoticeCard(
              notice: notice!,
              onRecordWhatHelped: () => recordWhatHelpedTapped = true,
              onViewEvidence: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('confirmed_repeat_change_notice_primary_cta')),
      );
      await tester.pump();

      expect(recordWhatHelpedTapped, isTrue);
      expect(
        find.text(EarlyFirstSignalCopy.recordWhatHelpedCta),
        findsOneWidget,
      );
    });
  });

  group('ConfirmedRepeatHelpfulActionCapture payoff', () {
    test('saving from what helped prompt shows helpful-action payoff', () {
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();
      expect(
        ConfirmedRepeatHelpfulActionCapture.resolveSave(
          capturePrompt: EarlyFirstSignalCopy.recordWhatHelpedGuidedPrompt,
        ),
        isTrue,
      );

      final payoff = EarlyFirstSignalEngine.buildHelpfulActionPayoff(
        entries: _fiveEntriesWithHelpfulActionCapture(),
        savedFromHelpfulActionPrompt: true,
      );

      expect(payoff, isNotNull);
      expect(payoff!.title, EarlyFirstSignalCopy.helpfulActionPayoffTitle);
      expect(
        payoff.body,
        anyOf(contains('may have helped'), contains('may have softened')),
      );
      expect(
        payoff.evidenceLines.last,
        anyOf(contains('may have helped'), contains('may have softened')),
      );
      expect(payoff.primaryCta, EarlyFirstSignalCopy.triggerPayoffPrimaryCta);
      expect(payoff.secondaryCta, EarlyFirstSignalCopy.viewEvidenceCta);
    });

    test('normal save after softening does not show helpful-action payoff', () {
      expect(
        ConfirmedRepeatHelpfulActionCapture.resolveSave(capturePrompt: null),
        isFalse,
      );

      expect(
        EarlyFirstSignalEngine.buildHelpfulActionPayoff(
          entries: _fourEntriesWithSofterRelatedReturn(),
          savedFromHelpfulActionPrompt: false,
        ),
        isNull,
      );
    });

    test('copy avoids confirmed helpful language', () {
      final payoff = EarlyFirstSignalEngine.buildHelpfulActionPayoff(
        entries: _fiveEntriesWithHelpfulActionCapture(),
        savedFromHelpfulActionPrompt: true,
      );

      final joined = [
        payoff!.title,
        payoff.body,
        ...payoff.evidenceLines,
      ].join(' ').toLowerCase();

      expect(
        joined,
        anyOf(contains('may have helped'), contains('may have softened')),
      );
      expect(joined, isNot(contains('confirmed helpful')));
      expect(joined, isNot(contains('proven')));
      _expectNoDiagnosticLanguage(joined);
    });

    test('trigger payoff takes priority over helpful-action capture', () {
      ConfirmedRepeatTriggerCapture.armForNextSave();
      ConfirmedRepeatHelpfulActionCapture.armForNextSave();

      final triggerSaved = ConfirmedRepeatTriggerCapture.resolveSave(
        capturePrompt: EarlyFirstSignalCopy.recordTriggerGuidedPrompt,
      );
      final helpfulSaved = triggerSaved
          ? false
          : ConfirmedRepeatHelpfulActionCapture.resolveSave(
              capturePrompt: EarlyFirstSignalCopy.recordWhatHelpedGuidedPrompt,
            );

      expect(triggerSaved, isTrue);
      expect(helpfulSaved, isFalse);

      expect(
        EarlyFirstSignalEngine.buildTriggerCapturePayoff(
          entries: _fourEntriesWithTriggerCapture(),
          savedFromTriggerPrompt: true,
        ),
        isNotNull,
      );
      expect(
        EarlyFirstSignalEngine.buildHelpfulActionPayoff(
          entries: _fiveEntriesWithHelpfulActionCapture(),
          savedFromHelpfulActionPrompt: false,
        ),
        isNull,
      );
    });
  });

  group('ConfirmedRepeatHelpfulActionPayoffCard', () {
    testWidgets('view evidence CTA fires callback', (tester) async {
      final payoff = EarlyFirstSignalEngine.buildHelpfulActionPayoff(
        entries: _fiveEntriesWithHelpfulActionCapture(),
        savedFromHelpfulActionPrompt: true,
      );

      var viewEvidenceTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatHelpfulActionPayoffCard(
              payoff: payoff!,
              onKeepWatching: () {},
              onViewEvidence: () => viewEvidenceTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const Key('confirmed_repeat_helpful_action_payoff_view_evidence_cta'),
        ),
      );
      await tester.pump();

      expect(viewEvidenceTapped, isTrue);
    });
  });

  group('EarlyEvidenceTimelineEngine', () {
    test('three related entries show only repeat confirmed', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      expect(timeline, isNotNull);
      expect(timeline!.title, EarlyEvidenceTimelineCopy.title);
      expect(timeline.subtitle, contains('tracking'));
      expect(timeline.subtitle, contains('saying yes'));
      expect(timeline.items.length, 1);
      expect(
        timeline.items.single.kind,
        EarlyEvidenceTimelineItemKind.repeatConfirmed,
      );
      expect(
        timeline.items.single.title,
        EarlyEvidenceTimelineCopy.repeatConfirmedTitle,
      );
      expect(timeline.items.single.body, contains('keeps coming back'));
    });

    test('trigger capture adds trigger captured item', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fourEntriesWithTriggerCapture(),
      );

      expect(timeline!.items.map((item) => item.kind), [
        EarlyEvidenceTimelineItemKind.repeatConfirmed,
        EarlyEvidenceTimelineItemKind.triggerCaptured,
      ]);
      expect(
        timeline.items[1].title,
        EarlyEvidenceTimelineCopy.triggerCapturedTitle,
      );
    });

    test('softer later entry adds softer return noticed item', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fourEntriesWithSofterRelatedReturn(),
      );

      expect(timeline!.items.map((item) => item.kind), [
        EarlyEvidenceTimelineItemKind.repeatConfirmed,
        EarlyEvidenceTimelineItemKind.softerReturn,
      ]);
      expect(
        timeline.items.last.title,
        EarlyEvidenceTimelineCopy.softerReturnTitle,
      );
    });

    test('helpful action capture adds helpful action captured item', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fiveEntriesWithHelpfulActionCapture(),
      );

      expect(timeline!.items.map((item) => item.kind), [
        EarlyEvidenceTimelineItemKind.repeatConfirmed,
        EarlyEvidenceTimelineItemKind.softerReturn,
        EarlyEvidenceTimelineItemKind.helpfulAction,
      ]);
      expect(
        timeline.items.last.title,
        EarlyEvidenceTimelineCopy.helpfulActionTitle,
      );
      expect(
        timeline.items.last.body,
        anyOf(contains('may have helped'), contains('may have softened')),
      );
    });

    test('unsupported items stay hidden', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fourEntriesWithNormalRelatedReturn(),
      );

      expect(timeline!.items.map((item) => item.kind), [
        EarlyEvidenceTimelineItemKind.repeatConfirmed,
      ]);
      expect(
        timeline.items.any(
          (item) => item.kind == EarlyEvidenceTimelineItemKind.triggerCaptured,
        ),
        isFalse,
      );
      expect(
        timeline.items.any(
          (item) => item.kind == EarlyEvidenceTimelineItemKind.softerReturn,
        ),
        isFalse,
      );
    });

    test('unrelated entries do not create fake timeline items', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript: 'A quiet moment about lunch with a friend today.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'e2',
          transcript: 'Another unrelated note about errands this afternoon.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e3',
          transcript: 'Weather was nice on my walk through the park today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      expect(EarlyEvidenceTimelineEngine.build(entries: entries), isNull);
    });

    test('timeline copy uses cautious language', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fiveEntriesWithHelpfulActionCapture(),
      );

      final joined = [
        timeline!.title,
        timeline.subtitle,
        for (final item in timeline.items) '${item.title} ${item.body}',
      ].join(' ').toLowerCase();

      expect(joined, contains('may help'));
      expect(
        joined,
        anyOf(contains('may have helped'), contains('may have softened')),
      );
      expect(joined, isNot(contains('proven')));
      expect(joined, isNot(contains('fixed')));
      expect(joined, isNot(contains('healed')));
    });

    test(
      'trigger payoff priority test still passes with timeline milestones',
      () {
        EarlyEvidenceMilestoneStore.useTestFlags = true;
        EarlyEvidenceMilestoneStore.testTriggerCaptured = true;
        EarlyEvidenceMilestoneStore.testHelpfulActionCaptured = true;

        final timeline = EarlyEvidenceTimelineEngine.build(
          entries: _fourEntriesWithTriggerCapture(),
          triggerCapturedMilestone: true,
          helpfulActionCapturedMilestone: true,
        );

        expect(
          timeline!.items.any(
            (item) =>
                item.kind == EarlyEvidenceTimelineItemKind.triggerCaptured,
          ),
          isTrue,
        );
        expect(
          timeline.items.any(
            (item) => item.kind == EarlyEvidenceTimelineItemKind.helpfulAction,
          ),
          isFalse,
        );
      },
    );
  });

  group('EarlyEvidenceTimelineCard', () {
    testWidgets('full card shows chip trail and evidence chain labels', (
      tester,
    ) async {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fiveEntriesWithHelpfulActionCapture(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EarlyEvidenceTimelineCard(timeline: timeline!)),
        ),
      );
      await tester.pump();

      expect(find.text('Your archive is building evidence.'), findsOneWidget);
      expect(find.textContaining('tracking'), findsOneWidget);
      expect(
        find.byKey(const Key('early_evidence_timeline_chip_trail')),
        findsOneWidget,
      );
      expect(find.text('Repeat'), findsWidgets);
      expect(find.text('Change'), findsWidgets);
      expect(find.text('Helped'), findsWidgets);
      expect(find.text('Repeat confirmed'), findsOneWidget);
      expect(find.text('Helpful action captured'), findsOneWidget);
    });

    testWidgets('compact card hides subtitle and chip trail', (tester) async {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fourEntriesWithSofterRelatedReturn(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyEvidenceTimelineCard(timeline: timeline!, compact: true),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('early_evidence_timeline_chip_trail')),
        findsNothing,
      );
      expect(
        find.text(
          'ArchiveMe is tracking what repeats, what starts it, and what may help '
          'it soften.',
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('early_evidence_timeline_row_chip_softerReturn')),
        findsOneWidget,
      );
      expect(find.text('Change'), findsOneWidget);
    });
  });

  group('EarlyFirstSignalRecordRoutes', () {
    test(
      'trigger and helpful routes support autostart for Patterns handoff',
      () {
        expect(
          EarlyFirstSignalRecordRoutes.routeWithTriggerPrompt(autostart: true),
          contains('autostart=1'),
        );
        expect(
          EarlyFirstSignalRecordRoutes.routeWithTriggerPrompt(autostart: true),
          contains(
            Uri.encodeComponent(EarlyFirstSignalCopy.recordTriggerGuidedPrompt),
          ),
        );
        expect(
          EarlyFirstSignalRecordRoutes.routeWithWhatHelpedPrompt(
            autostart: true,
          ),
          contains('autostart=1'),
        );
        expect(
          EarlyFirstSignalRecordRoutes.routeWithWhatHelpedPrompt(
            autostart: true,
          ),
          contains(
            Uri.encodeComponent(
              EarlyFirstSignalCopy.recordWhatHelpedGuidedPrompt,
            ),
          ),
        );
      },
    );
  });

  group('FirstUserJourney hardening', () {
    setUp(() async {
      await AppServices.resetForTest(
        journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
        prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
        skipRevenueCat: true,
      );
    });

    Future<void> saveRelatedRepeatEntries() async {
      for (final entry in _threeRelatedRepeatEntries()) {
        await AppServices.instance.journalStore.save(entry);
      }
    }

    test(
      'three related entries show timeline on Patterns not duplicate early card',
      () async {
        await saveRelatedRepeatEntries();

        final loaded = await AppServices.instance.journalStore.loadAll();
        expect(loaded.length, 3);

        final timeline = EarlyEvidenceTimelineEngine.build(entries: loaded);
        expect(timeline, isNotNull);

        final earlySignal = EarlyFirstSignalEngine.build(entries: loaded);
        expect(
          earlySignal?.kind,
          EarlyFirstSignalKind.threeEntryConfirmedRepeat,
        );
        expect(
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(loaded),
          isTrue,
        );
      },
    );

    test(
      'patterns early proof scaffold eligible at three confirmed entries',
      () {
        final entries = _threeRelatedRepeatEntries();
        expect(
          FirstSessionCoordinator.shouldShowMinimalPatterns(
            reflectionCount: entries.length,
          ),
          isFalse,
        );
        expect(entries.length >= 3 && entries.length <= 5, isTrue);
        expect(
          EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
          isTrue,
        );
        expect(EarlyEvidenceTimelineEngine.build(entries: entries), isNotNull);
      },
    );

    test(
      'Record compact timeline gate keeps early signal card at three entries',
      () {
        expect(
          RecordEmptyArchiveGates.showEarlyFirstSignalCard(
            loaded: true,
            entryCount: 3,
            isPostSave: false,
          ),
          isTrue,
        );
        expect(
          RecordEmptyArchiveGates.showEarlyEvidenceTimelineCompact(
            loaded: true,
            entryCount: 3,
            isPostSave: false,
          ),
          isFalse,
        );
        expect(
          RecordEmptyArchiveGates.showEarlyEvidenceTimelineCompact(
            loaded: true,
            entryCount: 4,
            isPostSave: false,
          ),
          isTrue,
        );
      },
    );
  });

  group('EarlyEvidenceTimelineDemo', () {
    test('can show CTA on empty and one entry only', () {
      expect(
        EarlyEvidenceTimelineDemo.canShowCta(
          entryCount: 0,
          hasRealTimeline: false,
        ),
        isTrue,
      );
      expect(
        EarlyEvidenceTimelineDemo.canShowCta(
          entryCount: 1,
          hasRealTimeline: false,
        ),
        isTrue,
      );
      expect(
        EarlyEvidenceTimelineDemo.canShowCta(
          entryCount: 2,
          hasRealTimeline: false,
        ),
        isFalse,
      );
    });

    test('real timeline takes priority over demo CTA', () {
      expect(
        EarlyEvidenceTimelineDemo.canShowCta(
          entryCount: 0,
          hasRealTimeline: true,
        ),
        isFalse,
      );
      expect(
        EarlyEvidenceTimelineDemo.canShowCta(
          entryCount: 1,
          hasRealTimeline: true,
        ),
        isFalse,
      );

      final realTimeline = EarlyEvidenceTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(realTimeline, isNotNull);
      expect(
        EarlyEvidenceTimelineDemo.canShowCta(
          entryCount: 3,
          hasRealTimeline: realTimeline != null,
        ),
        isFalse,
      );
    });

    test('sample timeline uses example copy and all four items', () {
      final timeline = EarlyEvidenceTimelineDemo.timeline;

      expect(timeline.title, EarlyEvidenceTimelineDemoCopy.title);
      expect(timeline.title.toLowerCase(), contains('example'));
      expect(timeline.subtitle.toLowerCase(), contains('sample'));
      expect(timeline.items, hasLength(4));
      expect(timeline.items.map((item) => item.kind), [
        EarlyEvidenceTimelineItemKind.repeatConfirmed,
        EarlyEvidenceTimelineItemKind.triggerCaptured,
        EarlyEvidenceTimelineItemKind.softerReturn,
        EarlyEvidenceTimelineItemKind.helpfulAction,
      ]);
    });

    testWidgets('empty Patterns footer shows demo CTA', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PatternsEmptyView(
              footer: [
                EarlyEvidenceTimelineDemoCta(
                  onTap: _noop,
                  entryCount: 0,
                  surface: 'patterns',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('See how ArchiveMe works'), findsOneWidget);
      expect(find.byKey(const Key('early_evidence_demo_cta')), findsOneWidget);
    });

    testWidgets('tapping demo CTA shows labelled sample timeline', (
      tester,
    ) async {
      var demoVisible = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: demoVisible
                    ? EarlyEvidenceTimelineDemoSection(
                        onHide: () => setState(() => demoVisible = false),
                        entryCount: 0,
                        surface: 'patterns',
                      )
                    : EarlyEvidenceTimelineDemoCta(
                        onTap: () => setState(() => demoVisible = true),
                        entryCount: 0,
                        surface: 'patterns',
                      ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('early_evidence_demo_cta')));
      await tester.pump();

      expect(
        find.byKey(const Key('early_evidence_demo_section')),
        findsOneWidget,
      );
      expect(find.text('Sample'), findsOneWidget);
      expect(find.text(EarlyEvidenceTimelineDemoCopy.title), findsOneWidget);
      expect(find.text(EarlyEvidenceTimelineDemoCopy.subtitle), findsOneWidget);
    });

    test('demo preview does not write journal entries', () async {
      await AppServices.resetForTest(
        journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
        prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
        skipRevenueCat: true,
      );

      expect(await AppServices.instance.journalStore.loadAll(), isEmpty);

      // Showing demo is static — no save side effects.
      expect(EarlyEvidenceTimelineDemo.timeline.items, isNotEmpty);

      expect(await AppServices.instance.journalStore.loadAll(), isEmpty);
    });
  });

  group('EarlyArchiveProofAnalytics', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      EarlyArchiveProofAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    List<String> eventsNamed(String name) =>
        captured.where((e) => e.event == name).map((e) => e.event).toList();

    testWidgets('demo CTA seen dedupes on rebuild', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyEvidenceTimelineDemoCta(
              onTap: () {},
              entryCount: 0,
              surface: 'patterns',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyEvidenceTimelineDemoCta(
              onTap: () {},
              entryCount: 0,
              surface: 'patterns',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        eventsNamed(EarlyArchiveProofAnalytics.demoCtaSeenEvent),
        hasLength(1),
      );
      expect(captured.single.properties['entry_count'], 0);
      expect(captured.single.properties['source'], 'patterns');
    });

    test('timeline seen marks session for pro after timeline', () {
      EarlyArchiveProofAnalytics.timelineSeen(
        entryCount: 4,
        surface: 'patterns',
        milestoneCount: 2,
        hasRealTimeline: true,
      );
      expect(EarlyArchiveProofAnalytics.realTimelineSeenThisSession, isTrue);

      EarlyArchiveProofAnalytics.proScreenOpenedAfterTimeline(
        source: 'paywall_screen',
      );
      expect(
        eventsNamed(
          EarlyArchiveProofAnalytics.proScreenOpenedAfterTimelineEvent,
        ),
        hasLength(1),
      );
    });

    test('payloads omit transcript-like content', () {
      EarlyArchiveProofAnalytics.confirmedRepeatSeen(
        entryCount: 3,
        surface: 'patterns',
      );
      final joined = captured
          .expand((e) => e.properties.values)
          .map((v) => v.toString())
          .join(' ')
          .toLowerCase();
      expect(joined, isNot(contains('transcript')));
      expect(joined, isNot(contains('said yes')));
    });
  });

  group('EarlyArchiveInsightQualityEngine', () {
    test('checking uncertainty entries produce specific repeat summary', () {
      final insight = EarlyArchiveInsightQualityEngine.build(
        entries: _threeCheckingUncertaintyEntries(),
      );

      expect(insight.repeatSummary, isNotNull);
      expect(
        insight.repeatSummary,
        contains('checking when things feel uncertain'),
      );
      _expectNoDiagnosticLanguage(insight.repeatSummary!);
    });

    test('trigger capture entry produces cautious trigger summary', () {
      final insight = EarlyArchiveInsightQualityEngine.build(
        entries: _fourEntriesWithTriggerCapture(),
      );

      expect(insight.triggerSummary, isNotNull);
      expect(insight.triggerSummary, contains('trigger seems to be'));
      _expectNoDiagnosticLanguage(insight.triggerSummary!);
    });

    test('softer entry produces less urgent style copy', () {
      final insight = EarlyArchiveInsightQualityEngine.build(
        entries: _fourEntriesWithSofterRelatedReturn(),
      );

      expect(insight.softeningSummary, isNotNull);
      expect(insight.softeningSummary!.toLowerCase(), contains('less urgent'));
      _expectNoDiagnosticLanguage(insight.softeningSummary!);
    });

    test('helpful action entry produces may have helped summary', () {
      final insight = EarlyArchiveInsightQualityEngine.build(
        entries: _fiveEntriesWithWaitingHelpfulAction(),
      );

      expect(insight.helpfulActionSummary, isNotNull);
      expect(
        insight.helpfulActionSummary,
        anyOf(contains('may have helped'), contains('may have softened')),
      );
      _expectNoDiagnosticLanguage(insight.helpfulActionSummary!);
    });

    test('unrelated entries fall back without fake insight', () {
      final entries = [
        _entry(
          id: 'e1',
          transcript: 'A quiet moment about lunch with a friend today.',
          createdAt: DateTime(2026, 6, 10, 12),
        ),
        _entry(
          id: 'e2',
          transcript: 'Another unrelated note about errands this afternoon.',
          createdAt: DateTime(2026, 6, 11, 12),
        ),
        _entry(
          id: 'e3',
          transcript: 'Weather was nice on my walk through the park today.',
          createdAt: DateTime(2026, 6, 12, 12),
        ),
      ];

      final insight = EarlyArchiveInsightQualityEngine.build(entries: entries);
      expect(insight.repeatSummary, isNull);
      expect(EarlyEvidenceTimelineEngine.build(entries: entries), isNull);
    });

    test('integrated summaries avoid diagnostic and overclaim language', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fiveEntriesWithHelpfulActionCapture(),
      );
      final joined = [
        timeline!.subtitle,
        for (final item in timeline.items) '${item.title} ${item.body}',
      ].join(' ');

      _expectNoDiagnosticLanguage(joined);
      expect(joined.toLowerCase(), isNot(contains('proves')));
    });
  });

  group('EarlyArchiveInsightFeedback', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() async {
      await AppServices.resetForTest(
        journalPath: '/tmp/vm_early_feedback_journal.json',
        prefsPath: '/tmp/vm_early_feedback_prefs.json',
      );
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      await EarlyArchiveInsightFeedbackStore.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    testWidgets('feedback row renders on timeline card', (tester) async {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyEvidenceTimelineCard(
              timeline: timeline!,
              analyticsSurface: 'patterns',
              entryCount: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('early_archive_insight_feedback_row_timeline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_archive_insight_feedback_feels_right')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_archive_insight_feedback_not_quite')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_archive_insight_feedback_wrong_pattern')),
        findsOneWidget,
      );
    });

    testWidgets('feedback row renders on confirmed repeat card', (
      tester,
    ) async {
      final model = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyFirstSignalCard(
                signal: model!,
                onPrimary: _noop,
                analyticsSurface: 'patterns',
                entryCount: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(
          const Key('early_archive_insight_feedback_row_confirmedRepeat'),
        ),
        findsOneWidget,
      );
    });

    test('analytics records safe metadata without private text', () {
      EarlyArchiveInsightFeedbackAnalytics.record(
        insightType: EarlyArchiveInsightType.timeline,
        value: EarlyArchiveInsightFeedbackValue.feelsRight,
        entryCount: 3,
        surface: 'patterns',
      );

      expect(captured, hasLength(1));
      expect(
        captured.single.event,
        EarlyArchiveInsightFeedbackAnalytics.feedbackEvent,
      );
      expect(captured.single.properties['entry_count'], 3);
      expect(captured.single.properties['source'], 'patterns');
      expect(captured.single.properties['stage'], 'timeline');
      expect(captured.single.properties['reason'], 'feels_right');

      final joined = captured.single.properties.values
          .map((value) => value.toString())
          .join(' ')
          .toLowerCase();
      expect(joined, isNot(contains('transcript')));
      expect(joined, isNot(contains('said yes')));
    });

    testWidgets('wrong pattern shows uncertainty acknowledgement', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyArchiveInsightFeedbackRow(
              insightType: EarlyArchiveInsightType.confirmedRepeat,
              surface: 'record',
              entryCount: 3,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(
        find.byKey(const Key('early_archive_insight_feedback_wrong_pattern')),
      );
      await tester.pump();

      expect(
        find.text(EarlyArchiveInsightFeedbackCopy.wrongPatternAcknowledgement),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('early_archive_insight_feedback_ack_wrongPattern'),
        ),
        findsOneWidget,
      );
      expect(captured, hasLength(1));
      expect(captured.single.properties['reason'], 'wrong_pattern');
    });

    testWidgets('demo timeline does not show feedback row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyEvidenceTimelineCard(
              timeline: EarlyEvidenceTimelineDemo.timeline,
              isSample: true,
              analyticsSurface: 'patterns',
              entryCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('early_archive_insight_feedback_row_timeline')),
        findsNothing,
      );
    });
  });

  group('EarlyArchiveInsightWhy', () {
    test('engine returns grounded repeat reasons for confirmed repeat', () {
      final reasons = EarlyArchiveInsightQualityEngine.whyReasonsFor(
        insightType: EarlyArchiveInsightType.confirmedRepeat,
        entries: _threeRelatedRepeatEntries(),
      );

      expect(reasons, isNotEmpty);
      expect(reasons.first, 'Seen across 3 entries.');
      expect(
        reasons.any((reason) => reason.contains('Your words repeated')),
        isTrue,
      );
      _expectNoDiagnosticLanguage(reasons.join(' '));
    });

    test('engine hides trigger reason without trigger evidence', () {
      final reasons = EarlyArchiveInsightQualityEngine.whyReasonsFor(
        insightType: EarlyArchiveInsightType.triggerPayoff,
        entries: _threeRelatedRepeatEntries(),
      );

      expect(reasons, isEmpty);
    });

    test('engine adds trigger reason when trigger evidence exists', () {
      final reasons = EarlyArchiveInsightQualityEngine.whyReasonsFor(
        insightType: EarlyArchiveInsightType.triggerPayoff,
        entries: _fourEntriesWithTriggerCapture(),
      );

      expect(reasons, contains(EarlyArchiveInsightWhyCopy.triggerInLaterEntry));
      _expectNoDiagnosticLanguage(reasons.join(' '));
    });

    test('timeline reasons include softening and helpful when present', () {
      final reasons = EarlyArchiveInsightQualityEngine.whyReasonsFor(
        insightType: EarlyArchiveInsightType.timeline,
        entries: _fiveEntriesWithHelpfulActionCapture(),
      );

      expect(reasons, contains(EarlyArchiveInsightWhyCopy.latestLessUrgent));
      expect(reasons, contains(EarlyArchiveInsightWhyCopy.helpfulActionOnce));
      _expectNoDiagnosticLanguage(reasons.join(' '));
    });

    test('softening notice reasons stay hidden without softening evidence', () {
      final reasons = EarlyArchiveInsightQualityEngine.whyReasonsFor(
        insightType: EarlyArchiveInsightType.softeningNotice,
        entries: _fourEntriesWithNormalRelatedReturn(),
      );

      expect(reasons, isEmpty);
    });

    testWidgets('why link appears on confirmed repeat card', (tester) async {
      final model = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyFirstSignalCard(
                signal: model!,
                onPrimary: _noop,
                analyticsSurface: 'patterns',
                entryCount: 3,
                entriesForWhy: _threeRelatedRepeatEntries(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(EarlyArchiveInsightWhyCopy.linkLabel), findsOneWidget);
      expect(
        find.byKey(const Key('early_archive_insight_why_link_confirmedRepeat')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('early_archive_insight_why_reason_confirmedRepeat_0'),
        ),
        findsNothing,
      );
    });

    testWidgets('expanding why shows grounded evidence reasons', (
      tester,
    ) async {
      final entries = _fiveEntriesWithHelpfulActionCapture();
      final timeline = EarlyEvidenceTimelineEngine.build(entries: entries);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyEvidenceTimelineCard(
                timeline: timeline!,
                analyticsSurface: 'record',
                entryCount: 5,
                entriesForWhy: entries,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('early_archive_insight_why_link_timeline')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(EarlyArchiveInsightWhyCopy.latestLessUrgent),
        findsOneWidget,
      );
      expect(find.textContaining('Seen across'), findsOneWidget);
      _expectNoDiagnosticLanguage(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data ?? '')
            .join(' '),
      );
    });

    testWidgets('why link hidden without entriesForWhy', (tester) async {
      final model = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EarlyFirstSignalCard(
                signal: model!,
                onPrimary: _noop,
                analyticsSurface: 'patterns',
                entryCount: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(EarlyArchiveInsightWhyCopy.linkLabel), findsNothing);
    });

    testWidgets('trigger payoff shows why when trigger evidence exists', (
      tester,
    ) async {
      final payoff = EarlyFirstSignalEngine.buildTriggerCapturePayoff(
        entries: _fourEntriesWithTriggerCapture(),
        savedFromTriggerPrompt: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatTriggerPayoffCard(
              payoff: payoff!,
              onKeepWatching: () {},
              onViewEvidence: () {},
              analyticsSurface: 'record',
              entryCount: 4,
              entriesForWhy: _fourEntriesWithTriggerCapture(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(EarlyArchiveInsightWhyCopy.linkLabel), findsOneWidget);
    });

    testWidgets('helpful action payoff expands helpful reason', (tester) async {
      final payoff = EarlyFirstSignalEngine.buildHelpfulActionPayoff(
        entries: _fiveEntriesWithHelpfulActionCapture(),
        savedFromHelpfulActionPrompt: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatHelpfulActionPayoffCard(
              payoff: payoff!,
              onKeepWatching: () {},
              onViewEvidence: () {},
              analyticsSurface: 'record',
              entryCount: 5,
              entriesForWhy: _fiveEntriesWithHelpfulActionCapture(),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const Key('early_archive_insight_why_link_helpfulActionPayoff'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(EarlyArchiveInsightWhyCopy.helpfulActionOnce),
        findsOneWidget,
      );
    });
  });

  group('EarlyArchiveReturnReminder', () {
    tearDown(() {
      EarlyArchiveReturnReminderSession.resetForTest();
      CheckInReminderService.resetBackendForTest();
    });

    test('gates allow reminder after confirmed repeat / timeline', () {
      final entries = _threeRelatedRepeatEntries();
      expect(
        EarlyArchiveReturnReminderGates.eligible(
          entryCount: 3,
          entries: entries,
          hasRealTimeline: true,
        ),
        isTrue,
      );
      expect(
        EarlyArchiveReturnReminderGates.eligible(
          entryCount: 3,
          entries: entries,
          hasRealTimeline: false,
        ),
        isTrue,
      );
    });

    test('gates block reminder before confirmed repeat', () {
      final twoEntries = _threeRelatedRepeatEntries().sublist(0, 2);
      expect(
        EarlyArchiveReturnReminderGates.eligible(
          entryCount: 2,
          entries: twoEntries,
          hasRealTimeline: false,
        ),
        isFalse,
      );
      expect(
        EarlyArchiveReturnReminderGates.eligible(
          entryCount: 1,
          entries: twoEntries.sublist(0, 1),
          hasRealTimeline: false,
        ),
        isFalse,
      );
    });

    test('not now hides reminder for the day', () async {
      await AppServices.resetForTest(
        journalPath: '/tmp/vm_return_reminder_journal.json',
        prefsPath: '/tmp/vm_return_reminder_prefs.json',
      );
      await EarlyArchiveReturnReminderStore.resetForTest(
        AppServices.instance.prefs,
      );

      expect(
        await EarlyArchiveReturnReminderStore.instance().shouldOffer(),
        isTrue,
      );
      await EarlyArchiveReturnReminderStore.instance().markNotNow();
      expect(
        await EarlyArchiveReturnReminderStore.instance().shouldOffer(),
        isFalse,
      );
    });

    test('session dismiss hides reminder until reset', () async {
      await AppServices.resetForTest(
        journalPath: '/tmp/vm_return_reminder_session_journal.json',
        prefsPath: '/tmp/vm_return_reminder_session_prefs.json',
      );
      await EarlyArchiveReturnReminderStore.resetForTest(
        AppServices.instance.prefs,
      );

      EarlyArchiveReturnReminderSession.dismiss();
      expect(
        await EarlyArchiveReturnReminderStore.instance().shouldOffer(),
        isFalse,
      );
    });

    testWidgets('reminder card shows calm copy and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EarlyArchiveReturnReminderCard(
              source: 'patterns',
              onDismiss: _noop,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(EarlyArchiveReturnReminderCopy.title), findsOneWidget);
      expect(find.text(EarlyArchiveReturnReminderCopy.body), findsOneWidget);
      expect(
        find.text(EarlyArchiveReturnReminderCopy.primaryCta),
        findsOneWidget,
      );
      expect(
        find.text(EarlyArchiveReturnReminderCopy.secondaryCta),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_archive_return_reminder_card_patterns')),
        findsOneWidget,
      );
    });

    testWidgets('only one reminder with timeline card in column', (
      tester,
    ) async {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  EarlyEvidenceTimelineCard(timeline: timeline!),
                  EarlyArchiveReturnReminderCard(
                    source: 'patterns',
                    onDismiss: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('early_evidence_timeline_card_full')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('early_archive_return_reminder_card_patterns')),
        findsOneWidget,
      );
      expect(find.text(EarlyArchiveReturnReminderCopy.title), findsOneWidget);
    });

    test('schedule uses existing reminder backend safely', () async {
      await AppServices.resetForTest(
        journalPath: '/tmp/vm_return_reminder_schedule_journal.json',
        prefsPath: '/tmp/vm_return_reminder_schedule_prefs.json',
      );
      await EarlyArchiveReturnReminderStore.resetForTest(
        AppServices.instance.prefs,
      );

      final backend = _ReturnReminderFakeBackend();
      CheckInReminderService.setBackendForTest(backend);

      final outcome = await EarlyArchiveReturnReminderService.schedule();
      expect(outcome, ReminderScheduleOutcome.scheduled);
      expect(backend.scheduleCalls, 1);
      expect(backend.lastTitle, EarlyArchiveReturnReminderCopy.title);
      expect(
        await EarlyArchiveReturnReminderStore.instance().shouldOffer(),
        isFalse,
      );
    });
  });

  group('ConfirmedRepeatWhyMatters', () {
    setUp(() async {
      await AppServices.resetForTest(
        journalPath:
            '${DateTime.now().microsecondsSinceEpoch}_why_matters_journal.json',
        prefsPath:
            '${DateTime.now().microsecondsSinceEpoch}_why_matters_prefs.json',
        skipRevenueCat: true,
      );
      await ConfirmedRepeatWhyMattersStore.resetForTest();
    });

    test('copy avoids therapy and diagnostic language', () {
      final lines = [
        ConfirmedRepeatWhyMattersCopy.title,
        ConfirmedRepeatWhyMattersCopy.body,
        ConfirmedRepeatWhyMattersCopy.hideCta,
      ];
      final copy = lines.join(' ');
      _expectNoDiagnosticLanguage(copy);
      for (final line in lines) {
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('"$line": $reason');
        }
      }
      expect(copy.toLowerCase(), isNot(contains('diagnose')));
      expect(copy.toLowerCase(), isNot(contains('therapy')));
      expect(copy.toLowerCase(), isNot(contains('heal')));
      expect(copy.toLowerCase(), isNot(contains('treat')));
    });

    test('gates hide before confirmed repeat and while recording', () {
      expect(
        ConfirmedRepeatWhyMattersGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeat: true,
          entryCount: 2,
          isReady: true,
          isRecording: false,
          dismissed: false,
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatWhyMattersGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeat: false,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          dismissed: false,
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatWhyMattersGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeat: true,
          entryCount: 3,
          isReady: true,
          isRecording: true,
          dismissed: false,
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatWhyMattersGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeat: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          dismissed: false,
        ),
        isTrue,
      );
    });

    test(
      'proof stack includes why matters without duplicating proof phrases',
      () {
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
        final joined = blocks.join('\n');

        expect(blocks, contains(ConfirmedRepeatWhyMattersCopy.title));
        expect(blocks, contains(ConfirmedRepeatWhyMattersCopy.body));
        expect(
          ArchiveProofCopyDedup.phrasesWithinLimit(
            copyBlocks: blocks,
            onceOnlyPhrases: [
              EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
              EarlyFirstSignalCopy.evidenceHeading,
              ConfirmedRepeatWhyMattersCopy.title,
            ],
          ),
          isTrue,
        );
        expect(
          ArchiveProofCopyDedup.countPhrase(
            joined,
            EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
          ),
          1,
        );
        expect(
          ConfirmedRepeatWhyMattersCopy.body,
          isNot(contains(EarlyFirstSignalCopy.evidenceHeading)),
        );
      },
    );

    testWidgets('card renders below proof copy and dismiss persists', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatWhyMattersCard.test(
              store: ConfirmedRepeatWhyMattersStore(AppServices.instance.prefs),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('confirmed_repeat_why_matters_card')),
        findsOneWidget,
      );
      expect(find.text(ConfirmedRepeatWhyMattersCopy.title), findsOneWidget);
      expect(find.text(ConfirmedRepeatWhyMattersCopy.body), findsOneWidget);
      expect(find.text(EarlyFirstSignalCopy.evidenceHeading), findsNothing);
      expect(
        find.byKey(const Key('early_first_signal_primary_cta')),
        findsNothing,
      );

      await tester.tap(find.text(ConfirmedRepeatWhyMattersCopy.hideCta));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await ConfirmedRepeatWhyMattersStore.ensureLoaded();
      });
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('confirmed_repeat_why_matters_card_hidden')),
        findsOneWidget,
      );
      expect(ConfirmedRepeatWhyMattersStore.cachedDismissed, isTrue);
    });
  });

  group('ConfirmedRepeatThoughtMap', () {
    setUp(() async {
      await AppServices.resetForTest(
        journalPath:
            '${DateTime.now().microsecondsSinceEpoch}_thought_map_journal.json',
        prefsPath:
            '${DateTime.now().microsecondsSinceEpoch}_thought_map_prefs.json',
        skipRevenueCat: true,
      );
      await ConfirmedRepeatThoughtMapStore.resetForTest();
      ConfirmedRepeatThoughtMapAnalytics.resetForTest();
    });

    test('copy avoids therapy and diagnostic language', () {
      final lines = [
        ConfirmedRepeatThoughtMapCopy.title,
        ConfirmedRepeatThoughtMapCopy.triggerLabel,
        ConfirmedRepeatThoughtMapCopy.triggerQuestion,
        ConfirmedRepeatThoughtMapCopy.triggerUnknown,
        ConfirmedRepeatThoughtMapCopy.thoughtLabel,
        ConfirmedRepeatThoughtMapCopy.thoughtQuestion,
        ConfirmedRepeatThoughtMapCopy.thoughtUnknown,
        ConfirmedRepeatThoughtMapCopy.actionLabel,
        ConfirmedRepeatThoughtMapCopy.actionQuestion,
        ConfirmedRepeatThoughtMapCopy.actionUnknown,
        ConfirmedRepeatThoughtMapCopy.resultLabel,
        ConfirmedRepeatThoughtMapCopy.resultQuestion,
        ConfirmedRepeatThoughtMapCopy.resultUnknown,
        ConfirmedRepeatThoughtMapCopy.recordMissingPieceCta,
      ];
      final copy = lines.join(' ');
      _expectNoDiagnosticLanguage(copy);
      for (final line in lines) {
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('"$line": $reason');
        }
      }
      expect(copy.toLowerCase(), isNot(contains('diagnose')));
      expect(copy.toLowerCase(), isNot(contains('therapy')));
      expect(copy.toLowerCase(), isNot(contains('heal')));
      expect(copy.toLowerCase(), isNot(contains('treat')));
    });

    test('gates hide before confirmed repeat and while recording', () {
      expect(
        ConfirmedRepeatThoughtMapGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeatOrTimeline: true,
          entryCount: 2,
          isReady: true,
          isRecording: false,
          hasThoughtMap: true,
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatThoughtMapGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeatOrTimeline: false,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          hasThoughtMap: true,
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatThoughtMapGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeatOrTimeline: true,
          entryCount: 3,
          isReady: true,
          isRecording: true,
          hasThoughtMap: true,
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatThoughtMapGates.shouldShow(
          loaded: true,
          viewingConfirmedRepeatOrTimeline: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          hasThoughtMap: true,
        ),
        isTrue,
      );
    });

    test('engine returns null without confirmed repeat foundation', () {
      expect(
        ConfirmedRepeatThoughtMapEngine.build(
          entries: _threeRelatedRepeatEntries().sublist(0, 2),
        ),
        isNull,
      );
    });

    test('engine uses evidence phrases and honest prompts for unknowns', () {
      final map = ConfirmedRepeatThoughtMapEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(map, isNotNull);
      expect(map!.title, ConfirmedRepeatThoughtMapCopy.title);

      final trigger = map.sections.firstWhere(
        (section) => section.id == ThoughtMapSectionId.trigger,
      );
      final thought = map.sections.firstWhere(
        (section) => section.id == ThoughtMapSectionId.thought,
      );
      expect(trigger.isKnown, isFalse);
      expect(trigger.displayText, ConfirmedRepeatThoughtMapCopy.triggerUnknown);
      expect(thought.isKnown, isTrue);
      expect(thought.displayText, contains('"'));
      expect(map.firstMissingSection, ThoughtMapSectionId.trigger);
    });

    test('engine fills trigger when milestone captured', () {
      final map = ConfirmedRepeatThoughtMapEngine.build(
        entries: _fourEntriesWithTriggerCapture(),
        triggerCapturedMilestone: true,
      );
      expect(map, isNotNull);
      final trigger = map!.sections.firstWhere(
        (section) => section.id == ThoughtMapSectionId.trigger,
      );
      expect(trigger.isKnown, isTrue);
    });

    test('record missing piece CTA hides when capture primary is visible', () {
      expect(
        ConfirmedRepeatThoughtMapGates.showRecordMissingPieceCta(
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
      expect(
        ConfirmedRepeatThoughtMapGates.showRecordMissingPieceCta(
          policy: const RecordCtaPolicyResolution(
            state: RecordCtaPolicyState.returning,
            primaryLabel: 'Continue',
            showMainBottomCta: false,
            action: RecordCtaAction.startRecording,
          ),
          hideCardRecordButtons: false,
          promoteMicCaptureActions: true,
        ),
        isTrue,
      );
    });

    test('analytics omits transcript text', () {
      Map<String, Object>? captured;
      ConfirmedRepeatThoughtMapAnalytics.captureForTest = (event, props) {
        captured = props;
      };
      ConfirmedRepeatThoughtMapAnalytics.recordMissingPieceTapped(
        section: ThoughtMapSectionId.trigger,
        surface: 'record',
        entryCount: 3,
      );
      expect(captured, isNotNull);
      expect(
        captured!.keys,
        containsAll(['section', 'surface', 'entry_count']),
      );
      expect(captured!.keys, isNot(contains('transcript')));
      expect(
        captured!.values.whereType<String>(),
        everyElement(isNot(contains('said yes'))),
      );
    });

    test('store persists section id only', () async {
      await ConfirmedRepeatThoughtMapStore.instance().markMissingPieceTarget(
        ThoughtMapSectionId.action,
      );
      expect(
        ConfirmedRepeatThoughtMapStore.cachedLastMissingSection,
        ThoughtMapSectionId.action.name,
      );
    });

    testWidgets('card renders loop sections and subtle record CTA', (
      tester,
    ) async {
      final map = ConfirmedRepeatThoughtMapEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(map, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatThoughtMapCard(
              result: map!,
              showRecordMissingPieceCta: true,
              onRecordMissingPiece: () {},
            ),
          ),
        ),
      );

      expect(find.text(ConfirmedRepeatThoughtMapCopy.title), findsOneWidget);
      expect(
        find.text(ConfirmedRepeatThoughtMapCopy.triggerLabel),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatThoughtMapCopy.thoughtLabel),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatThoughtMapCopy.actionLabel),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatThoughtMapCopy.resultLabel),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatThoughtMapCopy.triggerUnknown),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatThoughtMapCopy.recordMissingPieceCta),
        findsOneWidget,
      );
    });

    test('proof stack keeps thought map title distinct', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        whyMattersVisible: true,
        thoughtMapVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );
      expect(blocks, contains(ConfirmedRepeatThoughtMapCopy.title));
      expect(
        blocks.where((block) => block == ConfirmedRepeatThoughtMapCopy.title),
        hasLength(1),
      );
    });
  });
}

class _ReturnReminderFakeBackend implements CheckInReminderBackend {
  int scheduleCalls = 0;
  String? lastTitle;

  @override
  bool get isAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduleCalls++;
    lastTitle = title;
  }

  @override
  Future<void> cancel(String checkInId) async {}

  @override
  Future<void> clearAll() async {}
}

void _noop() {}
