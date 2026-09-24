import 'package:archiveme_mobile/billing/archive_paywall_stats.dart';
import 'package:archiveme_mobile/billing/v1/paywall_plan.dart';
import 'package:archiveme_mobile/widgets/paywall/archive_intelligence_pro_paywall.dart';
import 'package:archiveme_mobile/widgets/paywall/paywall_sticky_checkout_bar.dart';
import 'package:archiveme_mobile/widgets/paywall/staggered_pro_feature_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders hero, staggered features, and sticky checkout bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveIntelligenceProPaywall(
            headline: 'Keep the longer trail',
            subheadline: 'Pro keeps evidence connected over time.',
            positioningLine: 'Keep your verified timeline growing.',
            selectedPlan: PaywallPlan.yearly,
            monthlyPrice: r'$9.99 / month',
            yearlyPrice: r'$79.99 / year',
            hasMonthly: true,
            hasYearly: true,
            onPlanSelected: (_) {},
            onPurchase: () {},
            onDismiss: () {},
            onRestore: () {},
            purchaseInFlight: false,
            isBusy: false,
            ctaLabel: 'Continue with Pro',
            surface: 'subscription',
            preloadedStats: const ArchivePaywallStats(
              recordingCount: 12,
              spanDays: 14,
              recurringThemeCount: 2,
              activeTheoryCount: 1,
              changeCount: 3,
              contradictionCount: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Keep the longer trail'), findsOneWidget);
    expect(find.byType(StaggeredProFeatureList), findsOneWidget);
    expect(find.byType(PaywallStickyCheckoutBar), findsOneWidget);
    expect(find.text('Continue with Pro'), findsOneWidget);
    expect(find.textContaining('2 recurring themes'), findsOneWidget);
  });
}