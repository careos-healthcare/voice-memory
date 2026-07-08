import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/paywall_cta_lift/paywall_cta_lift_analytics.dart';
import 'package:voicememory_mobile/features/paywall_cta_lift/paywall_cta_lift_copy.dart';
import 'package:voicememory_mobile/features/paywall_cta_lift/paywall_cta_lift_engine.dart';
import 'package:voicememory_mobile/widgets/pro/paywall_cta_lift_block.dart';

void main() {
  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    PaywallCtaLiftAnalytics.resetForTest();
  });

  group('PaywallCtaLiftCopy', () {
    test('uses sharpened proof-connected copy', () {
      expect(PaywallCtaLiftCopy.title, 'Keep the evidence trail');
      expect(
        PaywallCtaLiftCopy.body,
        'The proof you just saw is only the start. Pro keeps the full timeline as more moments return, change, or fade.',
      );
      expect(
        PaywallCtaLiftCopy.supportLine,
        'Not more chat. The longer record behind the pattern.',
      );
      expect(
        PaywallCtaLiftCopy.purchaseCtaLine,
        'Keep the timeline before it disappears into separate moments.',
      );
    });
  });

  group('PaywallCtaLiftEngine', () {
    test('shows only for valueMoment source', () {
      expect(
        PaywallCtaLiftEngine.shouldShowBlock(
          source: PaywallSource.valueMoment,
          isPro: false,
        ),
        isTrue,
      );
      expect(
        PaywallCtaLiftEngine.shouldShowBlock(
          source: PaywallSource.generalPro,
          isPro: false,
        ),
        isFalse,
      );
    });

    test('hidden when beta off', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        PaywallCtaLiftEngine.shouldShowBlock(
          source: PaywallSource.valueMoment,
          isPro: false,
        ),
        isFalse,
      );
    });

    test('hidden for Pro users', () {
      expect(
        PaywallCtaLiftEngine.shouldShowBlock(
          source: PaywallSource.valueMoment,
          isPro: true,
        ),
        isFalse,
      );
    });
  });

  group('PaywallCtaLiftBlock', () {
    testWidgets('renders sharpened block above plans integration copy', (tester) async {
      final result = PaywallCtaLiftEngine.build(
        source: PaywallSource.valueMoment,
        analyticsSource: 'test',
        isPro: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaywallCtaLiftBlock.test(result: result),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('paywall_cta_lift_block')), findsOneWidget);
      expect(find.text(PaywallCtaLiftCopy.title), findsOneWidget);
      expect(find.text(PaywallCtaLiftCopy.supportLine), findsOneWidget);
    });
  });

  group('PaywallCtaLiftAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      PaywallCtaLiftAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      final result = PaywallCtaLiftEngine.build(
        source: PaywallSource.valueMoment,
        analyticsSource: 'value_moment',
        isPro: false,
      );
      PaywallCtaLiftAnalytics.seen(result: result);

      expect(events, [PaywallCtaLiftAnalytics.seenEvent]);
      expect(properties.single.keys, containsAll(['source', 'proof_connected']));
      expect(properties.single.containsKey('transcript'), isFalse);
    });
  });

  group('Integration placement', () {
    test('paywall screen integrates block above plan cards', () {
      final source = File('lib/screens/paywall_screen.dart').readAsStringSync();
      expect(source, contains('PaywallCtaLiftBlock'));
      expect(source, contains('PaywallCtaLiftEngine.build'));
      expect(source, contains('paywall_cta_lift_purchase_line'));
      expect(source, contains('purchaseCtaLine'));
    });

    test('testing screen includes compact preview', () {
      final source =
          File('lib/screens/testing_archiveme_screen.dart').readAsStringSync();
      expect(source, contains('PaywallCtaLiftBlock.test'));
    });
  });
}
