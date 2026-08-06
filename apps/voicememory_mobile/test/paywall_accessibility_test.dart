// Accessibility coverage for the paywall screen: the header restore action,
// live-region error announcements, plan-selector semantics, and 200%
// text-scale usability. Complements the copy/behavior assertions in
// paywall_conversion_clarity_test.dart and paywall_unavailable_buttons_test.dart
// rather than duplicating them.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/paywall_unavailable_state.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _pumpUnavailablePaywall(
  WidgetTester tester, {
  required bool billingReady,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/paywall',
    routes: [
      GoRoute(
        path: '/record',
        builder: (context, state) =>
            const Scaffold(body: Text('Record fallback')),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) =>
            PaywallScreen(billingReadyOverride: () => billingReady),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    final loading = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isNotEmpty;
    final unavailable = find
        .text(PaywallUnavailableState.continueWithoutProLabel)
        .evaluate()
        .isNotEmpty;
    if (!loading && unavailable) break;
  }
}

void main() {
  late Directory tempDir;
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'paywall_accessibility_test',
    );
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
    );
  });

  group('Paywall accessibility', () {
    testWidgets('remains usable at 200% text scale with no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2.0)),
                  child: PaywallScreen(billingReadyOverride: () => false),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pump();
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final loading = find
            .byType(CircularProgressIndicator)
            .evaluate()
            .isNotEmpty;
        if (!loading) break;
      }

      expect(tester.takeException(), isNull);

      // The body is a scroll view, so a long page at 2x text is expected —
      // dragging through it should never throw a render overflow.
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'header restore action is reachable by a screen reader without duplicating the visible button label',
      (tester) async {
        await _pumpUnavailablePaywall(tester, billingReady: false);

        final headerAction = find.byKey(
          const Key('paywall_header_restore_action'),
        );
        expect(headerAction, findsOneWidget);
        expect(
          tester.widget<IconButton>(headerAction).tooltip,
          ConsumerUiCopy.restorePurchases,
        );

        // The icon itself is icon-only; the accessible name comes from the
        // tooltip, not a second on-screen "Restore purchases" label stacked
        // in the header (that would double-announce to a screen reader).
        expect(
          find.descendant(
            of: headerAction,
            matching: find.text(ConsumerUiCopy.restorePurchases),
          ),
          findsNothing,
        );
      },
    );

    test(
      'header restore action is gated on the same loaded-entitlement check as the bottom-of-page CTA',
      () {
        // Pumping a real "already Pro" paywall requires a resolved
        // EntitlementCache/BillingService round-trip; the structural
        // guarantee — no restore CTA once `_entitlements?.isPro == true` —
        // is asserted directly against the source, matching this file's
        // other source-contract checks below.
        final source = File(
          'lib/screens/paywall_screen.dart',
        ).readAsStringSync();
        expect(
          source,
          contains(
            'if (_loading || _entitlements?.isPro == true) return null;',
          ),
        );
      },
    );
  });

  group('Paywall plan selector semantics (source contract)', () {
    // Pumping a real loaded-offerings paywall requires a full RevenueCat
    // Offerings/Package/StoreProduct object graph, which is store-SDK-owned
    // and not constructible from this test target. Instead we assert the
    // structural contract directly against the source, matching this
    // repo's existing pattern for widget internals that require live store
    // data (see paywall_conversion_clarity_test.dart's source-string checks).
    test(
      'plan cards expose button/selected semantics and hide the decorative radio icon from screen readers',
      () {
        final source = File(
          'lib/screens/paywall_screen.dart',
        ).readAsStringSync();
        expect(
          source,
          contains(
            'child: Semantics(\n          button: true,\n          selected: selected,',
          ),
        );
        expect(
          source,
          contains('ExcludeSemantics(\n                  child: Icon('),
        );
      },
    );

    test('a load error is announced via a live region', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(
        source,
        contains(
          'Semantics(\n              liveRegion: true,\n              child: Text(\n                _error!,',
        ),
      );
    });
  });
}
