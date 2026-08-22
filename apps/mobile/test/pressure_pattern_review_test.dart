import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_review_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_review_model.dart';
import 'package:archiveme_mobile/widgets/pressure_retention/pressure_pattern_review_card.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
  bool choseToStop = false,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 8, 12).subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    choseToStop: choseToStop,
    transcript: 'pressure moment',
  );
}

/// Five entries: dominant option `could_not_stop`, repeated `work` context,
/// first (oldest) entry did not stop, two later stops.
List<PressureCheckInRecord> _fiveRecords() => [
  _record(id: 'e', choseToStop: true, contextIds: const ['work']),
  _record(id: 'd', daysAgo: 1, contextIds: const ['work']),
  _record(id: 'c', daysAgo: 2, choseToStop: true, contextIds: const ['work']),
  _record(id: 'b', daysAgo: 3, optionId: 'guilty_resting'),
  _record(id: 'a', daysAgo: 4, contextIds: const ['personal']),
];

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  const engine = PressurePatternReviewEngine();

  group('Pattern review engine', () {
    test('no review before 5 entries', () {
      final review = engine.build([
        _record(id: 'a', daysAgo: 3),
        _record(id: 'b', daysAgo: 2),
        _record(id: 'c', daysAgo: 1),
        _record(id: 'd'),
      ]);
      expect(review.hasReview, isFalse);
      expect(review.repeatingSummary, isNull);
      expect(review.strongestTrigger, isNull);
      expect(review.changeSummary, isNull);
    });

    test('review appears at 5+ entries', () {
      final review = engine.build(_fiveRecords());
      expect(review.hasReview, isTrue);
      expect(review.entryCount, 5);
      expect(review.repeatingSummary, isNotNull);
    });

    test('repeated pattern is detected', () {
      final review = engine.build(_fiveRecords());
      expect(review.repeatingSummary!.toLowerCase(), contains('keep going'));
      expect(
        review.repeatingSummary!.toLowerCase(),
        contains('keeps repeating'),
      );
    });

    test('repeated trigger/context is detected', () {
      final review = engine.build(_fiveRecords());
      expect(review.strongestTrigger!.toLowerCase(), contains('work'));
    });

    test('change since first entry is detected only when supported', () {
      // Supported: first entry didn't stop, later entries did.
      final supported = engine.build(_fiveRecords());
      expect(supported.changeSummary, isNotNull);
      expect(
        supported.changeSummary!.toLowerCase(),
        contains('chosen to stop'),
      );

      // Not supported: nobody ever stopped.
      final noStops = engine.build([
        for (var i = 0; i < 5; i++) _record(id: 'n$i', daysAgo: i),
      ]);
      expect(noStops.changeSummary, isNull);

      // Not supported: the first entry already stopped — nothing changed.
      final firstStopped = engine.build([
        _record(id: 'f0', daysAgo: 4, choseToStop: true),
        for (var i = 0; i < 3; i++) _record(id: 'f${i + 1}', daysAgo: i + 1),
        _record(id: 'f4', choseToStop: true),
      ]);
      expect(firstStopped.changeSummary, isNull);
    });

    test('weak evidence does not overclaim', () {
      // Five varied entries, no repeated context, no fears, no stops.
      final review = engine.build([
        _record(id: 'a', daysAgo: 4),
        _record(id: 'b', daysAgo: 3, optionId: 'guilty_resting'),
        _record(id: 'c', daysAgo: 2, optionId: 'had_to_prove_enough'),
        _record(id: 'd', daysAgo: 1, optionId: 'did_more_to_not_feel_behind'),
        _record(id: 'e', optionId: 'kept_going_to_feel_productive'),
      ]);

      final allCopy = [
        review.repeatingSummary,
        review.strongestTrigger,
        review.likelyCost,
        review.changeSummary,
        review.experimentSuggestion,
        PressurePatternReview.noChangeCopy,
        PressurePatternReview.insufficientCopy,
      ].whereType<String>().join(' ').toLowerCase();

      for (final overclaim in const [
        'always',
        'proven',
        'definitely',
        'certain',
        'guaranteed',
        'every time',
      ]) {
        expect(
          allCopy,
          isNot(contains(overclaim)),
          reason: 'review copy must not contain "$overclaim"',
        );
      }
      // No invented context from one-offs.
      expect(review.strongestTrigger!.toLowerCase(), isNot(contains('around')));
    });
  });

  group('Pattern review card', () {
    testWidgets('free user sees preview + locked full review CTA', (
      tester,
    ) async {
      final review = engine.build(_fiveRecords());
      await _pumpCard(
        tester,
        PressurePatternReviewCard(
          review: review,
          isPro: false,
          onUnlock: () {},
        ),
      );

      expect(find.text(PressurePatternReview.title), findsOneWidget);
      expect(
        find.text(PressurePatternReview.repeatingSectionTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_pattern_review_locked')),
        findsOneWidget,
      );
      expect(
        find.text(PressurePatternReviewCard.lockedRowLabel),
        findsOneWidget,
      );
      // Full sections stay hidden for free users.
      expect(
        find.byKey(const Key('pressure_pattern_review_full')),
        findsNothing,
      );
      expect(
        find.text(PressurePatternReview.experimentSectionTitle),
        findsNothing,
      );
    });

    testWidgets('pro user sees full review with all sections', (tester) async {
      final review = engine.build(_fiveRecords());
      await _pumpCard(
        tester,
        PressurePatternReviewCard(review: review, isPro: true),
      );

      expect(
        find.byKey(const Key('pressure_pattern_review_full')),
        findsOneWidget,
      );
      expect(
        find.text(PressurePatternReview.repeatingSectionTitle),
        findsOneWidget,
      );
      expect(find.text(PressurePatternReview.costSectionTitle), findsOneWidget);
      expect(
        find.text(PressurePatternReview.changeSectionTitle),
        findsOneWidget,
      );
      expect(
        find.text(PressurePatternReview.experimentSectionTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_pattern_review_locked')),
        findsNothing,
      );
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('no review on screen with 4 entries (reveal only)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 3600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: [
              for (var i = 0; i < 4; i++) _record(id: 'r$i', daysAgo: i),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pressure_pattern_reveal_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_pattern_review_card')),
        findsNothing,
      );
    });

    testWidgets('5 entries show reveal + review, and CTA opens subscription', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 4200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PressureInsightsScreen(
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
              records: _fiveRecords(),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('SUBSCRIPTION_MARKER')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pressure_pattern_reveal_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_pattern_review_card')),
        findsOneWidget,
      );

      final lockedRow = find.byKey(const Key('pressure_pattern_review_locked'));
      await tester.ensureVisible(lockedRow);
      await tester.pumpAndSettle();
      await tester.tap(lockedRow);
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
    });

    testWidgets('pro user sees full review on screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 4200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: true),
            records: _fiveRecords(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pressure_pattern_review_full')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_pattern_review_locked')),
        findsNothing,
      );
    });
  });

  group('No VoiceMemory consumer copy', () {
    testWidgets('free and pro review cards never show VoiceMemory', (
      tester,
    ) async {
      final review = engine.build(_fiveRecords());
      await _pumpCard(
        tester,
        Column(
          children: [
            PressurePatternReviewCard(
              review: review,
              isPro: false,
              onUnlock: () {},
            ),
            PressurePatternReviewCard(review: review, isPro: true),
          ],
        ),
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });
}