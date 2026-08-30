import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/activation/belief_update_payoff.dart';
import 'package:archiveme_mobile/features/activation/third_entry_belief_payoff.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_copy.dart';
import 'package:archiveme_mobile/features/post_save/post_save_recorded_summary_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/analysis_fallback_payoff.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/screens/record_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/belief_update_payoff_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/app_services_test_lifecycle.dart';
import 'support/test_storage_sandbox.dart';
import 'support/v1_moment_save_receipt_expectations.dart';

JournalEntry _voiceEntry({
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

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
  durationSeconds: 20,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRepeatCapacityEntries() => [
  _voiceEntry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _voiceEntry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _voiceEntry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _fourRepeatCapacityEntries() => [
  ..._threeRepeatCapacityEntries(),
  _voiceEntry(
    id: 'e4',
    transcript:
        'The same yes-with-no-capacity pattern showed up again at work today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

List<JournalEntry> _fourDistinctWorkEntries() => [
  _voiceEntry(
    id: 'e1',
    transcript:
        'I felt pressure at work before saying yes again even when I was tired.',
    createdAt: DateTime(2026, 6, 9, 12),
  ),
  _voiceEntry(
    id: 'e2',
    transcript:
        'Work kept pulling me back after I wanted to stop for the day at the office.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _voiceEntry(
    id: 'e3',
    transcript:
        'I noticed the same hurry showing up before I answered anyone at work.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _voiceEntry(
    id: 'e4',
    transcript:
        'The deadline pressure returned again during the morning meeting at work.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

const _bannedCertaintyWords = [
  'you always',
  'diagnosis',
  'therapy',
  'pattern found',
  'certain',
  'must come back',
  'streak',
  'guilt',
];

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

void _expectNoBannedCopy(Iterable<String> visible, List<String> banned) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in banned) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  group('BeliefUpdatePayoffEngine', () {
    test('returns null below four usable entries', () {
      expect(
        BeliefUpdatePayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript: 'I felt pressure before saying yes again today.',
            ),
          ],
        ),
        isNull,
      );
      expect(
        BeliefUpdatePayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript: 'I felt pressure before saying yes again today.',
            ),
            _voiceEntry(
              id: 'e2',
              transcript: 'My sister called about planning the weekend trip.',
            ),
          ],
        ),
        isNull,
      );
      expect(
        BeliefUpdatePayoffEngine.build(
          entries: [
            _voiceEntry(
              id: 'e1',
              transcript:
                  'I felt pressure before saying yes again even when I was tired.',
            ),
            _voiceEntry(
              id: 'e2',
              transcript:
                  'Work kept pulling me back after I wanted to stop for the day.',
            ),
            _voiceEntry(
              id: 'e3',
              transcript:
                  'I noticed the same hurry showing up before I answered anyone.',
            ),
          ],
        ),
        isNull,
      );
      expect(
        ThirdEntryBeliefPayoffEngine.build(
          entries: _threeRepeatCapacityEntries(),
        ),
        isNotNull,
      );
    });

    test('four usable entries can show belief update title', () {
      final payoff = BeliefUpdatePayoffEngine.build(
        entries: _fourDistinctWorkEntries(),
      );

      expect(payoff, isNotNull);
      expect(payoff!.title, VisibleArchiveProofCopy.beliefUpdateTitle);
      expect(payoff.evidenceRows.length, greaterThanOrEqualTo(2));
      expect(payoff.primaryCta, 'Record if it happens again');
      expect(payoff.secondaryCta, 'View evidence');
      _expectNoBannedCopy([
        payoff.title,
        payoff.body,
        payoff.currentBelief,
        payoff.whatChangedLine,
        ...payoff.evidenceRows,
      ], _bannedCertaintyWords);
    });

    test('weak duplicate four-entry evidence shows still building copy', () {
      const shared =
          'I felt pressure at work before saying yes again even when I was tired.';
      final payoff = BeliefUpdatePayoffEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript: shared,
            createdAt: DateTime(2026, 6, 9),
          ),
          _voiceEntry(
            id: 'e2',
            transcript: shared,
            createdAt: DateTime(2026, 6, 10),
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'I noticed the same hurry showing up before I answered anyone at work.',
            createdAt: DateTime(2026, 6, 11),
          ),
          _voiceEntry(
            id: 'e4',
            transcript:
                'The deadline pressure returned, but I caught it earlier this time.',
            createdAt: DateTime(2026, 6, 12),
          ),
        ],
      );

      expect(payoff, isNotNull);
      expect(payoff!.evidenceWeak, isTrue);
      expect(payoff.beliefChanged, isFalse);
      expect(
        payoff.body,
        VisibleArchiveProofCopy.beliefUpdateBodyStillBuilding,
      );
      expect(
        payoff.whatChangedLine,
        VisibleArchiveProofCopy.beliefUpdateChangeEasierCompare,
      );
    });

    test('degraded entries do not count toward belief update', () {
      final entries = [
        ..._fourDistinctWorkEntries().sublist(0, 3),
        _degradedVoiceEntry(id: 'e4'),
      ];
      expect(BeliefUpdatePayoffEngine.build(entries: entries), isNull);
    });

    test('analysis unavailable still allows local belief update payoff', () {
      final payoff = BeliefUpdatePayoffEngine.build(
        entries: _fourDistinctWorkEntries(),
        analysisSucceeded: false,
      );

      expect(payoff, isNotNull);
      expect(payoff!.footnoteLine, contains('This moment is saved'));
      expect(
        AnalysisFallbackPayoffEngine.build(
          entries: _fourDistinctWorkEntries(),
          analysisSucceeded: false,
        ),
        isNull,
      );
    });
  });

  group('BeliefUpdatePayoffCard', () {
    testWidgets('renders belief update sections and CTAs', (tester) async {
      const payoff = BeliefUpdatePayoff(
        title: BeliefUpdatePayoffCopy.title,
        body: BeliefUpdatePayoffCopy.bodyChanged,
        currentBelief: VisibleArchiveProofCopy.beliefUpdateWorkBelief,
        evidenceRows: [
          'I felt pressure at work before saying yes again even when I was tired.',
          'Work kept pulling me back after I wanted to stop for the day at the office.',
        ],
        whatChangedLine: VisibleArchiveProofCopy.beliefUpdateChangeNewContext,
        beliefChanged: true,
        evidenceWeak: false,
        primaryCta: BeliefUpdatePayoffCopy.primaryCta,
        secondaryCta: BeliefUpdatePayoffCopy.secondaryCta,
      );

      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeliefUpdatePayoffCard(
                payoff: payoff,
                onAddAnother: () {},
                onViewEvidence: () {},
              ),
            ),
          ),
        )));
      await tester.pump();

      expect(
        find.byKey(const Key('belief_update_payoff_card')),
        findsOneWidget,
      );
      expect(find.text(BeliefUpdatePayoffCopy.title), findsOneWidget);
      expect(
        find.text(BeliefUpdatePayoffCopy.currentBeliefLabel),
        findsOneWidget,
      );
      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('What changed'), findsOneWidget);
      expect(find.text('Record if it happens again'), findsOneWidget);
      expect(find.text('View evidence'), findsNWidgets(2));
      expect(
        find.byKey(const Key('belief_update_payoff_evidence_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('belief_update_payoff_evidence_1')),
        findsOneWidget,
      );
      _expectNoBannedCopy(_visibleText(tester), _bannedCertaintyWords);
    });
  });

  group('RecordScreen belief update payoff', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(
        journalPath: sandbox.journalPath,
        skipRevenueCat: true,
      );
    });

    tearDown(() async {
      await settleAppServicesForTest();
      sandbox.dispose();
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpDoneState(
      WidgetTester tester, {
      required List<JournalEntry> entriesAfterSave,
      bool lastCaptureAnalysisSucceeded = true,
    }) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: entriesAfterSave,
          lastCaptureAnalysisSucceeded: lastCaptureAnalysisSucceeded,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        )));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('three repeated entries show one primary discovery result', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: _threeRepeatCapacityEntries(),
      );

      expect(
        find.byKey(const Key('post_save_archive_home_nudge_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('third_entry_belief_payoff_card')),
        findsNothing,
      );
      expect(find.byKey(const Key('belief_update_payoff_card')), findsNothing);
      expect(
        find.byKey(const Key('belief_history_timeline_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('weekly_archive_review_compact_card')),
        findsNothing,
      );
      expect(find.byKey(const Key('weekly_archive_review_card')), findsNothing);
      V1MomentSaveReceiptExpectations.expectVisible();
      V1MomentSaveReceiptExpectations.expectNoLegacyPostSaveStack();
    });

    testWidgets('four repeat entries show discovery without belief card', (
      tester,
    ) async {
      VisualAuditOverrides.setRecordPresentation(
        RecordAuditPresentation(
          ui: RecordUiState.done,
          entriesAfterSave: _fourRepeatCapacityEntries(),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(withAppProviderScope(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        )));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('belief_update_payoff_card')), findsNothing);
      V1MomentSaveReceiptExpectations.expectVisible();
      V1MomentSaveReceiptExpectations.expectNoLegacyPostSaveStack();
    });

    testWidgets('two unrelated entries keep focused post-save actions', (
      tester,
    ) async {
      await pumpDoneState(
        tester,
        entriesAfterSave: [
          _voiceEntry(
            id: 'e1',
            transcript: 'A quiet moment about lunch with a friend today.',
            createdAt: DateTime(2026, 6, 11, 12),
          ),
          _voiceEntry(
            id: 'e2',
            transcript: 'Another unrelated note about errands this afternoon.',
            createdAt: DateTime(2026, 6, 12, 12),
          ),
        ],
      );

      V1MomentSaveReceiptExpectations.expectVisible();
      V1MomentSaveReceiptExpectations.expectNoLegacyPostSaveStack();
      expect(V1MomentSaveReceiptExpectations.recordAnother, findsOneWidget);
      expect(V1MomentSaveReceiptExpectations.viewArchive, findsOneWidget);
    });
  });
}