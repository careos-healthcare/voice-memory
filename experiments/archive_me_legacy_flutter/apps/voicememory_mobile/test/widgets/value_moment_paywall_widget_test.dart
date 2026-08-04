import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_paywall_stats.dart';
import 'package:voicememory_mobile/features/monetization/domain/services/monetization_analytics.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';
import 'package:voicememory_mobile/widgets/value_moment_paywall.dart';

class _RecordingAnalytics implements AnalyticsEngine {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  void logEvent(String name, {Map<String, Object>? parameters}) {
    events.add((name: name, parameters: parameters ?? const {}));
  }
}

const _proEntitlement = SubscriptionState(
  tier: SubscriptionTier.pro,
  entitlementIds: [SubscriptionEntitlements.pro],
  billingConnected: true,
  origin: SubscriptionStateOrigin.store,
  productIdentifier: 'archive_loop_pro',
);

void main() {
  testWidgets('free entitlement opens server checkout session', (tester) async {
    Uri? launchedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueMomentPaywall(
            reason: ValueMomentPaywallReason.premiumInsights,
            entitlementLoader: () async => SubscriptionState.free(),
            checkoutCreator: () async => const SubscriptionCheckout(
              url: 'https://checkout.example.com/session',
              sessionId: 'session-1',
            ),
            checkoutLauncher: (uri) async {
              launchedUri = uri;
              return true;
            },
            useWebCheckout: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('value_moment_paywall_premiumInsights')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('value_moment_paywall_checkout')));
    await tester.pump();

    expect(launchedUri, Uri.parse('https://checkout.example.com/session'));
  });

  testWidgets('active Pro entitlement removes the boundary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ValueMomentPaywall(
          reason: ValueMomentPaywallReason.fullHistory,
          entitlementLoader: () async => const SubscriptionState(
            tier: SubscriptionTier.pro,
            entitlementIds: [SubscriptionEntitlements.pro],
            billingConnected: true,
            origin: SubscriptionStateOrigin.store,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('value_moment_paywall_fullHistory')),
      findsNothing,
    );
  });

  testWidgets('renders personalized local archive proof while offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ValueMomentPaywall(
          reason: ValueMomentPaywallReason.premiumInsights,
          entitlementLoader: () async => SubscriptionState.free(),
          personalizationLoader: () async => const ArchivePaywallStats(
            recordingCount: 12,
            spanDays: 45,
            recurringThemeCount: 3,
            activeTheoryCount: 0,
            changeCount: 0,
            contradictionCount: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('value_moment_paywall_personalized_proof')),
      findsOneWidget,
    );
    expect(find.textContaining('12 saved moments across'), findsOneWidget);
    expect(find.textContaining('3 recurring themes'), findsOneWidget);
  });

  testWidgets('successful sandbox purchase unlocks and dismisses paywall', (
    tester,
  ) async {
    var unlocked = false;
    final analytics = _RecordingAnalytics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueMomentPaywall(
            reason: ValueMomentPaywallReason.premiumInsights,
            knownIsPro: false,
            purchaseHandler: () async => _proEntitlement,
            onUnlocked: () => unlocked = true,
            analytics: analytics,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('value_moment_paywall_checkout')));
    await tester.pump();

    expect(unlocked, isTrue);
    expect(
      find.byKey(const Key('value_moment_paywall_premiumInsights')),
      findsNothing,
    );
    expect(
      analytics.events.map((event) => event.name),
      containsAllInOrder(['paywall_seen', 'purchase_completed']),
    );
    final conversion = analytics.events.last.parameters;
    expect(conversion['source'], 'insight_tease');
  });

  testWidgets('purchase cancellation is silent and clears busy state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueMomentPaywall(
            reason: ValueMomentPaywallReason.premiumInsights,
            knownIsPro: false,
            purchaseHandler: () async => throw SubscriptionPurchaseException(
              SubscriptionPurchaseFailureKind.cancelled,
              cause: StateError('cancelled'),
            ),
          ),
        ),
      ),
    );

    final checkout = find.byKey(const Key('value_moment_paywall_checkout'));
    await tester.tap(checkout);
    await tester.pump();

    expect(find.textContaining('could not'), findsNothing);
    expect(tester.widget<FilledButton>(checkout).onPressed, isNotNull);
  });

  testWidgets('temporary purchase error shows calm connection guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueMomentPaywall(
            reason: ValueMomentPaywallReason.premiumInsights,
            knownIsPro: false,
            purchaseHandler: () async => throw SubscriptionPurchaseException(
              SubscriptionPurchaseFailureKind.temporary,
              cause: StateError('offline'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('value_moment_paywall_checkout')));
    await tester.pump();

    expect(find.textContaining('could not be completed'), findsOneWidget);
  });

  testWidgets('successful restore unlocks and dismisses paywall', (
    tester,
  ) async {
    var unlocked = false;
    final analytics = _RecordingAnalytics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueMomentPaywall(
            reason: ValueMomentPaywallReason.fullHistory,
            knownIsPro: false,
            restoreHandler: () async => _proEntitlement,
            onUnlocked: () => unlocked = true,
            analytics: analytics,
          ),
        ),
      ),
    );

    expect(find.text('Restore Purchases'), findsOneWidget);
    await tester.tap(find.byKey(const Key('value_moment_paywall_restore')));
    await tester.pump();

    expect(unlocked, isTrue);
    expect(
      find.byKey(const Key('value_moment_paywall_fullHistory')),
      findsNothing,
    );
    final conversion = analytics.events.last;
    expect(conversion.name, 'purchase_completed');
    expect(conversion.parameters['source'], 'pro_bridge');
  });

  testWidgets('close button tracks dismissal with trigger source', (
    tester,
  ) async {
    final analytics = _RecordingAnalytics();
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueMomentPaywall(
          reason: ValueMomentPaywallReason.premiumInsights,
          knownIsPro: false,
          analytics: analytics,
          onDismissed: () => dismissed = true,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));

    expect(dismissed, isTrue);
    final dismissal = analytics.events.last;
    expect(dismissal.name, 'paywall_dismissed');
    expect(dismissal.parameters['source'], 'insight_tease');
  });

  testWidgets('unmount without purchase tracks swipe-away dismissal', (
    tester,
  ) async {
    final analytics = _RecordingAnalytics();
    await tester.pumpWidget(
      MaterialApp(
        home: ValueMomentPaywall(
          reason: ValueMomentPaywallReason.premiumInsights,
          knownIsPro: false,
          analytics: analytics,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    expect(
      analytics.events.map((event) => event.name),
      containsAllInOrder(['paywall_seen', 'paywall_dismissed']),
    );
  });
}
