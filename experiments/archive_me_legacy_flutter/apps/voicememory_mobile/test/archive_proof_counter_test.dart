import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/pressure_retention/archive_proof_counter_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/archive_proof_counter_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/archive_proof_counter_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/value_accuracy_feedback_row.dart';

import 'support/memory_pressure_stores.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment',
  );
}

/// Three work-context entries — a genuinely connected thread.
List<PressureCheckInRecord> _workThread3() => [
  _record(id: 'a', daysAgo: 7, contextIds: const ['work']),
  _record(
    id: 'b',
    daysAgo: 3,
    contextIds: const ['work'],
    fear: 'The deadline slipping',
  ),
  _record(
    id: 'c',
    daysAgo: 0,
    contextIds: const ['work'],
    fear: 'I kept checking messages after I wanted to stop.',
  ),
];

/// Two related entries — the minimum connected thread.
List<PressureCheckInRecord> _workThread2() => [
  _record(id: 'a', daysAgo: 5, contextIds: const ['work']),
  _record(id: 'b', daysAgo: 0, contextIds: const ['work']),
];

/// Entries with no overlap: different options, no contexts, no notes.
List<PressureCheckInRecord> _unrelatedRecords() => [
  _record(id: 'u0', daysAgo: 2, optionId: 'could_not_stop'),
  _record(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
  _record(id: 'u2', daysAgo: 0, optionId: 'had_to_prove_enough'),
];

String _allCopy(ArchiveProofCounter counter) => [
  counter.connectedLine,
  counter.threadReturnLine,
  counter.readinessLine,
  counter.onePieceLine,
  ArchiveProofCounter.enoughEvidenceLine,
  ArchiveProofCounter.onePieceTodayLine,
].join(' ');

void main() {
  const engine = ArchiveProofCounterEngine();

  group('Archive proof counter engine — eligibility', () {
    test('no proof counter before evidence', () {
      expect(engine.build(const [], now: _base).hasProof, isFalse);
      expect(
        engine.build([
          _record(id: 'a', contextIds: const ['work']),
        ], now: _base).hasProof,
        isFalse,
      );
      // Multiple unconnected entries are not proof of connection.
      expect(engine.build(_unrelatedRecords(), now: _base).hasProof, isFalse);
    });

    test(
      'post-save without a connected thread shows only the one-piece line',
      () {
        final counter = engine.build(
          _unrelatedRecords(),
          savedToday: true,
          now: _base,
        );
        expect(counter.hasProof, isTrue);
        expect(counter.onePieceLine, 'You added one more piece today.');
        // No fabricated connection counts.
        expect(counter.connectedLine, isEmpty);
        expect(counter.threadReturnLine, isEmpty);
        expect(counter.readinessLine, isEmpty);
        expect(counter.connectedCount, 0);
        expect(counter.threadReturnCount, 0);
        expect(counter.entryIds, isEmpty);
      },
    );

    test('post-save with an empty archive shows nothing', () {
      expect(
        engine.build(const [], savedToday: true, now: _base).hasProof,
        isFalse,
      );
    });
  });

  group('Archive proof counter engine — counts', () {
    test('connected recording count is correct', () {
      final counter = engine.build(_workThread3(), now: _base);
      expect(counter.hasProof, isTrue);
      expect(counter.connectedCount, 3);
      expect(counter.connectedLine, 'Your archive has 3 connected recordings.');
    });

    test('thread return count is appearances after the first', () {
      final three = engine.build(_workThread3(), now: _base);
      expect(three.threadReturnCount, 2);
      expect(three.threadReturnLine, 'This thread has returned 2 times.');

      final two = engine.build(_workThread2(), now: _base);
      expect(two.threadReturnCount, 1);
      expect(two.threadReturnLine, 'This thread has returned 1 time.');
    });

    test('counts come from the same thread evidence — never fabricated', () {
      const threadEngine = ThreadReturnEvidenceEngine();
      for (final records in [_workThread2(), _workThread3()]) {
        final counter = engine.build(records, now: _base);
        final evidence = threadEngine.build(records, now: _base);
        expect(counter.connectedCount, evidence.occurrenceCount);
        expect(counter.entryIds, evidence.entryIds);
        expect(counter.entryIds.length, counter.connectedCount);
        expect(counter.connectedCount, lessThanOrEqualTo(records.length));
        // Every counted entry is a real saved entry.
        final realIds = records.map((r) => r.entryId).toSet();
        for (final id in counter.entryIds) {
          expect(realIds, contains(id));
        }
      }
    });

    test('readiness line appears only with a connected thread', () {
      expect(
        engine.build(_workThread2(), now: _base).readinessLine,
        ArchiveProofCounter.enoughEvidenceLine,
      );
      expect(
        engine
            .build(_unrelatedRecords(), savedToday: true, now: _base)
            .readinessLine,
        isEmpty,
      );
    });

    test('one-piece line appears only right after a save', () {
      expect(engine.build(_workThread3(), now: _base).onePieceLine, isEmpty);
      expect(
        engine.build(_workThread3(), savedToday: true, now: _base).onePieceLine,
        ArchiveProofCounter.onePieceTodayLine,
      );
    });
  });

  group('Archive proof counter — language guardrails', () {
    final variants = [
      engine.build(_workThread3(), savedToday: true, now: _base),
      engine.build(_workThread3(), now: _base),
      engine.build(_workThread2(), now: _base),
      engine.build(_unrelatedRecords(), savedToday: true, now: _base),
    ];

    test('no streak, pressure, or banned words in any copy', () {
      for (final counter in variants) {
        final copy = _allCopy(counter).toLowerCase();
        for (final banned in const [
          'streak',
          'task',
          'homework',
          'must',
          'should',
          'fix',
          'problem',
          'failure',
          'lazy',
          'weak',
          'diagnose',
          'definitely',
          'resolved',
          'keep it up',
          'don\u2019t break',
        ]) {
          expect(
            copy,
            isNot(contains(banned)),
            reason: 'proof copy must not contain "$banned"',
          );
        }
      }
    });

    test('no VoiceMemory in any consumer copy', () {
      for (final counter in variants) {
        expect(_allCopy(counter), isNot(contains('VoiceMemory')));
      }
    });
  });

  group('Archive proof counter card', () {
    testWidgets('renders all proof lines after a saved thread entry', (
      tester,
    ) async {
      final counter = engine.build(
        _workThread3(),
        savedToday: true,
        now: _base,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveProofCounterCard(counter: counter),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('archive_proof_counter_card')),
        findsOneWidget,
      );
      expect(
        find.text('Your archive has 3 connected recordings.'),
        findsOneWidget,
      );
      expect(find.text('This thread has returned 2 times.'), findsOneWidget);
      expect(
        find.text('ArchiveMe now has enough evidence to compare tomorrow.'),
        findsOneWidget,
      );
      expect(find.text('You added one more piece today.'), findsOneWidget);
      // Compact, passive proof: no buttons, no CTAs.
      expect(
        find.byWidgetPredicate((w) => w is ButtonStyleButton),
        findsNothing,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('renders nothing without proof', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveProofCounterCard(counter: ArchiveProofCounter.none()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('archive_proof_counter_card')), findsNothing);
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('shows the proof counter without hiding existing cards', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 5200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: _workThread3(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final proofCard = find.byKey(const Key('archive_proof_counter_card'));
      final threadCard = find.byKey(const Key('thread_return_evidence_card'));
      expect(proofCard, findsOneWidget);
      // Existing evidence cards still render below the compact counter.
      expect(threadCard, findsOneWidget);
      expect(
        tester.getTopLeft(proofCard).dy,
        lessThan(tester.getTopLeft(threadCard).dy),
      );
      // Insights never shows the post-save line — that belongs to Record.
      expect(find.text('You added one more piece today.'), findsNothing);
    });

    testWidgets('no proof counter when nothing connects', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 5200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: _unrelatedRecords(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('archive_proof_counter_card')), findsNothing);
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_archive_proof_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    testWidgets('no proof counter before anything is saved', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: MemoryPressureCheckInStore(_workThread3()),
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('archive_proof_counter_card')), findsNothing);
      expect(find.text('You added one more piece today.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Value accuracy feedback — proof counter card', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    List<({String event, Map<String, Object> properties})> feedbackEvents() =>
        captured
            .where(
              (e) =>
                  e.event == ActivationFunnelAnalytics.valueFeedbackUseful ||
                  e.event == ActivationFunnelAnalytics.valueFeedbackNotQuite,
            )
            .toList();

    Future<void> pumpCard(
      WidgetTester tester,
      ArchiveProofCounter counter,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveProofCounterCard(counter: counter),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('feedback row renders only with a connected thread', (
      tester,
    ) async {
      await pumpCard(tester, engine.build(_workThread3(), now: _base));
      expect(find.text(ValueAccuracyFeedbackRow.question), findsOneWidget);
    });

    testWidgets('no feedback row in the minimal one-piece state', (
      tester,
    ) async {
      await pumpCard(
        tester,
        engine.build(_unrelatedRecords(), savedToday: true, now: _base),
      );
      expect(
        find.byKey(const Key('archive_proof_counter_card')),
        findsOneWidget,
      );
      expect(find.text(ValueAccuracyFeedbackRow.question), findsNothing);
    });

    testWidgets('Yes logs with counts only — no card text', (tester) async {
      await pumpCard(tester, engine.build(_workThread3(), now: _base));
      await tester.tap(
        find.byKey(const Key('value_feedback_yes_archive_proof_counter')),
      );
      await tester.pump();

      expect(find.text(ValueAccuracyFeedbackRow.yesThanksLine), findsOneWidget);
      // The optional testimonial ask follows a useful rating.
      expect(
        find.byKey(const Key('value_testimonial_ask_archive_proof_counter')),
        findsOneWidget,
      );
      final events = feedbackEvents();
      expect(events, hasLength(1));
      expect(events.single.properties, {
        'card_type': 'archive_proof_counter',
        'entry_count': 3,
        'has_connected_thread': 1,
      });
    });

    testWidgets('one tap disables duplicate feedback', (tester) async {
      await pumpCard(tester, engine.build(_workThread3(), now: _base));
      await tester.tap(
        find.byKey(const Key('value_feedback_not_quite_archive_proof_counter')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('value_feedback_yes_archive_proof_counter')),
        findsNothing,
      );
      expect(feedbackEvents(), hasLength(1));
    });
  });
}
