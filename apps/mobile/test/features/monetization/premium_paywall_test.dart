import 'package:archiveme_mobile/features/ai_coaching/gemma_summary_panel.dart';
import 'package:archiveme_mobile/features/ai_coaching/gemma_summary_service.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/continuity_paywall_section.dart';
import 'package:archiveme_mobile/features/monetization/ui/paywall_view.dart';
import 'package:archiveme_mobile/features/sync/cloud_relay_service.dart';
import 'package:archiveme_mobile/features/transcript/ui/transcript_detail_view.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/sync/sync_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    PremiumAccess.apply(PremiumEntitlement.free);
    ContinuityGate.resetFreeWatchQuota();
  });

  test('free tier does not upload a cloud relay blob', () async {
    final relay = CloudRelayService(
      crypto: SyncCrypto(List<int>.filled(32, 3)),
      bucket: MemoryCloudRelayBucket(),
    );
    final envelope = await relay.relayIfSecondaryOffline(
      peerObserved: false,
      recordingId: 'rec-free',
      audioBytes: const [9],
      transcript: 'raw transcript',
    );
    expect(envelope, isNull);
    expect(await relay.bucket.list(), isEmpty);
  });

  test('free Watch sync allows one capture and premium removes the cap', () {
    expect(ContinuityGate.allowWatchSync(), isTrue);
    expect(ContinuityGate.allowWatchSync(), isFalse);
    PremiumAccess.apply(PremiumEntitlement.active);
    expect(ContinuityGate.allowWatchSync(), isTrue);
    expect(ContinuityGate.allowWatchSync(), isTrue);
  });

  testWidgets('free summary buttons keep the raw transcript', (tester) async {
    var calls = 0;
    final service = GemmaSummaryService(
      completer: ({required systemPrompt, required userPrompt}) async {
        calls += 1;
        return 'polished';
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GemmaSummaryPanel(
            entryId: 'entry-1',
            transcript: 'The rent is due tomorrow.',
            service: service,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('gemma_summary_smart')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gemma_summary_actions')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gemma_summary_diary')));
    await tester.pump();
    expect(calls, 0);
    expect(find.byKey(const Key('gemma_summary_locked')), findsOneWidget);
    expect(find.text('The rent is due tomorrow.'), findsNothing);
    expect(find.byKey(const Key('gemma_summary_text')), findsNothing);
  });

  testWidgets('paywall purchase unlocks continuity and advanced AI', (
    tester,
  ) async {
    final service = MonetizationRevenueCatService(
      purchaseOverride: () async => PremiumEntitlement.active,
      restoreOverride: () async => PremiumEntitlement.active,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: PaywallView()),
      ),
    );
    await tester.pump();
    expect(find.text('100% Offline & Privacy-First'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('paywall_benefit_web')),
      120,
    );
    expect(find.byKey(const Key('paywall_benefit_watch')), findsOneWidget);
    expect(find.byKey(const Key('paywall_benefit_relay')), findsOneWidget);
    expect(find.byKey(const Key('paywall_benefit_web')), findsOneWidget);
    expect(find.text('Start Premium'), findsOneWidget);
    await tester.tap(find.byKey(const Key('paywall_purchase')));
    await tester.pump();
    expect(find.text('Premium is active'), findsOneWidget);
    expect(find.byKey(const Key('paywall_web_handoff')), findsOneWidget);
    expect(PremiumAccess.current.canUseSmartSummary, isTrue);
    expect(PremiumAccess.current.canUseCloudRelay, isTrue);
    expect(PremiumAccess.current.canUseUnlimitedWatchSync, isTrue);
    expect(PremiumAccess.current.canHandoffToWeb, isTrue);
  });

  test('archive_loop_pro and pro both count as premium', () {
    expect(
      holdsContinuityEntitlement(
        const PremiumEntitlements(
          tier: BillingTier.free,
          entitlementIds: ['archive_loop_pro'],
          billingConnected: true,
          source: 'revenuecat',
        ),
      ),
      isTrue,
    );
    expect(
      holdsContinuityEntitlement(
        const PremiumEntitlements(
          tier: BillingTier.pro,
          entitlementIds: ['pro'],
          billingConnected: true,
          source: 'revenuecat',
        ),
      ),
      isTrue,
    );
    expect(
      holdsContinuityEntitlement(PremiumEntitlements.free()),
      isFalse,
    );
  });

  testWidgets('free transcript stays in place and opens the paywall', (
    tester,
  ) async {
    var calls = 0;
    final service = MonetizationRevenueCatService(
      purchaseOverride: () async => PremiumEntitlement.active,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TranscriptDetailView(
              entryId: 'entry-1',
              transcript: 'The rent is due tomorrow.',
              service: GemmaSummaryService(
                completer:
                    ({required systemPrompt, required userPrompt}) async {
                      calls += 1;
                      return 'polished';
                    },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('The rent is due tomorrow.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('gemma_summary_smart')));
    await tester.pump();
    expect(calls, 0);
    expect(find.text('The rent is due tomorrow.'), findsOneWidget);
    expect(find.byKey(const Key('gemma_summary_locked')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gemma_summary_paywall')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Start Premium'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('paywall_benefit_web')),
      120,
      scrollable: find.descendant(
        of: find.byType(ContinuityPaywallSection),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Encrypted cloud backups'), findsWidgets);
    expect(find.text('Automated Obsidian sync'), findsWidgets);
    expect(find.text('Pattern synthesis'), findsWidgets);
    expect(find.textContaining('no subscription'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    await tester.tap(find.byKey(const Key('paywall_purchase')));
    await tester.pump();
    expect(find.text('Premium is active'), findsOneWidget);
    expect(find.byKey(const Key('paywall_web_handoff')), findsOneWidget);
  });

  testWidgets('an active entitlement runs the local rewrite', (tester) async {
    var calls = 0;
    final billing = MonetizationRevenueCatService(
      seed: PremiumEntitlement.active,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(billing),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TranscriptDetailView(
              entryId: 'entry-1',
              transcript: 'The rent is due tomorrow.',
              service: GemmaSummaryService(
                completer:
                    ({required systemPrompt, required userPrompt}) async {
                      calls += 1;
                      return 'Rent is due tomorrow.';
                    },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('gemma_summary_actions')));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('The rent is due tomorrow.'), findsOneWidget);
    expect(find.text('Rent is due tomorrow.'), findsOneWidget);
    expect(find.byKey(const Key('gemma_summary_locked')), findsNothing);
  });
}
