import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/paywall_objection_handling/paywall_objection_analytics.dart';
import 'package:voicememory_mobile/features/paywall_objection_handling/paywall_objection_copy.dart';
import 'package:voicememory_mobile/features/paywall_objection_handling/paywall_objection_engine.dart';
import 'package:voicememory_mobile/features/paywall_objection_handling/paywall_objection_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/widgets/pro/paywall_objection_section.dart';

const _privateTranscript =
    'I had no capacity but I said yes again to the extra meeting today.';

Future<void> _pumpPaywall(WidgetTester tester, {PaywallRouteArgs? args}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => PaywallScreen(
              triggerArgs: args,
              delayedPaywallProofGateOverride: () => true,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find
        .byKey(const Key('paywall_unavailable_body'))
        .evaluate()
        .isNotEmpty) {
      break;
    }
  }
}

void main() {
  setUp(PaywallObjectionAnalytics.resetForTest);
  tearDown(PaywallObjectionAnalytics.resetForTest);

  group('PaywallObjectionCopy', () {
    test('defines all five objection rows', () {
      final rows = PaywallObjectionCopy.allRows();
      expect(rows, hasLength(5));
      expect(rows.map((row) => row.question), [
        PaywallObjectionCopy.notJournalingQuestion,
        PaywallObjectionCopy.notAiChatQuestion,
        PaywallObjectionCopy.whatProKeepsQuestion,
        PaywallObjectionCopy.stayInControlQuestion,
        PaywallObjectionCopy.restorePurchasesQuestion,
      ]);
    });

    test('no therapy/medical claims', () {
      final blob = PaywallObjectionCopy.allDisplayedStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in PaywallObjectionCopy.bannedMedicalTerms) {
        expect(blob, isNot(contains(banned)));
      }
    });

    test('no fake testimonial/scarcity', () {
      final blob = PaywallObjectionCopy.allDisplayedStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in PaywallObjectionCopy.bannedFakeClaims) {
        expect(blob, isNot(contains(banned)));
      }
    });

    test('no private journal text', () {
      final blob = PaywallObjectionCopy.allDisplayedStrings().join('\n');
      expect(
        blob.toLowerCase(),
        isNot(contains(_privateTranscript.toLowerCase())),
      );
    });
  });

  group('PaywallObjectionEngine', () {
    test('builds section for general and proof-connected paywalls', () {
      final general = PaywallObjectionEngine.build(
        source: PaywallSource.generalPro,
        surface: 'paywall_screen',
      );
      final proofConnected = PaywallObjectionEngine.build(
        source: PaywallSource.valueMoment,
        surface: 'paywall_screen',
      );

      expect(general.shouldShow, isTrue);
      expect(proofConnected.shouldShow, isTrue);
      expect(general.rows, hasLength(5));
      expect(proofConnected.rows, hasLength(5));
      expect(general.source, PaywallSource.generalPro.id);
      expect(proofConnected.source, PaywallSource.valueMoment.id);
    });
  });

  group('PaywallObjectionAnalytics', () {
    test('metadata-only analytics', () {
      final events = <({String event, Map<String, Object> props})>[];
      PaywallObjectionAnalytics.captureForTest = (event, props) {
        events.add((event: event, props: props));
      };

      PaywallObjectionAnalytics.sectionSeen(
        source: 'value_moment',
        surface: 'paywall_screen',
      );
      PaywallObjectionAnalytics.expanded(
        source: 'value_moment',
        surface: 'paywall_screen',
        objectionId: PaywallObjectionId.notJournaling,
      );

      expect(events, hasLength(2));
      expect(events[0].event, PaywallObjectionAnalytics.seenEvent);
      expect(events[0].props.keys.toSet(), {'source', 'surface'});
      expect(events[1].event, PaywallObjectionAnalytics.expandedEvent);
      expect(events[1].props.keys.toSet(), {
        'source',
        'surface',
        'objection_id',
      });
      expect(events[1].props['objection_id'], 'not_journaling');
    });
  });

  group('PaywallObjectionSection widget', () {
    testWidgets('renders all objection rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallObjectionSection(
              result: PaywallObjectionEngine.build(
                source: PaywallSource.generalPro,
                surface: 'paywall_screen',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('paywall_objection_section')),
        findsOneWidget,
      );
      for (final row in PaywallObjectionCopy.allRows()) {
        expect(find.text(row.question), findsOneWidget);
      }
    });

    testWidgets('tracks expanded metadata when row opens', (tester) async {
      final events = <({String event, Map<String, Object> props})>[];
      PaywallObjectionAnalytics.captureForTest = (event, props) {
        events.add((event: event, props: props));
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallObjectionSection(
              result: PaywallObjectionEngine.build(
                source: PaywallSource.valueMoment,
                surface: 'paywall_screen',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(PaywallObjectionCopy.notJournalingQuestion));
      await tester.pumpAndSettle();

      expect(
        events.where((e) => e.event == PaywallObjectionAnalytics.seenEvent),
        hasLength(1),
      );
      expect(
        events.where((e) => e.event == PaywallObjectionAnalytics.expandedEvent),
        hasLength(1),
      );
      expect(
        events.last.props['objection_id'],
        PaywallObjectionId.notJournaling.analyticsValue,
      );
    });
  });

  group('PaywallScreen integration', () {
    test('paywall wires objection section for available plans body', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('_paywallObjectionSectionResult.shouldShow'));
      expect(source, contains('_paywallObjectionSection()'));
    });

    testWidgets('restore purchases remains visible', (tester) async {
      await _pumpPaywall(tester);

      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });

    test('purchase flow wiring untouched', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('ArchivePaywallCopy.purchaseStarting'));
      expect(source, contains('_PaywallBusyKind.purchase'));
      expect(source, contains('_PaywallBusyKind.restore'));
      expect(source, contains('_continue'));
      expect(source, isNot(contains('purchasePackage(')));
    });

    test('protected billing constants unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });
  });
}
