import 'package:archiveme_mobile/features/prove_enough/monthly_ambition_pressure_review_engine.dart';
import 'package:archiveme_mobile/features/prove_enough/monthly_ambition_pressure_review_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_contradiction_model.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/prove_enough/monthly_ambition_pressure_review_card.dart';
import 'package:archiveme_research/screens/monthly_ambition_pressure_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _pressureA =
    'I kept working late because stopping made me feel behind and not enough.';
const _pressureB =
    'I did more to prove I was productive even though I was tired and drained.';
const _pressureC =
    'I pushed through more work because rest felt unsafe and I felt behind.';
const _restGuilt =
    'I tried to rest during quiet time but felt guilt about stopping and being lazy.';
const _choiceA =
    'I wanted to finish because I enjoyed it and chose to stay with a clear reason.';
const _choiceB =
    'I decided to stop when satisfied because the work felt meaningful and clear reason.';

JournalEntry _entryAt(String id, String text, DateTime createdAt) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: text,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: text,
      repeatedSignal: '',
    ),
  );
}

MonthlyAmbitionPressureReview _sampleReview({
  AmbitionPressureDirection direction = AmbitionPressureDirection.mixed,
}) {
  return MonthlyAmbitionPressureReview(
    monthLabel: 'June',
    totalProvingMoments: 4,
    pressureMomentCount: 2,
    choiceMomentCount: 1,
    restGuiltCount: 1,
    contradictionCount: 0,
    topTriggers: const ['Work deadlines (2)', 'Comparison (1)'],
    direction: direction,
    directionEvidence: const [
      'Pressure moments: 2 this month vs 1 last month.',
      'Recent pressure: I kept working late because stopping made me feel behind and not enough.',
    ],
    whatChanged: 'Pressure moments increased compared with last month.',
    nextMonthMission: 'Capture what stopping feels like it would cost you.',
    whatRepeated: _pressureA,
    whatSeemedToCostYou: _restGuilt,
    choiceVsPressureSummary: 'Pressure: 2 · Choice: 1',
    restGuiltSummary: _restGuilt,
    triggerMapSummary: 'Work deadlines (2)\nComparison (1)',
  );
}

void main() {
  const engine = MonthlyAmbitionPressureReviewEngine();
  final juneNow = DateTime(2026, 6, 15);

  group('MonthlyAmbitionPressureReviewEngine', () {
    test('stronger direction when pressure ratio rises month over month', () {
      final review = engine.build(
        entries: [
          _entryAt('m1', _pressureA, DateTime(2026, 5, 2)),
          _entryAt('m2', _restGuilt, DateTime(2026, 5, 12)),
          _entryAt('j1', _pressureB, DateTime(2026, 6, 2)),
          _entryAt('j2', _pressureC, DateTime(2026, 6, 8)),
          _entryAt('j3', _restGuilt, DateTime(2026, 6, 12)),
        ],
        now: juneNow,
      );

      expect(review.direction, AmbitionPressureDirection.stronger);
      expect(review.direction.copy, contains('stronger'));
    });

    test('fading direction when choice moments dominate', () {
      final review = engine.build(
        entries: [
          _entryAt('j1', _choiceA, DateTime(2026, 6, 2)),
          _entryAt('j2', _choiceB, DateTime(2026, 6, 10)),
        ],
        now: juneNow,
      );

      expect(review.direction, AmbitionPressureDirection.fading);
      expect(review.direction.copy, contains('fading'));
    });

    test('mixed direction when pressure and choice both appear', () {
      final review = engine.build(
        entries: [
          _entryAt('j1', _pressureA, DateTime(2026, 6, 2)),
          _entryAt('j2', _choiceA, DateTime(2026, 6, 10)),
        ],
        now: juneNow,
      );

      expect(review.direction, AmbitionPressureDirection.mixed);
      expect(review.direction.copy, contains('mixed'));
    });

    test('unclear direction with too little data', () {
      final review = engine.build(
        entries: [_entryAt('j1', _pressureA, DateTime(2026, 6, 2))],
        now: juneNow,
      );

      expect(review.direction, AmbitionPressureDirection.unclear);
      expect(review.direction.copy, contains('ArchiveMe needs more moments'));
    });

    test('evidence excerpts are not invented', () {
      const transcript =
          'I kept working late because stopping made me feel behind and not enough.';
      final review = engine.build(
        entries: [
          _entryAt('j1', transcript, DateTime(2026, 6, 2)),
          _entryAt('j2', _pressureB, DateTime(2026, 6, 10)),
        ],
        now: juneNow,
      );

      final combined = [
        review.whatRepeated,
        review.whatSeemedToCostYou,
        review.restGuiltSummary,
        ...review.directionEvidence,
      ].join('\n').toLowerCase();

      expect(combined, contains(transcript.toLowerCase().split(' ').first));
      expect(combined, isNot(contains('invented')));
    });

    test('fading when contradictions increase month over month', () {
      final review = engine.build(
        entries: [
          _entryAt('m1', _pressureA, DateTime(2026, 5, 2)),
          _entryAt('m2', _pressureB, DateTime(2026, 5, 12)),
          _entryAt('j1', _choiceA, DateTime(2026, 6, 2)),
          _entryAt('j2', _choiceB, DateTime(2026, 6, 10)),
        ],
        contradictions: [
          ProveEnoughContradictionRecord(
            id: 'c1',
            option: ProveEnoughContradictionOption.restedWithoutGuilt,
            savedAt: DateTime(2026, 6, 11),
            journeyId: 'j1',
            entryId: 'j2',
          ),
        ],
        now: juneNow,
      );

      expect(review.direction, AmbitionPressureDirection.fading);
    });
  });

  group('MonthlyAmbitionPressureReviewScreen', () {
    testWidgets('free user sees Pro preview after free review used', (
      tester,
    ) async {
      final review = _sampleReview();

      await tester.binding.setSurfaceSize(const Size(390, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyAmbitionPressureReviewScreen(
            initialReview: review,
            initialEntitlements: PremiumEntitlements.free(),
            canViewFull: false,
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.text(MonthlyAmbitionPressureReview.screenTitle),
        findsOneWidget,
      );
      expect(
        find.text(MonthlyAmbitionPressureReview.proPreviewTitle),
        findsOneWidget,
      );
      expect(
        find.text(MonthlyAmbitionPressureReview.proPreviewBody),
        findsOneWidget,
      );
      expect(
        find.text(MonthlyAmbitionPressureReview.whatRepeatedTitle),
        findsNothing,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('Pro user sees full monthly review sections', (tester) async {
      final review = _sampleReview(
        direction: AmbitionPressureDirection.stronger,
      );

      await tester.binding.setSurfaceSize(const Size(390, 1600));
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyAmbitionPressureReviewScreen(
            initialReview: review,
            initialEntitlements: const PremiumEntitlements(
              tier: BillingTier.pro,
              entitlementIds: ['pro'],
              billingConnected: true,
              source: 'test',
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      for (final title in [
        MonthlyAmbitionPressureReview.whatRepeatedTitle,
        MonthlyAmbitionPressureReview.whatCostTitle,
        MonthlyAmbitionPressureReview.choiceVsPressureTitle,
        MonthlyAmbitionPressureReview.restGuiltTitle,
        MonthlyAmbitionPressureReview.triggerMapTitle,
        MonthlyAmbitionPressureReview.directionTitle,
        MonthlyAmbitionPressureReview.nextMissionTitle,
      ]) {
        await tester.scrollUntilVisible(find.text(title), 300);
        await _pumpFrames(tester, frames: 2);
        expect(find.text(title), findsOneWidget);
      }

      expect(
        find.text(MonthlyAmbitionPressureReview.proPreviewTitle),
        findsNothing,
      );
      expect(find.text(review.direction.copy), findsOneWidget);
    });

    testWidgets('See Pro CTA routes to paywall', (tester) async {
      final review = _sampleReview();
      var routed = false;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => MonthlyAmbitionPressureReviewScreen(
              initialReview: review,
              initialEntitlements: PremiumEntitlements.free(),
              canViewFull: false,
              onSeePro: () => context.push('/subscription'),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) {
              routed = true;
              return const Scaffold(body: Text('Paywall screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpFrames(tester);

      await tester.tap(
        find.byKey(const Key('monthly_ambition_pressure_review_see_pro_cta')),
      );
      await _pumpFrames(tester);

      expect(routed, isTrue);
      expect(find.text('Paywall screen'), findsOneWidget);
    });
  });

  group('MonthlyAmbitionPressureReviewCard', () {
    testWidgets('Pro preview card shows locked copy', (tester) async {
      final review = _sampleReview();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthlyAmbitionPressureReviewCard(
              review: review,
              canViewFull: false,
              onSeePro: () {},
            ),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('monthly_ambition_pressure_review_pro_preview')),
        findsOneWidget,
      );
      expect(
        find.text(MonthlyAmbitionPressureReview.proPreviewTitle),
        findsOneWidget,
      );
      expect(
        find.text(MonthlyAmbitionPressureReview.proPreviewCta),
        findsOneWidget,
      );
    });
  });
}