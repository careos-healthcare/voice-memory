import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  bool choseToStop = false,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 8, 12).subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    choseToStop: choseToStop,
    transcript: 'pressure moment',
  );
}

List<PressureCheckInRecord> _fiveRecords() => [
      for (var i = 0; i < 5; i++)
        _record(id: 'r$i', daysAgo: i, contextIds: const ['work']),
    ];

/// Pumps the paywall screen with optional [args]; billing is not configured
/// in tests, so the source-aware copy renders on the unavailable fallback.
Future<void> _pumpPaywall(WidgetTester tester, {PaywallRouteArgs? args}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PaywallScreen(triggerArgs: args),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps a free-tier Pressure Insights screen with a `/subscription` route
/// that captures the [PaywallRouteArgs] it was opened with.
Future<PaywallRouteArgs? Function()> _pumpInsightsWithPaywallCapture(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
}) async {
  PaywallRouteArgs? captured;

  await tester.binding.setSurfaceSize(const Size(390, 4200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => PressureInsightsScreen(
          entitlementReader: FakeArchiveEntitlementReader(pro: false),
          records: records,
        ),
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) {
          captured = state.extra as PaywallRouteArgs?;
          return const Scaffold(
            body: Center(child: Text('SUBSCRIPTION_MARKER')),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return () => captured;
}

void main() {
  group('Paywall source copy variants', () {
    test('pressure pattern history shows pressure-specific copy', () {
      final copy =
          PaywallSourceCopy.forSource(PaywallSource.pressurePatternHistory);
      expect(copy.headline, 'Unlock your full pressure pattern');
      expect(
        copy.subheadline,
        'See where this keeps repeating, what it may be costing you, '
        'and what changed over time.',
      );
      expect(copy.bullets, const [
        'Full pressure pattern history',
        'Your first pressure review',
        'Evidence confidence',
        'Ask your archive where this repeats',
        'Return triggers for the real-life pressure moment',
      ]);
      expect(copy.cta, 'Unlock ArchiveMe Pro');
    });

    test('full pressure review shares the pressure-specific copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.pressureReview);
      expect(copy.headline, 'Unlock your full pressure pattern');
      expect(copy.cta, 'Unlock ArchiveMe Pro');
      expect(copy.bullets, contains('Your first pressure review'));
    });

    test('Ask the Archive shows archive question copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.askArchive);
      expect(copy.headline, 'Ask your archive what keeps repeating');
      expect(
        copy.subheadline,
        'ArchiveMe uses your saved moments to show patterns with '
        'evidence, not generic advice.',
      );
      expect(copy.bullets, const [
        'Ask where this pressure repeats',
        'See the evidence behind the answer',
        'Track how the pattern changes',
        'Unlock full pressure reviews',
      ]);
    });

    test('start here today shows thread-connection copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.startHereToday);
      expect(copy.headline, 'Keep the thread connected');
      expect(
        copy.subheadline,
        'ArchiveMe uses what you record to connect today\u2019s '
        'pressure with what shows up again later.',
      );
      expect(copy.bullets, const [
        'Track when this pattern returns',
        'See how the evidence changes',
        'Ask your archive what keeps repeating',
      ]);
      expect(copy.cta, 'Unlock Pro');
    });

    test('daily suggestion shares the thread-connection copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.dailySuggestion);
      expect(copy.headline, 'Keep the thread connected');
      expect(copy.cta, 'Unlock Pro');
      expect(
        copy.bullets,
        contains('Track when this pattern returns'),
      );
    });

    test('daily-prompt copy avoids overclaiming language', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.startHereToday);
      final all = [copy.headline, copy.subheadline, copy.cta, ...copy.bullets]
          .join(' ')
          .toLowerCase();
      for (final banned in ['ai therapist', 'diagnosis', 'fix yourself']) {
        expect(all, isNot(contains(banned)));
      }
    });

    test('general Pro fallback copy', () {
      final copy = PaywallSourceCopy.forSource(PaywallSource.generalPro);
      expect(copy.headline, 'Unlock ArchiveMe Pro');
      expect(
        copy.subheadline,
        'Turn saved moments into patterns, reviews, and evidence you '
        'can come back to.',
      );
      expect(copy.bullets, isNotEmpty);
    });

    test('source ids round-trip through fromId', () {
      for (final source in PaywallSource.values) {
        expect(PaywallSource.fromId(source.id), source);
      }
      expect(PaywallSource.fromId('unknown'), isNull);
      expect(PaywallSource.fromId(null), isNull);
    });

    test('no VoiceMemory in any source copy variant', () {
      for (final source in PaywallSource.values) {
        final copy = PaywallSourceCopy.forSource(source);
        final all = [copy.headline, copy.subheadline, copy.cta, ...copy.bullets]
            .join(' ');
        expect(all, isNot(contains('VoiceMemory')),
            reason: '${source.id} copy must not mention VoiceMemory');
      }
    });
  });

  group('Paywall screen source-aware headline', () {
    testWidgets('pressure pattern source shows pressure headline/subheadline',
        (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(
          source: PaywallSource.pressurePatternHistory,
        ),
      );
      expect(find.text('Unlock your full pressure pattern'), findsOneWidget);
      expect(
        find.text(
          'See where this keeps repeating, what it may be costing you, '
          'and what changed over time.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('review source shows pressure-specific copy', (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.pressureReview),
      );
      expect(find.text('Unlock your full pressure pattern'), findsOneWidget);
    });

    testWidgets('Ask the Archive source shows archive question copy',
        (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.askArchive),
      );
      expect(
        find.text('Ask your archive what keeps repeating'),
        findsOneWidget,
      );
      expect(
        find.text(
          'ArchiveMe uses your saved moments to show patterns with '
          'evidence, not generic advice.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('start here today source shows thread headline',
        (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.startHereToday),
      );
      expect(find.text('Keep the thread connected'), findsOneWidget);
      expect(
        find.text(
          'ArchiveMe uses what you record to connect today\u2019s '
          'pressure with what shows up again later.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('daily suggestion source shows thread headline',
        (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.dailySuggestion),
      );
      expect(find.text('Keep the thread connected'), findsOneWidget);
    });

    testWidgets('general Pro source shows fallback headline', (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.generalPro),
      );
      expect(find.text('Unlock ArchiveMe Pro'), findsOneWidget);
      expect(
        find.text(
          'Turn saved moments into patterns, reviews, and evidence you '
          'can come back to.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no source keeps the existing default headline',
        (tester) async {
      await _pumpPaywall(tester);
      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });

  group('Purchase confidence layer', () {
    test('suggestion sources get the continuity confidence lines', () {
      expect(
        PaywallConfidenceCopy.forSource(PaywallSource.startHereToday),
        PaywallConfidenceCopy.suggestion,
      );
      expect(
        PaywallConfidenceCopy.forSource(PaywallSource.dailySuggestion),
        PaywallConfidenceCopy.suggestion,
      );
      expect(
        PaywallConfidenceCopy.suggestion,
        contains('Today\u2019s save stays in your archive.'),
      );
      expect(
        PaywallConfidenceCopy.suggestion,
        contains('Cancel anytime through the App Store.'),
      );
    });

    test('generic and non-suggestion sources get the default lines', () {
      expect(PaywallConfidenceCopy.forSource(null), PaywallConfidenceCopy.generic);
      expect(
        PaywallConfidenceCopy.forSource(PaywallSource.generalPro),
        PaywallConfidenceCopy.generic,
      );
      expect(
        PaywallConfidenceCopy.forSource(PaywallSource.pressureReview),
        PaywallConfidenceCopy.generic,
      );
      expect(
        PaywallConfidenceCopy.generic,
        contains('Your archive is yours.'),
      );
      expect(
        PaywallConfidenceCopy.generic,
        contains('Cancel anytime through the App Store.'),
      );
    });

    test('confidence copy has no scarcity, loss framing, or VoiceMemory', () {
      final all = [
        ...PaywallConfidenceCopy.generic,
        ...PaywallConfidenceCopy.suggestion,
      ].join(' ').toLowerCase();
      for (final banned in [
        'limited time',
        'last chance',
        'expires',
        'lose access',
        'deleted',
        'disappear',
        'removed',
        'voicememory',
      ]) {
        expect(all, isNot(contains(banned)),
            reason: 'confidence copy must not contain "$banned"');
      }
    });

    testWidgets('confidence copy renders on suggestion-source paywall',
        (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.startHereToday),
      );

      expect(
        find.text('Today\u2019s save stays in your archive.'),
        findsOneWidget,
      );
      expect(
        find.text('Pro keeps the thread connected across future recordings.'),
        findsOneWidget,
      );
      expect(
        find.text('Cancel anytime through the App Store.'),
        findsOneWidget,
      );
      // Suggestion headline renders alongside the confidence copy.
      expect(find.text('Keep the thread connected'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('confidence copy renders on the generic paywall',
        (tester) async {
      await _pumpPaywall(tester);

      expect(find.text('Your archive is yours.'), findsOneWidget);
      expect(
        find.text('Today\u2019s saves stay even if you don\u2019t upgrade.'),
        findsOneWidget,
      );
      expect(
        find.text('Cancel anytime through the App Store.'),
        findsOneWidget,
      );
      // Existing generic copy stays unchanged.
      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });

  group('Pro thread preview', () {
    test('preview shows only for suggestion sources', () {
      expect(PaywallProThreadPreview.showFor(PaywallSource.startHereToday),
          isTrue);
      expect(PaywallProThreadPreview.showFor(PaywallSource.dailySuggestion),
          isTrue);
      expect(PaywallProThreadPreview.showFor(PaywallSource.generalPro),
          isFalse);
      expect(
          PaywallProThreadPreview.showFor(PaywallSource.pressureReview),
          isFalse);
      expect(PaywallProThreadPreview.showFor(null), isFalse);
    });

    test('preview copy avoids banned and loss-implying wording', () {
      final all = [
        PaywallProThreadPreview.heading,
        for (final row in PaywallProThreadPreview.rows) ...[
          row.title,
          row.body,
        ],
      ].join(' ').toLowerCase();
      for (final banned in [
        'must',
        'should',
        'problem',
        'unresolved',
        'failure',
        'lazy',
        'weak',
        'fix',
        'diagnose',
        'limited time',
        'last chance',
        'expires',
        'lose access',
        'deleted',
        'disappear',
        'removed',
        'voicememory',
      ]) {
        expect(all, isNot(contains(banned)),
            reason: 'preview copy must not contain "$banned"');
      }
    });

    testWidgets('"What Pro continues" renders for startHereToday',
        (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.startHereToday),
      );

      expect(find.text('What Pro continues'), findsOneWidget);
      expect(find.text('This thread'), findsOneWidget);
      expect(
        find.text('Keep today\u2019s save connected to future recordings.'),
        findsOneWidget,
      );
      expect(find.text('Pattern returns'), findsOneWidget);
      expect(
        find.text('See when the same pressure shows up again.'),
        findsOneWidget,
      );
      expect(find.text('Evidence changes'), findsOneWidget);
      expect(
        find.text('Notice if the story is getting stronger or fading.'),
        findsOneWidget,
      );
      // Confidence copy and restore stay present alongside the preview.
      expect(
        find.text('Today\u2019s save stays in your archive.'),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    testWidgets('preview renders for dailySuggestion', (tester) async {
      await _pumpPaywall(
        tester,
        args: const PaywallRouteArgs(source: PaywallSource.dailySuggestion),
      );
      expect(find.text('What Pro continues'), findsOneWidget);
      expect(
        find.byKey(const Key('paywall_pro_thread_preview')),
        findsOneWidget,
      );
    });

    testWidgets('preview does not render for the generic paywall',
        (tester) async {
      await _pumpPaywall(tester);

      expect(find.text('What Pro continues'), findsNothing);
      expect(
        find.byKey(const Key('paywall_pro_thread_preview')),
        findsNothing,
      );
      // Generic headline and confidence copy remain unchanged.
      expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
      expect(find.text('Your archive is yours.'), findsOneWidget);
    });
  });

  group('Locked CTAs route with the right paywall source', () {
    testWidgets('locked pattern history row passes pattern history source',
        (tester) async {
      final captured = await _pumpInsightsWithPaywallCapture(
        tester,
        records: _fiveRecords(),
      );

      final row = find.byKey(const Key('pressure_pattern_locked_history'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      expect(captured()?.source, PaywallSource.pressurePatternHistory);
      expect(captured()?.sourceRoute, '/pressure-insights');
    });

    testWidgets('locked review row passes pressure review source',
        (tester) async {
      final captured = await _pumpInsightsWithPaywallCapture(
        tester,
        records: _fiveRecords(),
      );

      final row = find.byKey(const Key('pressure_pattern_review_locked'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      expect(captured()?.source, PaywallSource.pressureReview);
    });

    testWidgets('locked Ask the Archive question passes archive source',
        (tester) async {
      final captured = await _pumpInsightsWithPaywallCapture(
        tester,
        records: _fiveRecords(),
      );

      final question = find.text('Where does this repeat?');
      await tester.ensureVisible(question);
      await tester.pumpAndSettle();
      await tester.tap(question);
      await tester.pumpAndSettle();

      expect(find.text('SUBSCRIPTION_MARKER'), findsOneWidget);
      expect(captured()?.source, PaywallSource.askArchive);
    });
  });
}
