import 'dart:async';

import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/archive_paywall_stats.dart';
import 'package:archiveme_mobile/billing/v1/paywall_plan.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_builder.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/archive_paywall/archive_intelligence_proof_section.dart';
import 'package:archiveme_mobile/widgets/billing/paywall_subscription_details_section.dart';
import 'package:archiveme_mobile/widgets/paywall/archive_intelligence_paywall_hero.dart';
import 'package:archiveme_mobile/widgets/paywall/paywall_sticky_checkout_bar.dart';
import 'package:archiveme_mobile/widgets/paywall/pro_paywall_feature.dart';
import 'package:archiveme_mobile/widgets/paywall/staggered_pro_feature_list.dart';
import 'package:flutter/material.dart';

/// Default Pro feature rows — aligned with paywall copy, not fabricated claims.
List<ProPaywallFeatureItem> buildDefaultProPaywallFeatures() {
  final bullets = PaywallValueSharpeningCopy.benefitBullets;
  return [
    ProPaywallFeatureItem(
      icon: Icons.timeline_outlined,
      title: bullets[0],
      subtitle: 'Your verified timeline stays on this device as you add moments.',
    ),
    ProPaywallFeatureItem(
      icon: Icons.inventory_2_outlined,
      title: bullets[1],
      subtitle: 'Archive more reflections without losing earlier proof.',
    ),
    ProPaywallFeatureItem(
      icon: Icons.autorenew,
      title: bullets[2],
      subtitle: 'See when patterns return, shift, or fade across weeks.',
    ),
    const ProPaywallFeatureItem(
      icon: Icons.auto_stories_outlined,
      title: 'Monthly review & historian synthesis',
      subtitle: 'Locked intelligence cards unlock with Pro.',
    ),
    const ProPaywallFeatureItem(
      icon: Icons.flag_outlined,
      title: 'Milestone insights',
      subtitle: 'Celebrate evidence thresholds as your archive grows.',
    ),
  ];
}

/// Polished intelligence paywall — hero, proof section, staggered features,
/// sticky RevenueCat checkout bar.
class ArchiveIntelligenceProPaywall extends StatefulWidget {
  const ArchiveIntelligenceProPaywall({
    required this.headline,
    required this.subheadline,
    required this.positioningLine,
    required this.selectedPlan,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.hasMonthly,
    required this.hasYearly,
    required this.onPlanSelected,
    required this.onPurchase,
    required this.onDismiss,
    required this.onRestore,
    required this.purchaseInFlight,
    required this.isBusy,
    required this.ctaLabel,
    required this.surface,
    super.key,
    this.features,
    this.confirmLine,
    this.errorMessage,
    this.extraScrollContent,
    this.preloadedStats,
  });

  final String headline;
  final String subheadline;
  final String positioningLine;
  final List<ProPaywallFeatureItem>? features;
  final PaywallPlan selectedPlan;
  final String? monthlyPrice;
  final String? yearlyPrice;
  final bool hasMonthly;
  final bool hasYearly;
  final ValueChanged<PaywallPlan> onPlanSelected;
  final VoidCallback onPurchase;
  final VoidCallback onDismiss;
  final VoidCallback onRestore;
  final bool purchaseInFlight;
  final bool isBusy;
  final String ctaLabel;
  final String surface;
  final String? confirmLine;
  final String? errorMessage;
  final Widget? extraScrollContent;
  final ArchivePaywallStats? preloadedStats;

  @override
  State<ArchiveIntelligenceProPaywall> createState() =>
      _ArchiveIntelligenceProPaywallState();
}

class _ArchiveIntelligenceProPaywallState
    extends State<ArchiveIntelligenceProPaywall> {
  ArchivePaywallStats? _stats;

  @override
  void initState() {
    super.initState();
    _stats = widget.preloadedStats;
    if (_stats == null) {
      unawaited(_loadStats());
    }
  }

  Future<void> _loadStats() async {
    if (!AppServices.isInitialized) return;
    final s = AppServices.instance;
    final entries = await s.journal.loadAll();
    ArchiveV1View? v1;
    if (archiveHasMinimumEvidence(entries)) {
      v1 = await const ArchiveV1Builder().build(
        entries: entries,
        evolutionService: s.beliefEvolution,
      );
    }
    if (!mounted) return;
    setState(() {
      _stats = ArchivePaywallStats.fromEntries(entries: entries, archiveV1: v1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final features = widget.features ?? buildDefaultProPaywallFeatures();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: ArchiveResponsiveLayout.pagePadding(context),
                    sliver: SliverToBoxAdapter(
                      child: ArchiveResponsiveLayout.constrainContent(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ArchiveIntelligencePaywallHero(
                              headline: widget.headline,
                              subheadline: widget.subheadline,
                              positioningLine: widget.positioningLine,
                              stats: _stats,
                            ),
                            SizedBox(
                              height: ArchiveResponsiveLayout.gap(context) + 8,
                            ),
                            if (_stats != null)
                              ArchiveIntelligenceProofSection(
                                stats: _stats!,
                                surface: widget.surface,
                              ),
                            if (_stats != null)
                              SizedBox(
                                height: ArchiveResponsiveLayout.gap(context) +
                                    10,
                              ),
                            StaggeredProFeatureList(
                              sectionTitle: ArchivePaywallCopy.lockedSectionTitle,
                              features: features,
                            ),
                            if (widget.extraScrollContent != null) ...[
                              const SizedBox(height: 16),
                              widget.extraScrollContent!,
                            ],
                            PaywallSubscriptionDetailsSection(
                              monthlyPrice: widget.monthlyPrice,
                              yearlyPrice: widget.yearlyPrice,
                              plansAvailable: widget.hasMonthly ||
                                  widget.hasYearly,
                            ),
                            if (widget.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  widget.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: 120 + bottomInset),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PaywallStickyCheckoutBar(
              selectedPlan: widget.selectedPlan,
              monthlyPrice: widget.monthlyPrice,
              yearlyPrice: widget.yearlyPrice,
              hasMonthly: widget.hasMonthly,
              hasYearly: widget.hasYearly,
              onPlanSelected: widget.onPlanSelected,
              onPurchase: widget.onPurchase,
              onDismiss: widget.onDismiss,
              onRestore: widget.onRestore,
              purchaseInFlight: widget.purchaseInFlight,
              isBusy: widget.isBusy,
              ctaLabel: widget.ctaLabel,
              confirmLine: widget.confirmLine,
            ),
          ],
        );
      },
    );
  }
}