import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_model.dart';
import 'package:voicememory_mobile/features/feedback/value_testimonial_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/value_accuracy_feedback_row.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
  String? stopCostNote,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    stopCostNote: stopCostNote,
    transcript: 'pressure moment',
  );
}

/// Three work-context entries across 8 days, newest on the "today" base day.
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

/// Entries with no overlap at all: different options, no contexts, no notes.
List<PressureCheckInRecord> _unrelatedRecords() => [
  _record(id: 'u0', daysAgo: 2, optionId: 'could_not_stop'),
  _record(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
  _record(id: 'u2', daysAgo: 0, optionId: 'had_to_prove_enough'),
];

void main() {
  const engine = ThreadReturnEvidenceEngine();

  group('Thread return evidence engine — eligibility', () {
    test('no evidence with fewer than 2 entries', () {
      expect(engine.build(const [], now: _base).hasEvidence, isFalse);
      expect(
        engine.build([
          _record(id: 'a', contextIds: const ['work']),
        ], now: _base).hasEvidence,
        isFalse,
      );
    });

    test('no evidence when nothing overlaps across entries', () {
      final evidence = engine.build(_unrelatedRecords(), now: _base);
      expect(evidence.hasEvidence, isFalse);
      expect(evidence.evidenceSnippets, isEmpty);
      expect(evidence.entryIds, isEmpty);
    });

    test('2 related entries produce early signal language only', () {
      final evidence = engine.build([
        _record(id: 'a', daysAgo: 5, contextIds: const ['work']),
        _record(id: 'b', daysAgo: 0, contextIds: const ['work']),
      ], now: _base);

      expect(evidence.hasEvidence, isTrue);
      expect(evidence.status, ThreadReturnStatus.earlySignal);
      expect(evidence.statusLabel, 'Early signal');
      expect(evidence.headline, ThreadReturnEvidence.earlySignalHeadline);
      expect(evidence.summaryLine, contains('Too early'));
      expect(
        evidence.confidenceLabel,
        ThreadReturnEvidence.earlySignalConfidence,
      );
      // Never stronger language with only 2 occurrences.
      final copy = '${evidence.headline} ${evidence.summaryLine}'.toLowerCase();
      expect(copy, isNot(contains('returned')));
      expect(copy, isNot(contains('building')));
    });
  });

  group('Thread return evidence engine — status rules', () {
    test('3 related entries with one today produce returned language', () {
      final evidence = engine.build(_workThread3(), now: _base);

      expect(evidence.hasEvidence, isTrue);
      expect(evidence.status, ThreadReturnStatus.returned);
      expect(evidence.statusLabel, 'Returned');
      expect(evidence.headline, ThreadReturnEvidence.returnedTodayHeadline);
      expect(
        evidence.summaryLine,
        'Work pressure has appeared 3 times in 8 days.',
      );
    });

    test('repeated count, days window, and entry ids are correct', () {
      final evidence = engine.build(_workThread3(), now: _base);
      expect(evidence.occurrenceCount, 3);
      expect(evidence.daysWindow, 8);
      expect(evidence.entryIds, ['a', 'b', 'c']);
      expect(
        evidence.confidenceLabel,
        ThreadReturnEvidence.repeatedSignalConfidence,
      );
    });

    test('fading when older occurrences are stronger than recent', () {
      final evidence = engine.build([
        _record(id: 'f0', daysAgo: 8, contextIds: const ['work']),
        _record(id: 'f1', daysAgo: 7, contextIds: const ['work']),
        _record(id: 'f2', daysAgo: 6, contextIds: const ['work']),
        _record(id: 'f3', daysAgo: 1, contextIds: const ['work']),
      ], now: _base);

      expect(evidence.status, ThreadReturnStatus.fading);
      expect(evidence.statusLabel, 'May be fading');
      expect(evidence.headline, ThreadReturnEvidence.fadingHeadline);
      expect(evidence.summaryLine, contains('less often'));
      expect(evidence.summaryLine, contains('Work pressure'));
    });

    test('building when recent occurrences are increasing', () {
      final evidence = engine.build([
        _record(id: 'b0', daysAgo: 8, contextIds: const ['work']),
        _record(id: 'b1', daysAgo: 3, contextIds: const ['work']),
        _record(id: 'b2', daysAgo: 2, contextIds: const ['work']),
        _record(id: 'b3', daysAgo: 1, contextIds: const ['work']),
      ], now: _base);

      expect(evidence.status, ThreadReturnStatus.building);
      expect(evidence.statusLabel, 'Building');
      expect(evidence.headline, ThreadReturnEvidence.buildingHeadline);
      expect(evidence.occurrenceCount, 4);
      expect(evidence.daysWindow, 8);
    });
  });

  group('Thread return evidence engine — evidence integrity', () {
    test('exact snippets from the user\u2019s entries are included', () {
      final evidence = engine.build(_workThread3(), now: _base);
      expect(
        evidence.evidenceSnippets,
        contains('I kept checking messages after I wanted to stop.'),
      );
      expect(evidence.evidenceSnippets, contains('The deadline slipping'));
    });

    test('snippets are capped at 3, newest first', () {
      final evidence = engine.build([
        for (var i = 0; i < 5; i++)
          _record(
            id: 's$i',
            daysAgo: i,
            contextIds: const ['work'],
            fear: 'Unique note number $i',
          ),
      ], now: _base);

      expect(evidence.evidenceSnippets.length, 3);
      expect(evidence.evidenceSnippets, [
        'Unique note number 0',
        'Unique note number 1',
        'Unique note number 2',
      ]);
    });

    test('source terms are capped at 3', () {
      final evidence = engine.build([
        for (var i = 0; i < 3; i++)
          _record(
            id: 't$i',
            daysAgo: i,
            contextIds: const ['work', 'evening', 'deadline'],
            fear: 'Endless email checking',
          ),
      ], now: _base);

      expect(evidence.sourceTerms.length, ThreadReturnEvidence.maxTerms);
      expect(evidence.sourceTerms.length, 3);
    });

    test('no fabricated snippets — every snippet exists in the records', () {
      final records = _workThread3();
      final evidence = engine.build(records, now: _base);
      final realText = {
        for (final record in records) ...[
          if (record.fear != null) record.fear!.trim(),
          if (record.stopCostNote != null) record.stopCostNote!.trim(),
        ],
      };
      expect(evidence.evidenceSnippets, isNotEmpty);
      for (final snippet in evidence.evidenceSnippets) {
        expect(
          realText,
          contains(snippet),
          reason: 'snippet "$snippet" must come from a real entry',
        );
      }
    });

    test('entries without free text produce no snippets, never filler', () {
      final evidence = engine.build([
        _record(id: 'n0', daysAgo: 2, contextIds: const ['work']),
        _record(id: 'n1', daysAgo: 1, contextIds: const ['work']),
        _record(id: 'n2', daysAgo: 0, contextIds: const ['work']),
      ], now: _base);
      expect(evidence.hasEvidence, isTrue);
      expect(evidence.evidenceSnippets, isEmpty);
    });
  });

  group('Thread return evidence — follow-up CTA', () {
    test('returned evidence carries the record-now follow-up', () {
      final evidence = engine.build(_workThread3(), now: _base);
      expect(evidence.status, ThreadReturnStatus.returned);
      expect(evidence.followUpCtaLabel, 'Record what happened this time');
      expect(
        evidence.followUpPrompt,
        'This thread returned. What happened this time?',
      );
    });

    test('building evidence carries a follow-up CTA and prompt', () {
      final evidence = engine.build([
        _record(id: 'b0', daysAgo: 8, contextIds: const ['work']),
        _record(id: 'b1', daysAgo: 3, contextIds: const ['work']),
        _record(id: 'b2', daysAgo: 2, contextIds: const ['work']),
        _record(id: 'b3', daysAgo: 1, contextIds: const ['work']),
      ], now: _base);
      expect(evidence.status, ThreadReturnStatus.building);
      expect(evidence.followUpCtaLabel, 'Record what happened this time');
      expect(
        evidence.followUpPrompt,
        'This pattern is building. What did it make you do today?',
      );
    });

    test('fading evidence asks what felt different', () {
      final evidence = engine.build([
        _record(id: 'f0', daysAgo: 8, contextIds: const ['work']),
        _record(id: 'f1', daysAgo: 7, contextIds: const ['work']),
        _record(id: 'f2', daysAgo: 6, contextIds: const ['work']),
        _record(id: 'f3', daysAgo: 1, contextIds: const ['work']),
      ], now: _base);
      expect(evidence.status, ThreadReturnStatus.fading);
      expect(evidence.followUpCtaLabel, 'Add what felt different');
      expect(
        evidence.followUpPrompt,
        'This may be fading. What felt different this time?',
      );
    });

    test('early signal asks for another example', () {
      final evidence = engine.build([
        _record(id: 'e0', daysAgo: 5, contextIds: const ['work']),
        _record(id: 'e1', daysAgo: 0, contextIds: const ['work']),
      ], now: _base);
      expect(evidence.status, ThreadReturnStatus.earlySignal);
      expect(evidence.followUpCtaLabel, 'Add another example');
      expect(
        evidence.followUpPrompt,
        'This may be starting. What is another example?',
      );
    });

    test('no follow-up copy without evidence', () {
      final evidence = ThreadReturnEvidence.none();
      expect(evidence.followUpCtaLabel, isEmpty);
      expect(evidence.followUpPrompt, isEmpty);
    });
  });

  group('Thread return evidence — light affect labeling', () {
    test('named line uses the real thread term only', () {
      final evidence = engine.build(_workThread3(), now: _base);
      expect(evidence.namedLine, 'You named the work thread.');
      // The named term is real user evidence, not invented.
      expect(evidence.sourceTerms, contains('work'));
    });

    test('option-theme threads name the pressure, not a thread noun', () {
      // Two entries share only the "could not stop" option — the thread term
      // is the hedged theme "stopping".
      final evidence = engine.build([
        _record(id: 'o0', daysAgo: 4),
        _record(id: 'o1', daysAgo: 0),
      ], now: _base);
      expect(evidence.hasEvidence, isTrue);
      expect(evidence.namedLine, 'You named the pressure around stopping.');
    });

    test('generic fallback never claims more than adding words', () {
      expect(
        ThreadReturnEvidence.genericNamedLine,
        'You added words to something that was repeating.',
      );
    });

    test('no named line without evidence', () {
      expect(ThreadReturnEvidence.none().namedLine, isEmpty);
    });

    test('named line never makes therapeutic or resolution claims', () {
      final scenarios = [
        engine.build(_workThread3(), now: _base),
        engine.build([
          _record(id: 'o0', daysAgo: 4),
          _record(id: 'o1', daysAgo: 0),
        ], now: _base),
      ];
      for (final evidence in scenarios) {
        final line = evidence.namedLine.toLowerCase();
        for (final claim in const [
          'processed',
          'healed',
          'regulated',
          'resolved',
          'anxious',
          'this means you',
        ]) {
          expect(line, isNot(contains(claim)));
        }
      }
    });
  });

  group('Thread return evidence — language guardrails', () {
    test('no diagnostic, certainty, or shame wording in any status', () {
      final scenarios = [
        engine.build(_workThread3(), now: _base),
        engine.build([
          _record(id: 'f0', daysAgo: 8, contextIds: const ['work']),
          _record(id: 'f1', daysAgo: 7, contextIds: const ['work']),
          _record(id: 'f2', daysAgo: 6, contextIds: const ['work']),
          _record(id: 'f3', daysAgo: 1, contextIds: const ['work']),
        ], now: _base),
        engine.build([
          _record(id: 'b0', daysAgo: 8, contextIds: const ['work']),
          _record(id: 'b1', daysAgo: 3, contextIds: const ['work']),
          _record(id: 'b2', daysAgo: 2, contextIds: const ['work']),
          _record(id: 'b3', daysAgo: 1, contextIds: const ['work']),
        ], now: _base),
        engine.build([
          _record(id: 'e0', daysAgo: 5, contextIds: const ['work']),
          _record(id: 'e1', daysAgo: 0, contextIds: const ['work']),
        ], now: _base),
      ];

      for (final evidence in scenarios) {
        final copy = [
          evidence.headline,
          evidence.namedLine,
          evidence.summaryLine,
          evidence.statusLabel,
          evidence.confidenceLabel,
          evidence.followUpPrompt,
          evidence.followUpCtaLabel,
          ...evidence.sourceTerms,
          ThreadReturnEvidence.evidenceHeading,
          ThreadReturnEvidence.basedOnLine,
          ThreadReturnEvidence.genericNamedLine,
        ].join(' ').toLowerCase();
        for (final banned in const [
          'definitely',
          'always',
          'certain',
          'guaranteed',
          'proven',
          'diagnos',
          'disorder',
          'must',
          'failure',
          'lazy',
          'weak',
          'shame',
          'healed',
          'processed',
          'regulated',
          'anxious',
          'trauma',
          'cure',
          'resolved',
        ]) {
          expect(
            copy,
            isNot(contains(banned)),
            reason: 'copy must not contain "$banned"',
          );
        }
      }
    });

    test('no VoiceMemory in any consumer copy', () {
      final evidence = engine.build(_workThread3(), now: _base);
      final copy = [
        evidence.headline,
        evidence.namedLine,
        evidence.summaryLine,
        evidence.statusLabel,
        evidence.confidenceLabel,
        evidence.followUpPrompt,
        evidence.followUpCtaLabel,
        ...evidence.sourceTerms,
        ...evidence.evidenceSnippets,
        ThreadReturnEvidence.evidenceHeading,
        ThreadReturnEvidence.basedOnLine,
        ThreadReturnEvidence.genericNamedLine,
      ].join(' ');
      expect(copy, isNot(contains('VoiceMemory')));
    });
  });

  group('Thread return evidence card', () {
    testWidgets('renders headline, summary, chips, evidence, and footer', (
      tester,
    ) async {
      final evidence = engine.build(_workThread3(), now: _base);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThreadReturnEvidenceCard(evidence: evidence),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('This thread returned today'), findsOneWidget);
      expect(find.byKey(const Key('thread_return_named_line')), findsOneWidget);
      expect(find.text('You named the work thread.'), findsOneWidget);
      expect(
        find.text('Work pressure has appeared 3 times in 8 days.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('thread_return_status_chip')),
        findsOneWidget,
      );
      expect(find.text('Returned'), findsOneWidget);
      expect(find.text(evidence.confidenceLabel), findsOneWidget);
      for (final term in evidence.sourceTerms) {
        expect(find.text(term), findsOneWidget);
      }
      expect(find.text('Evidence behind this'), findsOneWidget);
      for (final snippet in evidence.evidenceSnippets) {
        expect(find.textContaining(snippet), findsOneWidget);
      }
      expect(find.text('Based on your recent archive'), findsOneWidget);
      // Follow-up CTA is visible without hiding the evidence above it.
      expect(
        find.byKey(const Key('thread_return_follow_up_cta')),
        findsOneWidget,
      );
      expect(find.text('Record what happened this time'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('tapping the CTA hands the prompt to the Record screen', (
      tester,
    ) async {
      final evidence = engine.build(_workThread3(), now: _base);
      String? capturedPrompt;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: ThreadReturnEvidenceCard(evidence: evidence),
              ),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) {
              capturedPrompt = state.uri.queryParameters['prompt'];
              return const Scaffold(body: Center(child: Text('RECORD_MARKER')));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final cta = find.byKey(const Key('thread_return_follow_up_cta'));
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('RECORD_MARKER'), findsOneWidget);
      expect(capturedPrompt, 'This thread returned. What happened this time?');
    });

    testWidgets('renders nothing without evidence', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThreadReturnEvidenceCard(
              evidence: ThreadReturnEvidence.none(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsNothing,
      );
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('renders the thread card near the top when eligible', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 4200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: [
              ..._workThread3(),
              _record(id: 'd', daysAgo: 1, contextIds: const ['work']),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('thread_return_evidence_card'));
      expect(cardFinder, findsOneWidget);

      // The follow-up CTA ships with the card on the insights screen.
      expect(
        find.byKey(const Key('thread_return_follow_up_cta')),
        findsOneWidget,
      );

      // Existing pattern reveal card is still shown, below the thread card.
      final revealFinder = find.byKey(
        const Key('pressure_pattern_reveal_card'),
      );
      expect(revealFinder, findsOneWidget);
      expect(
        tester.getTopLeft(cardFinder).dy,
        lessThan(tester.getTopLeft(revealFinder).dy),
      );
    });

    testWidgets('hides the thread card when not eligible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: [
              _record(id: 'x0', daysAgo: 1, optionId: 'could_not_stop'),
              _record(id: 'x1', daysAgo: 0, optionId: 'guilty_resting'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsNothing,
      );
    });
  });

  group('Value accuracy feedback — thread return card', () {
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

    Future<void> pumpCard(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThreadReturnEvidenceCard(
                evidence: engine.build(_workThread3(), now: _base),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('feedback row renders on the card', (tester) async {
      await pumpCard(tester);
      expect(find.text(ValueAccuracyFeedbackRow.question), findsOneWidget);
      expect(find.text(ValueAccuracyFeedbackRow.yesLabel), findsOneWidget);
      expect(find.text(ValueAccuracyFeedbackRow.notQuiteLabel), findsOneWidget);
    });

    testWidgets('Yes logs useful with safe metadata only', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_yes_thread_return_evidence')),
      );
      await tester.pump();

      expect(find.text(ValueAccuracyFeedbackRow.yesThanksLine), findsOneWidget);
      final events = feedbackEvents();
      expect(events, hasLength(1));
      expect(
        events.single.event,
        ActivationFunnelAnalytics.valueFeedbackUseful,
      );
      expect(events.single.properties, {
        'card_type': 'thread_return_evidence',
        'entry_count': 3,
        'has_connected_thread': 1,
      });
      // No snippet, note, or term text in the payload.
      final flat = events.single.properties.values.join(' ').toLowerCase();
      for (final word in const ['checking', 'messages', 'deadline', 'work']) {
        expect(flat, isNot(contains(word)));
      }
    });

    testWidgets('Not quite logs and keeps it light', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(
          const Key('value_feedback_not_quite_thread_return_evidence'),
        ),
      );
      await tester.pump();

      expect(
        find.text(ValueAccuracyFeedbackRow.notQuiteThanksLine),
        findsOneWidget,
      );
      expect(
        feedbackEvents().single.event,
        ActivationFunnelAnalytics.valueFeedbackNotQuite,
      );
    });

    testWidgets('one tap removes the buttons — no duplicate feedback', (
      tester,
    ) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_yes_thread_return_evidence')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('value_feedback_yes_thread_return_evidence')),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('value_feedback_not_quite_thread_return_evidence'),
        ),
        findsNothing,
      );
      expect(feedbackEvents(), hasLength(1));
    });

    test('feedback copy avoids banned words and VoiceMemory', () {
      final copy = [
        ValueAccuracyFeedbackRow.question,
        ValueAccuracyFeedbackRow.yesLabel,
        ValueAccuracyFeedbackRow.notQuiteLabel,
        ValueAccuracyFeedbackRow.yesThanksLine,
        ValueAccuracyFeedbackRow.notQuiteThanksLine,
      ].join(' ').toLowerCase();
      const banned = [
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
        'therapy',
        'treatment',
        'voicememory',
      ];
      for (final word in banned) {
        expect(copy, isNot(contains(word)), reason: 'banned word: $word');
      }
    });
  });

  group('Value testimonial capture', () {
    late List<({String event, Map<String, Object> properties})> captured;
    late _MemoryTestimonialStore store;

    setUp(() {
      captured = [];
      store = _MemoryTestimonialStore();
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    Future<void> pumpRow(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueAccuracyFeedbackRow(
                cardType: 'thread_return_evidence',
                entryCount: 3,
                hasConnectedThread: true,
                testimonialStore: store,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    const askKey = Key('value_testimonial_ask_thread_return_evidence');
    const fieldKey = Key('value_testimonial_field_thread_return_evidence');
    const saveKey = Key('value_testimonial_save_thread_return_evidence');
    const notNowKey = Key('value_testimonial_not_now_thread_return_evidence');

    testWidgets('ask appears only after a useful rating', (tester) async {
      await pumpRow(tester);
      expect(find.byKey(askKey), findsNothing);

      await tester.tap(
        find.byKey(const Key('value_feedback_yes_thread_return_evidence')),
      );
      await tester.pump();

      expect(find.byKey(askKey), findsOneWidget);
      expect(
        find.text(ValueAccuracyFeedbackRow.testimonialTitle),
        findsOneWidget,
      );
      expect(
        find.text(ValueAccuracyFeedbackRow.testimonialHelper),
        findsOneWidget,
      );
    });

    testWidgets('ask never appears after Not quite', (tester) async {
      await pumpRow(tester);
      await tester.tap(
        find.byKey(
          const Key('value_feedback_not_quite_thread_return_evidence'),
        ),
      );
      await tester.pump();

      expect(find.byKey(askKey), findsNothing);
      expect(
        find.text(ValueAccuracyFeedbackRow.notQuiteThanksLine),
        findsOneWidget,
      );
    });

    testWidgets('Not now dismisses the ask and stores nothing', (tester) async {
      await pumpRow(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_yes_thread_return_evidence')),
      );
      await tester.pump();
      await tester.tap(find.byKey(notNowKey));
      await tester.pump();

      expect(find.byKey(askKey), findsNothing);
      expect(find.text(ValueAccuracyFeedbackRow.yesThanksLine), findsOneWidget);
      expect(store.saved, isEmpty);
      expect(
        captured.where(
          (e) => e.event == ActivationFunnelAnalytics.valueTestimonialSaved,
        ),
        isEmpty,
      );
    });

    testWidgets('save stores the quote and keeps it out of analytics', (
      tester,
    ) async {
      await pumpRow(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_yes_thread_return_evidence')),
      );
      await tester.pump();

      const quote = 'It noticed I bring up the same worry every week.';
      await tester.enterText(find.byKey(fieldKey), quote);
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();

      expect(
        find.text(ValueAccuracyFeedbackRow.testimonialThanksLine),
        findsOneWidget,
      );
      expect(store.saved, hasLength(1));
      expect(store.saved.single.quote, quote);
      expect(store.saved.single.cardType, 'thread_return_evidence');
      // Stored record carries no snippets, terms, or transcripts.
      expect(store.saved.single.toJson().keys.toSet(), {
        'quote',
        'cardType',
        'createdAt',
      });

      final saved = captured
          .where(
            (e) => e.event == ActivationFunnelAnalytics.valueTestimonialSaved,
          )
          .toList();
      expect(saved, hasLength(1));
      expect(saved.single.properties, {
        'card_type': 'thread_return_evidence',
        'entry_count': 3,
        'has_connected_thread': 1,
      });
      // The quote never appears in any analytics payload.
      for (final e in captured) {
        expect('${e.properties.values.join(' ')}', isNot(contains('worry')));
      }
    });

    testWidgets('saving an empty field is a quiet not-now', (tester) async {
      await pumpRow(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_yes_thread_return_evidence')),
      );
      await tester.pump();
      await tester.tap(find.byKey(saveKey));
      await tester.pump();

      expect(find.byKey(askKey), findsNothing);
      expect(store.saved, isEmpty);
    });

    test('quotes are capped at 180 characters and newlines are stripped', () {
      final long = List.filled(40, 'useful insight').join(' ');
      final capped = ValueTestimonialStore.sanitizeQuote(long);
      expect(capped.length, lessThanOrEqualTo(180));

      expect(
        ValueTestimonialStore.sanitizeQuote('line one\nline two\r\nline three'),
        'line one line two line three',
      );
      expect(ValueTestimonialStore.sanitizeQuote('   \n  '), isEmpty);
    });

    test('store round-trips locally and enforces the cap', () async {
      final dir = Directory.systemTemp.createTempSync('vm_testimonials_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final fileStore = ValueTestimonialStore(prefs);

      await fileStore.add(
        quote: 'It noticed\nsomething I keep repeating.',
        cardType: 'belief_distance',
        now: DateTime(2026, 6, 11, 9),
      );
      final all = await fileStore.all();
      expect(all, hasLength(1));
      expect(all.single.quote, 'It noticed something I keep repeating.');
      expect(all.single.cardType, 'belief_distance');
    });

    test('quotes never enter the share card', () async {
      await store.add(
        quote: 'It noticed something I keep repeating.',
        cardType: 'thread_return_evidence',
      );
      final proof = const ShareableArchiveProofEngine().build(
        _workThread3(),
        now: _base,
      );
      expect(proof.hasProof, isTrue);
      expect(
        proof.shareText,
        isNot(contains('It noticed something I keep repeating.')),
      );
    });

    test('testimonial copy avoids banned words and VoiceMemory', () {
      final copy = [
        ValueAccuracyFeedbackRow.testimonialTitle,
        ValueAccuracyFeedbackRow.testimonialPlaceholder,
        ValueAccuracyFeedbackRow.testimonialHelper,
        ValueAccuracyFeedbackRow.testimonialSaveLabel,
        ValueAccuracyFeedbackRow.testimonialNotNowLabel,
        ValueAccuracyFeedbackRow.testimonialThanksLine,
      ].join(' ').toLowerCase();
      const banned = [
        'must',
        'should',
        'task',
        'homework',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'definitely',
        'therapy',
        'treatment',
        'voicememory',
      ];
      for (final word in banned) {
        expect(copy, isNot(contains(word)), reason: 'banned word: $word');
      }
    });
  });
}

/// In-memory testimonial store — keeps widget tests free of file IO.
class _MemoryTestimonialStore extends ValueTestimonialStore {
  _MemoryTestimonialStore()
    : super(
        MobilePrefsStore(file: File('test/tmp/testimonials/unused_prefs.json')),
      );

  final List<ValueTestimonial> saved = [];

  @override
  Future<void> add({
    required String quote,
    required String cardType,
    DateTime? now,
  }) async {
    final sanitized = ValueTestimonialStore.sanitizeQuote(quote);
    if (sanitized.isEmpty) return;
    saved.add(
      ValueTestimonial(
        quote: sanitized,
        cardType: cardType,
        createdAt: now ?? DateTime(2026, 6, 11),
      ),
    );
  }

  @override
  Future<List<ValueTestimonial>> all() async => List.of(saved);
}
