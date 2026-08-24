import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/memory/cross_thread_confirmation.dart';
import 'package:archiveme_mobile/features/memory/entry_memory_mode.dart';
import 'package:archiveme_mobile/features/memory/memory_authority_framing_engine.dart';
import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_control_store.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_decision.dart';
import 'package:archiveme_mobile/features/memory/memory_priority_governance.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/next_entry_fresh_mode.dart';
import 'package:archiveme_mobile/features/memory/treat_as_new.dart';
import 'package:archiveme_mobile/features/memory/wrong_thread_feedback.dart';
import 'package:archiveme_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/weekly_thread_review_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/features/recording/recording_screen.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/memory/memory_used_indicator.dart';
import 'package:archiveme_mobile/widgets/memory/treat_as_new_control.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/belief_distance_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/weekly_thread_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
import 'support/expand_advanced_save_options.dart';
import 'support/memory_pressure_stores.dart';
import 'support/test_storage_sandbox.dart';

const _threadEngine = ThreadReturnEvidenceEngine();
const _weeklyEngine = WeeklyThreadReviewEngine();
const _beliefEngine = BeliefDistanceEngine();

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

List<_Event> _eventsNamed(String name) =>
    _events.where((e) => e.name == name).toList();

JournalEntry _entry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 11, 9),
  transcript:
      transcript ?? 'A long enough transcript to count as a saved reflection.',
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: 'signal',
  ),
);

PressureCheckInRecord _rec({
  required String id,
  required int daysAgo,
  List<String> contexts = const ['work'],
  String? fear,
  bool treatAsNew = false,
}) => PressureCheckInRecord(
  entryId: id,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo, hours: 1)),
  optionId: 'could_not_stop',
  contextIds: contexts,
  fear: fear,
  treatAsNew: treatAsNew,
);

/// Engine-grade evidence: a work thread with repeated language across days.
List<PressureCheckInRecord> _evidenceRecords({bool treatAsNew = false}) => [
  _rec(
    id: 'e1',
    daysAgo: 6,
    fear: 'I keep circling the same work decision',
    treatAsNew: treatAsNew,
  ),
  _rec(
    id: 'e2',
    daysAgo: 3,
    fear: 'The same work decision came back today',
    treatAsNew: treatAsNew,
  ),
  _rec(
    id: 'e3',
    daysAgo: 0,
    fear: 'Circling the same work decision tonight',
    treatAsNew: treatAsNew,
  ),
];

void _resetMemoryState() {
  MemoryScopePolicy.resetForTest();
  MemoryControlStore.resetSessionForTest();
  MemoryConnectionRules.resetForTest();
  WrongThreadFeedback.resetForTest();
  CrossThreadConfirmation.resetForTest();
  NextEntryFreshMode.resetForTest();
  MemoryAuthorityFrameLog.resetForTest();
  MemoryPriorityGovernance.resetForTest();
}

Future<void> _pumpRecordWithEntries(
  WidgetTester tester, {
  int entries = 1,
}) async {
  if (entries > 0) {
    await tester.runAsync(() async {
      for (var i = 0; i < entries; i++) {
        await AppServices.instance.journalStore.save(_entry('seed$i'));
      }
    });
  }
  VisualAuditOverrides.setRecordPresentation(
    const RecordAuditPresentation(ui: RecordUiState.ready),
  );
  addTearDown(() => VisualAuditOverrides.setRecordPresentation(null));
  await tester.binding.setSurfaceSize(const Size(390, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(withAppProviderScope(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RecordScreen(
          suggestionAttributionStore: MemorySuggestionAttributionStore(),
          entitlementReader: FakeArchiveEntitlementReader(pro: false),
        ),
      ),
    )));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  await tester.binding.setSurfaceSize(const Size(390, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(withAppProviderScope(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: card)),
    )));
  await tester.pump();
}

void main() {
  setUp(() {
    _events.clear();
    _resetMemoryState();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
    TreatAsNew.resetSessionForTest();
    MemoryControlStore.resetSessionForTest();
  });

  tearDown(() {
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    TreatAsNew.resetSessionForTest();
    MemoryControlStore.resetSessionForTest();
  });

  group('Treat this as new', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(journalPath: sandbox.journalPath);
    });

    tearDown(() => sandbox.dispose());

    testWidgets('appears on the record screen before save', (tester) async {
      await _pumpRecordWithEntries(tester);

      await expandAdvancedSaveOptions(tester);

      expect(
        find.byKey(const Key('entry_memory_scope_picker')),
        findsOneWidget,
      );
      expect(find.text(EntryMemoryModeCopy.treatAsNewLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('default is off and tapping toggles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TreatAsNewControl())),
      );
      expect(TreatAsNew.selectedForNextSave, isFalse);

      await tester.tap(find.byKey(const Key('treat_as_new_control')));
      await tester.pump();
      expect(TreatAsNew.selectedForNextSave, isTrue);
      expect(find.text(TreatAsNew.expandedHelper), findsOneWidget);

      await tester.tap(find.byKey(const Key('treat_as_new_control')));
      await tester.pump();
      expect(TreatAsNew.selectedForNextSave, isFalse);
    });

    test('selected save writes the safe metadata flag', () async {
      final store = AppServices.instance.journalStore;
      TreatAsNew.selectedForNextSave = true;
      await store.save(_entry('fresh1', transcript: 'Untouched words.'));

      final all = await store.loadAll();
      final saved = all.singleWhere((e) => e.id == 'fresh1');
      expect(saved.treatAsNew, isTrue);
      expect(saved.transcript, 'Untouched words.');
      expect(TreatAsNew.lastSaveWasFresh, isTrue);
    });

    test('unselected save does not write the flag', () async {
      final store = AppServices.instance.journalStore;
      await store.save(_entry('plain1'));

      final all = await store.loadAll();
      expect(all.singleWhere((e) => e.id == 'plain1').treatAsNew, isFalse);
      expect(TreatAsNew.lastSaveWasFresh, isFalse);
    });

    test('post-save fresh copy state appears only when selected', () async {
      final store = AppServices.instance.journalStore;
      TreatAsNew.selectedForNextSave = true;
      await store.save(_entry('fresh2'));
      expect(TreatAsNew.lastSaveWasFresh, isTrue);

      await store.save(_entry('plain2'));
      expect(TreatAsNew.lastSaveWasFresh, isFalse);
    });

    test('fresh entries still appear in the archive', () async {
      final store = AppServices.instance.journalStore;
      TreatAsNew.selectedForNextSave = true;
      await store.save(_entry('fresh3'));
      await store.save(_entry('plain3'));

      final all = await store.loadAll();
      expect(all.map((e) => e.id), containsAll(['fresh3', 'plain3']));
    });
  });

  group('Engine exclusion', () {
    test('thread return evidence ignores fresh entries', () {
      expect(
        _threadEngine.build(_evidenceRecords(treatAsNew: true)).hasEvidence,
        isFalse,
      );
    });

    test('weekly review makes no claims from fresh entries alone', () {
      expect(
        _weeklyEngine.build(_evidenceRecords(treatAsNew: true)).hasReview,
        isFalse,
      );
    });

    test('belief distance makes no claim from fresh entries alone', () {
      expect(
        _beliefEngine.build(_evidenceRecords(treatAsNew: true)).hasBelief,
        isFalse,
      );
    });

    test('existing non-fresh evidence still works', () {
      final records = _evidenceRecords();
      expect(_threadEngine.build(records).hasEvidence, isTrue);
      expect(_weeklyEngine.build(records).hasReview, isTrue);
      expect(_beliefEngine.build(records).hasBelief, isTrue);
    });
  });

  group('Not related', () {
    testWidgets('suppresses only that card for the session', (tester) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('memory_connection_actions_thread_return')),
          matching: find.text(MemoryControlCopy.notRelatedLabel),
        ),
      );
      await tester.pump();
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.threadReturn),
        isTrue,
      );

      // Next build of the surface: the connection is suppressed.
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsNothing,
      );

      // Other memory cards are untouched — no global disable.
      final belief = _beliefEngine.build(_evidenceRecords());
      await _pumpCard(tester, BeliefDistanceCard(belief: belief));
      expect(find.byKey(const Key('belief_distance_card')), findsOneWidget);

      final marked = _eventsNamed(
        ActivationFunnelAnalytics.memoryMarkedNotRelated,
      );
      expect(marked, hasLength(1));
      expect(marked.single.properties['card_type'], 'thread_return');
    });

    testWidgets('works on belief distance and weekly review cards', (
      tester,
    ) async {
      final belief = _beliefEngine.build(_evidenceRecords());
      await _pumpCard(tester, BeliefDistanceCard(belief: belief));
      await tester.tap(
        find.descendant(
          of: find.byKey(
            const Key('memory_connection_actions_belief_distance'),
          ),
          matching: find.text(MemoryControlCopy.notRelatedLabel),
        ),
      );
      await tester.pump();
      await _pumpCard(tester, BeliefDistanceCard(belief: belief));
      expect(find.byKey(const Key('belief_distance_card')), findsNothing);

      final review = _weeklyEngine.build(_evidenceRecords());
      await _pumpCard(tester, WeeklyThreadReviewCard(review: review));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('memory_connection_actions_weekly_review')),
          matching: find.text(MemoryControlCopy.notRelatedLabel),
        ),
      );
      await tester.pump();
      await _pumpCard(tester, WeeklyThreadReviewCard(review: review));
      expect(find.byKey(const Key('weekly_thread_review_card')), findsNothing);
    });

    test('marks nothing in storage — entries and history are untouched', () {
      MemoryControlStore.markNotRelated(MemoryCardType.threadReturn);
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.threadReturn),
        isTrue,
      );
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.beliefDistance),
        isFalse,
      );
      // Session-scoped only: a fresh session starts clean.
      MemoryControlStore.resetSessionForTest();
      expect(
        MemoryControlStore.isSuppressed(MemoryCardType.threadReturn),
        isFalse,
      );
    });
  });

  group('Why this appeared', () {
    testWidgets('opens the high-level sheet from a memory card', (
      tester,
    ) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));

      await tester.tap(
        find.byKey(const Key('memory_used_receipt_why_thread_return')),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(const Key('memory_priority_explanation_sheet'));
      expect(sheet, findsOneWidget);
      // The action label shares the title text, so scope to the sheet.
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(MemoryControlCopy.whyTitle),
        ),
        findsOneWidget,
      );
      expect(find.text(MemoryControlCopy.whyBodyShared), findsOneWidget);
      expect(find.text(MemoryControlCopy.whyCorrectionFooter), findsOneWidget);

      final opened = _eventsNamed(
        ActivationFunnelAnalytics.memoryUsedReceiptOpened,
      );
      expect(opened, hasLength(1));
      expect(opened.single.properties['card_type'], 'thread_return');
    });

    testWidgets('sheet contains no raw notes, snippets, dates, or entry ids', (
      tester,
    ) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      await tester.tap(
        find.byKey(const Key('memory_used_receipt_why_thread_return')),
      );
      await tester.pumpAndSettle();

      // Every text inside the sheet must be one of the fixed constants.
      final sheetTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('memory_priority_explanation_sheet')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .toList();
      expect(sheetTexts, isNotEmpty);
      const allowed = {
        MemoryControlCopy.whyTitle,
        MemoryPriorityCopy.explainRecentRelated,
        MemoryControlCopy.whyBodyShared,
        MemoryControlCopy.whyCorrectionFooter,
      };
      for (final text in sheetTexts) {
        expect(
          allowed.contains(text) ||
              text.startsWith('Used because') ||
              text.startsWith('ArchiveMe found') ||
              text.startsWith('ArchiveMe is comparing') ||
              text.startsWith('ArchiveMe noticed'),
          isTrue,
          reason: 'unexpected sheet text: $text',
        );
        expect(text.contains('work decision'), isFalse);
        expect(text.contains('e1'), isFalse);
        expect(RegExp(r'\d{4}').hasMatch(text), isFalse);
      }
    });

    testWidgets('body variant matches the card type', (tester) async {
      final belief = _beliefEngine.build(_evidenceRecords());
      await _pumpCard(tester, BeliefDistanceCard(belief: belief));
      await tester.tap(
        find.byKey(const Key('memory_used_receipt_why_belief_distance')),
      );
      await tester.pumpAndSettle();
      expect(find.text(MemoryControlCopy.whyBodyShared), findsOneWidget);
      expect(find.text(MemoryControlCopy.whyBodyThreadReturn), findsNothing);
    });
  });

  group('Memory used indicator', () {
    testWidgets('receipt appears on connected insight cards', (tester) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      expect(find.byKey(const Key('memory_used_receipt')), findsOneWidget);
      expect(
        find.text(MemoryControlCopy.usedArchiveContextLabel),
        findsOneWidget,
      );
      expect(find.text(MemoryControlCopy.savedAsNewLabel), findsNothing);

      final seen = _eventsNamed(
        ActivationFunnelAnalytics.memoryUsedReceiptSeen,
      );
      expect(seen, hasLength(1));
    });

    testWidgets('does not appear on a counting-only weekly review', (
      tester,
    ) async {
      const review = WeeklyThreadReview(
        hasReview: true,
        title: 'This week in your archive',
        weekSummaryLine: 'A quiet week.',
        evidenceLine: 'You added 2 pieces of evidence this week.',
        nextWeekLine: 'One calm thing to look at next week.',
      );
      await _pumpCard(tester, const WeeklyThreadReviewCard(review: review));
      expect(
        find.byKey(const Key('weekly_thread_review_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('memory_used_receipt')), findsNothing);
      expect(
        find.byKey(const Key('memory_connection_actions_weekly_review')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('memory_used_receipt_why_weekly_review')),
        findsNothing,
      );
    });

    testWidgets('saved-as-new variant appears only for the fresh-save state', (
      tester,
    ) async {
      await _pumpCard(tester, const FreshEntrySavedReceipt());
      expect(find.byKey(const Key('saved_as_new_indicator')), findsOneWidget);
      expect(find.text(MemoryControlCopy.savedAsNewLabel), findsOneWidget);
      expect(find.byKey(const Key('memory_used_indicator')), findsNothing);
      expect(find.text(MemoryControlCopy.memoryUsedLabel), findsNothing);

      final seen = _eventsNamed(
        ActivationFunnelAnalytics.memoryUsedIndicatorSeen,
      );
      expect(seen, hasLength(1));
      expect(seen.single.properties['connection_mode'], 'fresh');
    });

    testWidgets('standalone indicator renders both modes', (tester) async {
      await _pumpCard(
        tester,
        const MemoryUsedIndicator(connected: true, source: 'thread_return'),
      );
      expect(find.text(MemoryControlCopy.memoryUsedLabel), findsOneWidget);

      await _pumpCard(
        tester,
        const MemoryUsedIndicator(connected: false, source: 'record_post_save'),
      );
      expect(find.text(MemoryControlCopy.savedAsNewLabel), findsOneWidget);
    });
  });

  group('Analytics privacy', () {
    testWidgets('payloads carry only whitelisted, safe properties', (
      tester,
    ) async {
      final evidence = _threadEngine.build(_evidenceRecords());
      await _pumpCard(tester, ThreadReturnEvidenceCard(evidence: evidence));
      await tester.tap(
        find.byKey(const Key('memory_used_receipt_why_thread_return')),
      );
      await tester.pumpAndSettle();
      // Close the sheet so the not-related action is reachable.
      Navigator.of(
        tester.element(
          find.byKey(const Key('memory_priority_explanation_sheet')),
        ),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(MemoryControlCopy.notRelatedLabel));
      await tester.pump();

      const memoryEvents = {
        'treat_as_new_seen',
        'treat_as_new_selected',
        'treat_as_new_saved',
        'memory_marked_not_related',
        'memory_used_receipt_seen',
        'memory_used_receipt_opened',
      };
      final relevant = _events
          .where((e) => memoryEvents.contains(e.name))
          .toList();
      expect(relevant, isNotEmpty);
      const allowedKeys = {
        'entry_count',
        'enabled',
        'card_type',
        'connection_mode',
        'source',
      };
      final safeValue = RegExp(r'^[a-z0-9_]{1,40}$');
      for (final event in relevant) {
        for (final entry in event.properties.entries) {
          expect(
            allowedKeys.contains(entry.key),
            isTrue,
            reason: 'unexpected property ${entry.key} on ${event.name}',
          );
          final value = entry.value;
          if (value is String) {
            expect(
              safeValue.hasMatch(value),
              isTrue,
              reason: 'unsafe value "$value" on ${event.name}',
            );
            expect(value.contains('decision'), isFalse);
          } else {
            expect(value, isA<int>());
          }
        }
      }
    });
  });

  group('Copy guardrails', () {
    const allCopy = [
      MemoryControlCopy.notRelatedLabel,
      MemoryControlCopy.notRelatedThanks,
      MemoryControlCopy.whyLabel,
      MemoryControlCopy.whyTitle,
      MemoryControlCopy.whyBodyThreadReturn,
      MemoryControlCopy.whyBodyWeeklyReview,
      MemoryControlCopy.whyBodyBeliefDistance,
      MemoryControlCopy.whyFooter,
      MemoryControlCopy.memoryUsedLabel,
      MemoryControlCopy.savedAsNewLabel,
      TreatAsNew.controlLabel,
      TreatAsNew.helper,
      TreatAsNew.expandedHelper,
      TreatAsNew.postSaveTitle,
      TreatAsNew.postSaveBody,
    ];

    test('expected exact copy', () {
      expect(MemoryControlCopy.notRelatedLabel, 'Not related');
      expect(
        MemoryControlCopy.notRelatedThanks,
        'Thanks — ArchiveMe will treat this as separate.',
      );
      expect(MemoryControlCopy.whyTitle, 'Why this appeared');
      expect(
        MemoryControlCopy.whyBodyThreadReturn,
        'ArchiveMe found enough evidence to compare this with earlier '
        'entries.',
      );
      expect(
        MemoryControlCopy.whyBodyWeeklyReview,
        'ArchiveMe is comparing entries from this week with earlier '
        'evidence.',
      );
      expect(
        MemoryControlCopy.whyBodyBeliefDistance,
        'ArchiveMe noticed that a belief-like phrase may be changing over '
        'time.',
      );
      expect(
        MemoryControlCopy.whyFooter,
        MemoryControlCopy.whyCorrectionFooter,
      );
      expect(MemoryControlCopy.usedArchiveContextLabel, 'Used archive context');
      expect(MemoryControlCopy.savedAsNewLabel, 'Saved as new');
    });

    test('no VoiceMemory in consumer copy', () {
      final flat = allCopy.join(' ').toLowerCase();
      expect(flat, isNot(contains('voicememory')));
      expect(flat, isNot(contains('voice memory')));
    });

    test('banned-word sweep', () {
      final flat = allCopy.join(' ').toLowerCase();
      for (final banned in const [
        'always',
        'never',
        'proves',
        'definitely',
        'diagnosis',
        'diagnose',
        'therapy',
        'treatment',
        'fixed',
        'broken',
        'problem',
        'failure',
        'lazy',
        'weak',
        'must',
        'should',
      ]) {
        expect(
          RegExp('\\b$banned\\b').hasMatch(flat),
          isFalse,
          reason: 'copy may not contain "$banned"',
        );
      }
    });
  });
}