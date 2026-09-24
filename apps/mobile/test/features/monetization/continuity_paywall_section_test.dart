import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/continuity_paywall_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PremiumAccess.apply(PremiumEntitlement.free));

  testWidgets('continuity copy and purchase hooks are wired', (tester) async {
    var purchased = false;
    var restored = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(
            MonetizationRevenueCatService(
              purchaseOverride: () async {
                purchased = true;
                return PremiumEntitlement.active;
              },
              restoreOverride: () async {
                restored = true;
                return PremiumEntitlement.free;
              },
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ContinuityPaywallSection()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('paywall_benefit_watch')), findsOneWidget);
    expect(find.textContaining('on this device'), findsWidgets);
    expect(find.textContaining('Encrypted cloud backups'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('does not turn it on'),
      80,
    );
    expect(find.textContaining('Automated Obsidian sync'), findsWidgets);
    expect(find.textContaining('does not turn it on'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('https://archiveme.app'),
      80,
    );
    expect(find.textContaining('Pattern synthesis'), findsWidgets);
    expect(find.textContaining('https://archiveme.app'), findsOneWidget);

    await tester.tap(find.byKey(const Key('paywall_restore')));
    await tester.pump();
    expect(restored, isTrue);

    await tester.tap(find.byKey(const Key('paywall_purchase')));
    await tester.pump();
    expect(purchased, isTrue);
    expect(find.text('Premium is active'), findsOneWidget);
    expect(find.byKey(const Key('paywall_web_handoff')), findsOneWidget);
  });
}
