import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/weekly_thread_review_model.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/value_accuracy_feedback_row.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/weekly_thread_review_card.dart';

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

/// Three work-context entries; two fall inside the 7-day window.
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

/// Older cluster plus one recent entry — the thread engine calls this fading.
List<PressureCheckInRecord> _fadingThread() => [
  _record(id: 'f0', daysAgo: 10, contextIds: const ['work']),
  _record(id: 'f1', daysAgo: 9, contextIds: const ['work']),
  _record(id: 'f2', daysAgo: 8, contextIds: const ['work']),
  _record(
    id: 'f3',
    daysAgo: 1,
    contextIds: const ['work'],
    fear: 'Late emails piling up',
  ),
];

/// Notes that repeat belief-like language ("checking") across 3 entries.
List<PressureCheckInRecord> _checkingBelief3() => [
  _record(id: 'c0', daysAgo: 6, fear: 'I have to keep checking messages'),
  _record(id: 'c1', daysAgo: 3, fear: 'Checking messages again at night'),
  _record(id: 'c2', daysAgo: 0, fear: 'I have to keep checking before I rest'),
];

/// Entries with no overlap: different options, no contexts, no notes.
List<PressureCheckInRecord> _unrelatedRecords() => [
  _record(id: 'u0', daysAgo: 2, optionId: 'could_not_stop'),
  _record(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
  _record(id: 'u2', daysAgo: 0, optionId: 'had_to_prove_enough'),
];

/// Three unconnected entries, all older than the 7-day window.
List<PressureCheckInRecord> _staleRecords() => [
  _record(id: 's0', daysAgo: 20, optionId: 'could_not_stop'),
  _record(id: 's1', daysAgo: 15, optionId: 'guilty_resting'),
  _record(id: 's2', daysAgo: 10, optionId: 'had_to_prove_enough'),
];

/// Generated copy only — snippets are the user's own words and are checked
/// separately for exactness.
String _generatedCopy(WeeklyThreadReview review) => [
  review.title,
  review.weekSummaryLine,
  review.takeawayLine,
  WeeklyThreadReview.returnedTakeaway,
  WeeklyThreadReview.fadingTakeaway,
  WeeklyThreadReview.changedTakeaway,
  WeeklyThreadReview.evidenceOnlyTakeaway,
  review.returnedLine,
  review.fadedLine,
  review.changedLine,
  review.evidenceLine,
  review.nextWeekLine,
  WeeklyThreadReview.defaultTitle,
  WeeklyThreadReview.defaultWeekSummaryLine,
  WeeklyThreadReview.defaultNextWeekLine,
  WeeklyThreadReview.evidenceHeading,
].join(' ');

void main() {
  const engine = WeeklyThreadReviewEngine();

  group('Weekly thread review engine — eligibility', () {
    test('no review without enough archive evidence', () {
      expect(engine.build(const [], now: _base).hasReview, isFalse);
      expect(
        engine.build([
          _record(id: 'a', contextIds: const ['work']),
        ], now: _base).hasReview,
        isFalse,
      );
      // Two unconnected entries: below the entry floor, no thread either.
      expect(
        engine.build([
          _record(id: 'u0', daysAgo: 1, optionId: 'could_not_stop'),
          _record(id: 'u1', daysAgo: 0, optionId: 'guilty_resting'),
        ], now: _base).hasReview,
        isFalse,
      );
    });

    test('review appears with 3+ entries even without a thread', () {
      final review = engine.build(_unrelatedRecords(), now: _base);
      expect(review.hasReview, isTrue);
      expect(review.title, 'This week in your archive');
      expect(review.evidenceLine, 'You added 3 pieces of evidence.');
      // No thread → no thread claims.
      expect(review.returnedLine, isEmpty);
      expect(review.fadedLine, isEmpty);
      expect(review.changedLine, isEmpty);
      expect(review.sourceTerms, isEmpty);
      expect(review.evidenceSnippets, isEmpty);
    });

    test('review appears with only 2 connected entries', () {
      final review = engine.build(_workThread2(), now: _base);
      expect(review.hasReview, isTrue);
      expect(review.returnedLine, 'The work thread returned 1 time.');
    });

    test('no review when nothing moved inside the window', () {
      // Eligible by entry count, but no thread and nothing added this week:
      // an empty review would be fabricated filler.
      expect(engine.build(_staleRecords(), now: _base).hasReview, isFalse);
    });
  });

  group('Weekly thread review engine — counts', () {
    test('evidence count is accurate for the 7-day window', () {
      // Only the daysAgo 3 and 0 entries fall inside the window.
      final review = engine.build(_workThread3(), now: _base);
      expect(review.evidenceLine, 'You added 2 pieces of evidence.');

      final single = engine.build(_fadingThread(), now: _base);
      expect(single.evidenceLine, 'You added 1 piece of evidence.');
    });

    test('returned count excludes the thread\u2019s first appearance', () {
      final review = engine.build(_workThread3(), now: _base);
      // Occurrences a (first ever), b, c — b and c are real comebacks.
      expect(review.returnedLine, 'The work thread returned 2 times.');
    });

    test('no fabricated claims — counts map to real entries', () {
      final review = engine.build(_workThread3(), now: _base);
      expect(review.entryIds, ['a', 'b', 'c']);
      final realIds = _workThread3().map((r) => r.entryId).toSet();
      for (final id in review.entryIds) {
        expect(realIds, contains(id));
      }
    });
  });

  group('Weekly thread review engine — change detection', () {
    test('fading and change lines are omitted without support', () {
      final review = engine.build(_workThread3(), now: _base);
      expect(review.fadedLine, isEmpty);
      expect(review.changedLine, isEmpty);
    });

    test('fading line appears only when the thread genuinely faded', () {
      final review = engine.build(_fadingThread(), now: _base);
      expect(
        review.fadedLine,
        'The work thread appeared less often in your recent recordings.',
      );
      // Hedged observation only — never resolution.
      expect(review.fadedLine.toLowerCase(), isNot(contains('resolved')));
    });

    test('change line appears when a belief-like phrase repeated', () {
      final review = engine.build(_checkingBelief3(), now: _base);
      expect(review.changedLine, 'One belief-like phrase showed up again.');
      expect(review.returnedLine, 'The checking thread returned 2 times.');
      expect(review.evidenceLine, 'You added 3 pieces of evidence.');
    });
  });

  group('Weekly thread review engine — evidence integrity', () {
    test('snippets are exact user text, capped at 3', () {
      final review = engine.build(_workThread3(), now: _base);
      expect(review.evidenceSnippets.length, lessThanOrEqualTo(3));
      expect(
        review.evidenceSnippets,
        contains('I kept checking messages after I wanted to stop.'),
      );
      expect(review.evidenceSnippets, contains('The deadline slipping'));
      // Every snippet is verbatim from a saved note.
      final notes = _workThread3().map((r) => r.fear).whereType<String>();
      for (final snippet in review.evidenceSnippets) {
        expect(notes, contains(snippet));
      }
    });

    test('source terms are capped at 3', () {
      for (final records in [
        _workThread3(),
        _fadingThread(),
        _checkingBelief3(),
      ]) {
        final review = engine.build(records, now: _base);
        expect(review.sourceTerms.length, lessThanOrEqualTo(3));
      }
    });
  });

  group('Weekly thread review — main takeaway', () {
    /// A faded thread with no occurrence inside the 7-day window — the only
    /// supported line is fading.
    List<PressureCheckInRecord> fadedOnly() => [
      _record(id: 'fo0', daysAgo: 20, contextIds: const ['work']),
      _record(id: 'fo1', daysAgo: 18, contextIds: const ['work']),
      _record(id: 'fo2', daysAgo: 16, contextIds: const ['work']),
      _record(id: 'fo3', daysAgo: 10, contextIds: const ['work']),
    ];

    /// A building thread entirely outside the window — the only supported
    /// line is the change line.
    List<PressureCheckInRecord> changedOnly() => [
      _record(id: 'co0', daysAgo: 20, contextIds: const ['work']),
      _record(id: 'co1', daysAgo: 10, contextIds: const ['work']),
      _record(id: 'co2', daysAgo: 8, contextIds: const ['work']),
    ];

    test('returned takeaway when the returned line exists', () {
      final review = engine.build(_workThread3(), now: _base);
      expect(review.returnedLine, isNotEmpty);
      expect(
        review.takeawayLine,
        'Main takeaway: this thread came back this week.',
      );
    });

    test('returned beats fading when both lines exist', () {
      final review = engine.build(_fadingThread(), now: _base);
      expect(review.returnedLine, isNotEmpty);
      expect(review.fadedLine, isNotEmpty);
      expect(review.takeawayLine, WeeklyThreadReview.returnedTakeaway);
    });

    test('fading takeaway only when fading is supported without a return', () {
      final review = engine.build(fadedOnly(), now: _base);
      expect(review.hasReview, isTrue);
      expect(review.returnedLine, isEmpty);
      expect(review.fadedLine, isNotEmpty);
      expect(
        review.takeawayLine,
        'Main takeaway: this thread may be getting quieter.',
      );
    });

    test('changed takeaway only when change is the strongest support', () {
      final review = engine.build(changedOnly(), now: _base);
      expect(review.hasReview, isTrue);
      expect(review.returnedLine, isEmpty);
      expect(review.fadedLine, isEmpty);
      expect(review.changedLine, isNotEmpty);
      expect(
        review.takeawayLine,
        'Main takeaway: something shifted in the archive.',
      );
    });

    test('evidence-only fallback takeaway when nothing else is supported', () {
      final review = engine.build(_unrelatedRecords(), now: _base);
      expect(review.returnedLine, isEmpty);
      expect(review.fadedLine, isEmpty);
      expect(review.changedLine, isEmpty);
      expect(review.evidenceLine, isNotEmpty);
      expect(
        review.takeawayLine,
        'Main takeaway: your archive has more to compare now.',
      );
    });

    test('no fabricated change — every takeaway maps to a supported line', () {
      for (final records in [
        _workThread3(),
        _workThread2(),
        _fadingThread(),
        _checkingBelief3(),
        _unrelatedRecords(),
        fadedOnly(),
        changedOnly(),
      ]) {
        final review = engine.build(records, now: _base);
        if (!review.hasReview) continue;
        final expected = review.returnedLine.isNotEmpty
            ? WeeklyThreadReview.returnedTakeaway
            : review.fadedLine.isNotEmpty
            ? WeeklyThreadReview.fadingTakeaway
            : review.changedLine.isNotEmpty
            ? WeeklyThreadReview.changedTakeaway
            : WeeklyThreadReview.evidenceOnlyTakeaway;
        expect(review.takeawayLine, expected);
      }
    });

    test('never claims certainty', () {
      for (final takeaway in const [
        WeeklyThreadReview.returnedTakeaway,
        WeeklyThreadReview.fadingTakeaway,
        WeeklyThreadReview.changedTakeaway,
        WeeklyThreadReview.evidenceOnlyTakeaway,
      ]) {
        final lower = takeaway.toLowerCase();
        for (final certain in const [
          'definitely',
          'certainly',
          'proves',
          'always',
          'never',
        ]) {
          expect(lower, isNot(contains(certain)));
        }
      }
    });

    test('no raw notes, snippets, belief phrases, or source terms in the '
        'takeaway', () {
      for (final records in [
        _workThread3(),
        _fadingThread(),
        _checkingBelief3(),
        fadedOnly(),
        changedOnly(),
      ]) {
        final review = engine.build(records, now: _base);
        if (!review.hasReview) continue;
        final lower = review.takeawayLine.toLowerCase();
        // Never the thread's source terms…
        for (final term in review.sourceTerms) {
          expect(lower, isNot(contains(term.toLowerCase())));
        }
        // …never the user's exact saved words…
        for (final snippet in review.evidenceSnippets) {
          expect(lower, isNot(contains(snippet.toLowerCase())));
        }
        // …and never the raw notes behind them.
        for (final note in records.map((r) => r.fear).whereType<String>()) {
          expect(lower, isNot(contains(note.toLowerCase())));
        }
        // Always one of the four fixed variants.
        expect(const [
          WeeklyThreadReview.returnedTakeaway,
          WeeklyThreadReview.fadingTakeaway,
          WeeklyThreadReview.changedTakeaway,
          WeeklyThreadReview.evidenceOnlyTakeaway,
        ], contains(review.takeawayLine));
      }
    });
  });

  group('Weekly thread review — language guardrails', () {
    final variants = [
      engine.build(_workThread3(), now: _base),
      engine.build(_workThread2(), now: _base),
      engine.build(_fadingThread(), now: _base),
      engine.build(_checkingBelief3(), now: _base),
      engine.build(_unrelatedRecords(), now: _base),
    ];

    test('no banned, streak, or therapy words in generated copy', () {
      for (final review in variants) {
        final copy = _generatedCopy(review).toLowerCase();
        for (final banned in const [
          'streak',
          'daily',
          'habit',
          'guilt',
          'missed',
          'behind',
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
          'anxiety',
          'trauma',
          'resolved',
          'cured',
        ]) {
          expect(
            copy,
            isNot(contains(banned)),
            reason: 'review copy must not contain "$banned"',
          );
        }
      }
    });

    test('no VoiceMemory in any consumer copy', () {
      for (final review in variants) {
        expect(_generatedCopy(review), isNot(contains('VoiceMemory')));
      }
    });
  });

  group('Weekly thread review card', () {
    testWidgets('renders title, lines, evidence, and next-week cue', (
      tester,
    ) async {
      final review = engine.build(_workThread3(), now: _base);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyThreadReviewCard(review: review),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('weekly_thread_review_card')),
        findsOneWidget,
      );
      expect(find.text('This week in your archive'), findsOneWidget);
      expect(
        find.text('What returned, faded, or changed across your last 7 days.'),
        findsOneWidget,
      );
      expect(find.text('You added 2 pieces of evidence.'), findsOneWidget);
      expect(find.text('The work thread returned 2 times.'), findsOneWidget);
      expect(find.text(WeeklyThreadReview.evidenceHeading), findsOneWidget);
      expect(find.textContaining('I kept checking messages'), findsOneWidget);
      expect(
        find.text('Next week, check whether this returned, faded, or changed.'),
        findsOneWidget,
      );
      // Compact and passive: no CTA buttons, no Pro gate. The only
      // buttons are the small memory-control text actions.
      expect(find.byWidgetPredicate((w) => w is FilledButton), findsNothing);
      expect(find.byWidgetPredicate((w) => w is OutlinedButton), findsNothing);
      expect(
        find.byKey(const Key('memory_used_receipt_why_weekly_review')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('memory_connection_actions_weekly_review')),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('renders the takeaway above the evidence snippets', (
      tester,
    ) async {
      final review = engine.build(_workThread3(), now: _base);
      expect(review.takeawayLine, isNotEmpty);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyThreadReviewCard(review: review),
            ),
          ),
        ),
      );
      await tester.pump();

      final takeaway = find.byKey(const Key('weekly_review_takeaway'));
      expect(takeaway, findsOneWidget);
      expect(find.text(review.takeawayLine), findsOneWidget);

      // The sharpened takeaway sits near the top — above the detail lines
      // and above the exact evidence snippets, which stay untouched.
      final takeawayDy = tester.getTopLeft(takeaway).dy;
      final firstDetailDy = tester
          .getTopLeft(find.text('You added 2 pieces of evidence.'))
          .dy;
      final snippetDy = tester
          .getTopLeft(find.textContaining('I kept checking messages'))
          .dy;
      expect(takeawayDy, lessThan(firstDetailDy));
      expect(takeawayDy, lessThan(snippetDy));
      expect(find.textContaining('I kept checking messages'), findsOneWidget);
      // The feedback row is unchanged below.
      expect(find.byType(ValueAccuracyFeedbackRow), findsOneWidget);
    });

    testWidgets('renders nothing without a review', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyThreadReviewCard(review: WeeklyThreadReview.none()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('weekly_thread_review_card')), findsNothing);
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('renders the weekly review without hiding existing cards', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
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

      expect(find.byKey(const Key('weekly_thread_review_card')), findsNothing);
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('archive_proof_counter_card')),
        findsOneWidget,
      );
    });

    testWidgets('no weekly review when nothing moved', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: _staleRecords(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('weekly_thread_review_card')), findsNothing);
    });
  });

  group('Value accuracy feedback — weekly review card', () {
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
              child: WeeklyThreadReviewCard(
                review: const WeeklyThreadReviewEngine().build(
                  _workThread3(),
                  now: _base,
                ),
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
    });

    testWidgets('Yes logs useful with the card type only', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_yes_weekly_thread_review')),
      );
      await tester.pump();

      expect(find.text(ValueAccuracyFeedbackRow.yesThanksLine), findsOneWidget);
      // The optional testimonial ask follows a useful rating.
      expect(
        find.byKey(const Key('value_testimonial_ask_weekly_thread_review')),
        findsOneWidget,
      );
      final events = feedbackEvents();
      expect(events, hasLength(1));
      expect(
        events.single.event,
        ActivationFunnelAnalytics.valueFeedbackUseful,
      );
      expect(events.single.properties, {'card_type': 'weekly_thread_review'});
    });

    testWidgets('one tap disables duplicate feedback', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_not_quite_weekly_thread_review')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('value_feedback_yes_weekly_thread_review')),
        findsNothing,
      );
      expect(feedbackEvents(), hasLength(1));
    });
  });
}
