import 'package:flutter/material.dart';

import '../../billing/paywall_source.dart';
import '../../design/archive_mobile_typography.dart';
import '../../services/activation_funnel_analytics.dart';

/// Small plan-choice helper rendered directly below the plan cards and
/// before the purchase CTA. The helper line follows the currently selected
/// plan; the manage/cancel reassurance is always visible. Passive — no
/// buttons, and never any pressure toward yearly.
class PlanSelectionConfidenceBlock extends StatelessWidget {
  const PlanSelectionConfidenceBlock({
    super.key,
    required this.selectedPlanId,
    this.source,
  });

  /// Stable plan id: `monthly` or `yearly`. Never user text.
  final String selectedPlanId;

  /// Paywall source id for attribution. Never user text.
  final String? source;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.planSelectionConfidenceSeen,
      source: source,
      oncePerSession: true,
    );
    return Column(
      key: const Key('paywall_plan_selection_confidence'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          PaywallPlanSelectionConfidence.title,
          textAlign: TextAlign.center,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: 4),
        Text(
          PaywallPlanSelectionConfidence.helperForPlanId(selectedPlanId),
          key: const Key('paywall_plan_selection_helper'),
          textAlign: TextAlign.center,
          style: ArchiveMobileTypography.responsiveHelper(context),
        ),
        const SizedBox(height: 4),
        Text(
          PaywallPlanSelectionConfidence.manageLine,
          textAlign: TextAlign.center,
          style: ArchiveMobileTypography.responsiveHelper(context),
        ),
      ],
    );
  }
}
