import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/features/pressure_retention/guided_thread_plan_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/guided_thread_plan_model.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/guided_thread_plan_card.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
    contextIds: const ['work'],
    fear: 'I kept checking messages after I wanted to stop.',
  ),
];

/// Work-context thread that appeared less often recently → fading.
List<PressureCheckInRecord> _fadingThread() => [
  _record(id: 'f0', daysAgo: 8, contextIds: const ['work']),
  _record(id: 'f1', daysAgo: 7, contextIds: const ['work']),
  _record(id: 'f2', daysAgo: 6, contextIds: const ['work']),
  _record(id: 'f3', daysAgo: 1, contextIds: const ['work']),
];

List<PressureCheckInRecord> _unrelatedRecords() => [
  _record(id: 'u0', daysAgo: 2),
  _record(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
  _record(id: 'u2', optionId: 'had_to_prove_enough'),
];

/// All consumer copy carried by one plan, joined for language sweeps.
String _planCopy(GuidedThreadPlan plan) => [
  plan.title,
  plan.basedOnLine,
  plan.encouragementLine,
  plan.nextPrompt,
  ...plan.alreadyCovered,
  ...plan.worthChecking,
  ...plan.sourceTerms,
  GuidedThreadPlan.alreadyCoveredHeading,
  GuidedThreadPlan.worthCheckingHeading,
  GuidedThreadPlan.nextRecordingHeading,
  GuidedThreadPlan.recordCtaLabel,
].join(' ');

void main() {
  const engine = GuidedThreadPlanEngine();

  group('Guided thread plan engine — eligibility', () {
    test('no plan before enough related evidence', () {
      expect(engine.build(const [], now: _base).hasPlan, isFalse);
      expect(
        engine.build([
          _record(id: 'a', contextIds: const ['work']),
        ], now: _base).hasPlan,
        isFalse,
      );
      expect(engine.build(_unrelatedRecords(), now: _base).hasPlan, isFalse);
    });

    test('plan appears with 2+ related entries', () {
      final plan = engine.build([
        _record(id: 'a', daysAgo: 5, contextIds: const ['work']),
        _record(id: 'b', contextIds: const ['work']),
      ], now: _base);

      expect(plan.hasPlan, isTrue);
      expect(plan.title, 'Today\u2019s thread plan');
      expect(plan.basedOnLine, 'Based on your recent archive');
      expect(plan.alreadyCovered, isNotEmpty);
      expect(plan.worthChecking, isNotEmpty);
      expect(plan.nextPrompt, isNotEmpty);
    });
  });

  group('Guided thread plan engine — plan content', () {
    test('alreadyCovered uses real terms and real counts', () {
      final plan = engine.build(_workThread3(), now: _base);
      expect(
        plan.alreadyCovered,
        contains('You already named the work thread.'),
      );
      expect(
        plan.alreadyCovered,
        contains('You already logged 3 moments on it.'),
      );
      expect(
        plan.alreadyCovered.length,
        lessThanOrEqualTo(GuidedThreadPlan.maxAlreadyCovered),
      );
    });

    test('worthChecking has 1–3 short open items', () {
      final scenarios = [
        engine.build(_workThread3(), now: _base),
        engine.build(_fadingThread(), now: _base),
        engine.build([
          _record(id: 'e0', daysAgo: 5, contextIds: const ['work']),
          _record(id: 'e1', contextIds: const ['work']),
        ], now: _base),
      ];
      for (final plan in scenarios) {
        expect(plan.worthChecking.length, greaterThanOrEqualTo(1));
        expect(
          plan.worthChecking.length,
          lessThanOrEqualTo(GuidedThreadPlan.maxWorthChecking),
        );
      }
    });

    test('nextPrompt is generated from the user\u2019s thread term', () {
      final returned = engine.build(_workThread3(), now: _base);
      expect(returned.nextPrompt, 'What happened with the work thread today?');

      final fading = engine.build(_fadingThread(), now: _base);
      expect(fading.nextPrompt, 'What felt different about work today?');

      final early = engine.build([
        _record(id: 'e0', daysAgo: 5, contextIds: const ['work']),
        _record(id: 'e1', contextIds: const ['work']),
      ], now: _base);
      expect(
        early.nextPrompt,
        'Did the work thread return, fade, or change today?',
      );
    });

    test('source terms are capped at 3', () {
      final plan = engine.build([
        for (var i = 0; i < 3; i++)
          _record(
            id: 't$i',
            daysAgo: i,
            contextIds: const ['work', 'evening', 'deadline'],
          ),
      ], now: _base);
      expect(plan.sourceTerms.length, GuidedThreadPlan.maxTerms);
    });

    test('evidence snippets are capped at 2', () {
      final plan = engine.build([
        for (var i = 0; i < 5; i++)
          _record(
            id: 's$i',
            daysAgo: i,
            contextIds: const ['work'],
            fear: 'Unique note number $i',
          ),
      ], now: _base);
      expect(plan.evidenceSnippets.length, GuidedThreadPlan.maxSnippets);
      expect(plan.evidenceSnippets, [
        'Unique note number 0',
        'Unique note number 1',
      ]);
    });

    test('no fabricated snippets — every snippet exists in the records', () {
      final records = _workThread3();
      final plan = engine.build(records, now: _base);
      final realText = {
        for (final record in records) ...[
          if (record.fear != null) record.fear!.trim(),
          if (record.stopCostNote != null) record.stopCostNote!.trim(),
        ],
      };
      expect(plan.evidenceSnippets, isNotEmpty);
      for (final snippet in plan.evidenceSnippets) {
        expect(
          realText,
          contains(snippet),
          reason: 'snippet "$snippet" must come from a real entry',
        );
      }
    });
  });

  group('Guided thread plan — language guardrails', () {
    test('settling language is cautious and only used when fading', () {
      final fading = engine.build(_fadingThread(), now: _base);
      expect(
        fading.alreadyCovered,
        contains('The work thread may be settling.'),
      );

      final returned = engine.build(_workThread3(), now: _base);
      expect(_planCopy(returned).toLowerCase(), isNot(contains('settling')));

      // Nothing is ever called resolved.
      for (final plan in [fading, returned]) {
        expect(_planCopy(plan).toLowerCase(), isNot(contains('resolved')));
      }
    });

    test('encouragement line is the calm default', () {
      final plan = engine.build(_workThread3(), now: _base);
      expect(
        plan.encouragementLine,
        'You do not need to solve everything today.',
      );
    });

    test('no banned, certainty, diagnostic, or shame wording', () {
      final scenarios = [
        engine.build(_workThread3(), now: _base),
        engine.build(_fadingThread(), now: _base),
        engine.build([
          _record(id: 'b0', daysAgo: 8, contextIds: const ['work']),
          _record(id: 'b1', daysAgo: 3, contextIds: const ['work']),
          _record(id: 'b2', daysAgo: 2, contextIds: const ['work']),
          _record(id: 'b3', daysAgo: 1, contextIds: const ['work']),
        ], now: _base),
        engine.build([
          _record(id: 'e0', daysAgo: 5, contextIds: const ['work']),
          _record(id: 'e1', contextIds: const ['work']),
        ], now: _base),
      ];

      for (final plan in scenarios) {
        final copy = _planCopy(plan).toLowerCase();
        for (final banned in const [
          'must',
          'should',
          'homework',
          'task',
          'unresolved problem',
          'failure',
          'lazy',
          'weak',
          'diagnos',
          'definitely',
          'always',
          'certain',
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
            reason: 'plan copy must not contain "$banned"',
          );
        }
      }
    });

    test('no VoiceMemory in any consumer copy', () {
      final plan = engine.build(_workThread3(), now: _base);
      expect(
        '${_planCopy(plan)} ${plan.evidenceSnippets.join(' ')}',
        isNot(contains('VoiceMemory')),
      );
    });
  });

  group('Guided thread plan card', () {
    testWidgets('renders the full plan without feeling like a task list', (
      tester,
    ) async {
      final plan = engine.build(_workThread3(), now: _base);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuidedThreadPlanCard(plan: plan),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Today\u2019s thread plan'), findsOneWidget);
      expect(find.text('Based on your recent archive'), findsOneWidget);
      expect(find.text('Already covered'), findsOneWidget);
      for (final line in plan.alreadyCovered) {
        expect(find.text(line), findsOneWidget);
      }
      for (final snippet in plan.evidenceSnippets) {
        expect(find.textContaining(snippet), findsOneWidget);
      }
      expect(find.text('Worth checking'), findsOneWidget);
      for (final line in plan.worthChecking) {
        expect(find.text(line), findsOneWidget);
      }
      expect(find.text('One small next recording'), findsOneWidget);
      expect(find.text(plan.nextPrompt), findsOneWidget);
      expect(
        find.text('You do not need to solve everything today.'),
        findsOneWidget,
      );
      expect(find.text('Record this'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('tapping Record this hands the prompt to the Record screen', (
      tester,
    ) async {
      final plan = engine.build(_workThread3(), now: _base);
      String? capturedPrompt;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: GuidedThreadPlanCard(plan: plan),
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

      final cta = find.byKey(const Key('guided_thread_plan_record_cta'));
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('RECORD_MARKER'), findsOneWidget);
      expect(capturedPrompt, 'What happened with the work thread today?');
    });

    testWidgets('renders nothing without a plan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuidedThreadPlanCard(plan: GuidedThreadPlan.none()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('guided_thread_plan_card')), findsNothing);
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('renders the plan directly under the thread evidence card', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 5000));
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

      final planFinder = find.byKey(const Key('guided_thread_plan_card'));
      final threadFinder = find.byKey(const Key('thread_return_evidence_card'));
      expect(planFinder, findsOneWidget);
      expect(threadFinder, findsOneWidget);
      expect(
        tester.getTopLeft(planFinder).dy,
        greaterThan(tester.getTopLeft(threadFinder).dy),
      );
    });

    testWidgets('hides the plan when not eligible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: [
              _record(id: 'x0', daysAgo: 1),
              _record(id: 'x1', optionId: 'guilty_resting'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guided_thread_plan_card')), findsNothing);
    });
  });
}