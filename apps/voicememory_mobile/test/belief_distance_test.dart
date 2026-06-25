import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/memory/current_intent_signal.dart';
import 'package:voicememory_mobile/features/memory/memory_connection_rules.dart';
import 'package:voicememory_mobile/features/memory/memory_control_model.dart';
import 'package:voicememory_mobile/features/memory/memory_governance_policy.dart';
import 'package:voicememory_mobile/features/memory/memory_priority_governance.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/belief_distance_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/belief_distance_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/value_accuracy_feedback_row.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
  String? stopCostNote,
  String archiveThreadId = 'checking-thread',
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    stopCostNote: stopCostNote,
    transcript: 'pressure moment',
    archiveThreadId: archiveThreadId,
  );
}

/// Three entries whose notes repeat the same belief-like language.
List<PressureCheckInRecord> _checkingBelief3() => [
  _record(id: 'c0', daysAgo: 6, fear: 'I have to keep checking messages'),
  _record(id: 'c1', daysAgo: 3, fear: 'Checking messages again at night'),
  _record(id: 'c2', daysAgo: 0, fear: 'I have to keep checking before I rest'),
];

/// Two entries sharing belief-like language — early, cautious territory.
List<PressureCheckInRecord> _checkingBelief2() => [
  _record(id: 'd0', daysAgo: 4, fear: 'I have to keep checking messages'),
  _record(id: 'd1', daysAgo: 0, fear: 'Checking messages again tonight'),
];

/// A real thread (shared work context) whose notes share no repeated words —
/// a thread exists, but no belief-like phrase can be safely formed.
List<PressureCheckInRecord> _threadWithoutRepeatedWords() => [
  _record(id: 'w0', daysAgo: 7, contextIds: const ['work']),
  _record(
    id: 'w1',
    daysAgo: 3,
    contextIds: const ['work'],
    fear: 'The deadline slipping',
  ),
  _record(
    id: 'w2',
    daysAgo: 0,
    contextIds: const ['work'],
    fear: 'Too many open browser tabs at midnight',
  ),
];

String _allCopy(BeliefDistance belief) => [
  belief.title,
  belief.beliefLine,
  belief.frequencyLine,
  belief.distanceLine,
  belief.confidenceLabel,
  ...belief.evidenceSnippets,
  ...belief.sourceTerms,
  BeliefDistance.evidenceHeading,
].join(' ');

void main() {
  const engine = BeliefDistanceEngine();

  setUp(() {
    MemoryScopePolicy.resetForTest();
    MemoryGovernancePolicy.resetForTest();
    MemoryPriorityGovernance.resetForTest();
    MemoryConnectionRules.resetForTest();
    CurrentIntentSignal.resetSessionForTest();
    MemoryConnectionRules.keepConnected(MemoryCardType.beliefDistance);
  });

  BeliefDistance buildBelief(List<PressureCheckInRecord> records) =>
      engine.build(records, entryCount: records.length);

  group('Belief distance engine — eligibility', () {
    test('no belief with fewer than 2 entries', () {
      expect(buildBelief(const []).hasBelief, isFalse);
      expect(
        buildBelief([
          _record(id: 'a', fear: 'I have to keep checking'),
        ]).hasBelief,
        isFalse,
      );
    });

    test('no belief when notes share no repeated language', () {
      final belief = buildBelief(_threadWithoutRepeatedWords());
      expect(belief.hasBelief, isFalse);
      expect(belief.beliefLine, isEmpty);
      expect(belief.evidenceSnippets, isEmpty);
    });

    test('no belief when entries hold no notes at all', () {
      final belief = buildBelief([
        _record(id: 'n0', daysAgo: 2, contextIds: const ['work']),
        _record(id: 'n1', daysAgo: 0, contextIds: const ['work']),
      ]);
      expect(belief.hasBelief, isFalse);
    });

    test('no belief when the repeated language only lives in long notes', () {
      final longNote =
          'I have been checking messages over and over for hours tonight and '
          'I cannot seem to put the phone down at all anymore';
      expect(longNote.length, greaterThan(BeliefDistance.maxPhraseLength));
      final belief = buildBelief([
        _record(id: 'l0', daysAgo: 3, fear: longNote),
        _record(id: 'l1', daysAgo: 0, fear: '$longNote either way'),
      ]);
      expect(belief.hasBelief, isFalse);
    });
  });

  group('Belief distance engine — copy rules', () {
    test('3+ entries use "A belief that showed up"', () {
      final belief = buildBelief(_checkingBelief3());
      expect(belief.hasBelief, isTrue);
      expect(belief.title, 'A belief that showed up');
      expect(
        belief.beliefLine,
        '\u201CI have to keep checking before I rest\u201D showed up again.',
      );
      expect(
        belief.frequencyLine,
        'This appeared 3 times in your recent archive.',
      );
      expect(belief.confidenceLabel, 'Repeated signal');
    });

    test('2 entries use the cautious starting-to-repeat title', () {
      final belief = buildBelief(_checkingBelief2());
      expect(belief.hasBelief, isTrue);
      expect(belief.title, 'This may be a belief that is starting to repeat.');
      expect(belief.confidenceLabel, 'Early signal');
      expect(
        belief.frequencyLine,
        'This appeared 2 times in your recent archive.',
      );
    });

    test('distance line never treats the belief as fact', () {
      final belief = buildBelief(_checkingBelief3());
      expect(
        belief.distanceLine,
        'You do not need to treat it as fact today. '
        'Just notice that it returned.',
      );
    });
  });

  group('Belief distance engine — phrase extraction', () {
    test('prefers a first-person pressure phrase over a newer plain note', () {
      final belief = buildBelief([
        _record(id: 'm0', daysAgo: 4, fear: 'I have to keep checking messages'),
        _record(
          id: 'm1',
          daysAgo: 0,
          fear: 'Checking messages crept back tonight',
        ),
      ]);
      expect(belief.hasBelief, isTrue);
      expect(
        belief.beliefLine,
        '\u201CI have to keep checking messages\u201D showed up again.',
      );
    });

    test('takes the exact belief sentence out of a longer note', () {
      final belief = buildBelief([
        _record(
          id: 'p0',
          daysAgo: 3,
          fear:
              'A long winding lead-in sentence that rambles on for a while '
              'without getting anywhere near the point at all. '
              'I cannot stop checking messages.',
        ),
        _record(id: 'p1', daysAgo: 0, fear: 'Checking messages again at night'),
      ]);
      expect(belief.hasBelief, isTrue);
      // Punctuation trimmed, wording preserved verbatim.
      expect(
        belief.beliefLine,
        '\u201CI cannot stop checking messages\u201D showed up again.',
      );
    });

    test('falls back to the newest plain note when no marker exists', () {
      final belief = buildBelief([
        _record(id: 'f0', daysAgo: 4, fear: 'Checking messages at my desk'),
        _record(id: 'f1', daysAgo: 0, fear: 'Checking messages again tonight'),
      ]);
      expect(belief.hasBelief, isTrue);
      expect(
        belief.beliefLine,
        '\u201CChecking messages again tonight\u201D showed up again.',
      );
    });
  });

  group('Belief distance engine — evidence integrity', () {
    test('quoted phrase and snippets are the user\u2019s exact words', () {
      final records = _checkingBelief3();
      final belief = buildBelief(records);
      final realNotes = records.map((r) => r.fear).whereType<String>().toList();

      for (final snippet in belief.evidenceSnippets) {
        expect(
          realNotes,
          contains(snippet),
          reason: 'snippet must be an exact saved note: "$snippet"',
        );
      }
      // The quoted belief phrase itself is one of the user's saved notes.
      final quoted = RegExp('\u201C(.+)\u201D').firstMatch(belief.beliefLine);
      expect(quoted, isNotNull);
      expect(realNotes, contains(quoted!.group(1)));
    });

    test('entry ids map to the real entries behind the repeated word', () {
      final belief = buildBelief(_checkingBelief3());
      expect(belief.entryIds, ['c0', 'c1', 'c2']);
    });

    test('snippets are capped at 3 even with more evidence', () {
      final belief = buildBelief([
        for (var i = 0; i < 5; i++)
          _record(
            id: 's$i',
            daysAgo: 5 - i,
            fear: 'Checking messages round number $i',
          ),
      ]);
      expect(belief.hasBelief, isTrue);
      expect(belief.evidenceSnippets.length, BeliefDistance.maxSnippets);
      expect(belief.confidenceLabel, 'Strong repeated signal');
      expect(
        belief.frequencyLine,
        'This appeared 5 times in your recent archive.',
      );
    });

    test('source terms are capped at 3 and start with the repeated word', () {
      final belief = buildBelief(_checkingBelief3());
      expect(
        belief.sourceTerms.length,
        lessThanOrEqualTo(BeliefDistance.maxTerms),
      );
      expect(belief.sourceTerms.first, 'checking');
    });
  });

  group('Belief distance engine — language guardrails', () {
    final scenarios = [
      () => buildBelief(_checkingBelief3()),
      () => buildBelief(_checkingBelief2()),
    ];

    test('never says "you believe" or claims the belief is true', () {
      for (final build in scenarios) {
        final copy = _allCopy(build()).toLowerCase();
        expect(copy, isNot(contains('you believe')));
        expect(copy, isNot(contains('your belief')));
        expect(copy, isNot(contains('this is true')));
        expect(copy, isNot(contains('it is true')));
      }
    });

    test('no therapy or diagnosis words', () {
      for (final build in scenarios) {
        final belief = build();
        final copy = _allCopy(belief);
        final lower = copy.toLowerCase();
        for (final banned in const [
          'therapy',
          'defusion',
          'treatment',
          'anxiety',
          'trauma',
          'disorder',
          'diagnos',
          'healed',
          'processed',
          'regulated',
          'cured',
        ]) {
          expect(
            lower,
            isNot(contains(banned)),
            reason: 'copy must not contain "$banned"',
          );
        }
        // ACT checked case-sensitively so "fact" stays allowed.
        expect(copy, isNot(contains('ACT')));
      }
    });

    test('no pressure words', () {
      for (final build in scenarios) {
        final copy = _allCopy(build()).toLowerCase();
        for (final banned in const [
          'must',
          'should',
          'task',
          'homework',
          'failure',
          'lazy',
          'weak',
          'problem',
          'fix',
          'definitely',
        ]) {
          expect(
            copy,
            isNot(contains(banned)),
            reason: 'copy must not contain "$banned"',
          );
        }
      }
    });

    test('no VoiceMemory in consumer copy', () {
      for (final build in scenarios) {
        expect(_allCopy(build()), isNot(contains('VoiceMemory')));
      }
    });
  });

  group('Belief distance card', () {
    testWidgets('renders title, belief, frequency, evidence, and distance', (
      tester,
    ) async {
      final belief = buildBelief(_checkingBelief3());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeliefDistanceCard(belief: belief),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('belief_distance_card')), findsOneWidget);
      expect(find.text('A belief that showed up'), findsOneWidget);
      expect(
        find.text(
          '\u201CI have to keep checking before I rest\u201D showed up again.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('This appeared 3 times in your recent archive.'),
        findsOneWidget,
      );
      expect(find.text('Evidence behind this'), findsOneWidget);
      for (final snippet in belief.evidenceSnippets) {
        expect(find.textContaining(snippet), findsWidgets);
      }
      expect(find.byKey(const Key('belief_distance_line')), findsOneWidget);
      expect(
        find.textContaining('You do not need to treat it as fact today.'),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
      // Closure and noticing only — no buttons, nothing gated behind Pro.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('Pro'), findsNothing);
    });

    testWidgets('renders nothing without a safely formed belief', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BeliefDistanceCard(belief: BeliefDistance.none()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('belief_distance_card')), findsNothing);
    });
  });

  group('Pressure Insights integration', () {
    testWidgets(
      'renders the belief card when eligible, near the thread cards',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 5200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: PressureInsightsScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
              records: _checkingBelief3(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('belief_distance_card')), findsOneWidget);
        // Existing cards are not hidden by the new one.
        expect(
          find.byKey(const Key('thread_return_evidence_card')),
          findsOneWidget,
        );
      },
    );

    testWidgets('hides the belief card when no phrase can be formed', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 5200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: _threadWithoutRepeatedWords(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('belief_distance_card')), findsNothing);
      // The thread card still renders from the shared work context.
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsOneWidget,
      );
    });
  });

  group('Value accuracy feedback — belief distance card', () {
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
              child: BeliefDistanceCard(
                belief: buildBelief(_checkingBelief3()),
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

    testWidgets('Not quite logs without the belief phrase', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_not_quite_belief_distance')),
      );
      await tester.pump();

      expect(
        find.text(ValueAccuracyFeedbackRow.notQuiteThanksLine),
        findsOneWidget,
      );
      final events = feedbackEvents();
      expect(events, hasLength(1));
      expect(
        events.single.event,
        ActivationFunnelAnalytics.valueFeedbackNotQuite,
      );
      expect(events.single.properties, {'card_type': 'belief_distance'});
      final flat = events.single.properties.values.join(' ').toLowerCase();
      for (final word in const ['checking', 'messages', 'keep']) {
        expect(flat, isNot(contains(word)));
      }
    });

    testWidgets('one tap disables duplicate feedback', (tester) async {
      await pumpCard(tester);
      await tester.tap(
        find.byKey(const Key('value_feedback_yes_belief_distance')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('value_feedback_yes_belief_distance')),
        findsNothing,
      );
      // The optional testimonial ask follows a useful rating.
      expect(
        find.byKey(const Key('value_testimonial_ask_belief_distance')),
        findsOneWidget,
      );
      expect(feedbackEvents(), hasLength(1));
    });
  });
}
