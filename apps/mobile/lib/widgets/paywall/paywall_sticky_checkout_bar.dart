import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/archive_paywall_plans.dart';
import 'package:archiveme_mobile/billing/v1/paywall_plan.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Sticky bottom checkout — plan toggle, RevenueCat purchase CTA, restore/dismiss.
class PaywallStickyCheckoutBar extends StatelessWidget {
  const PaywallStickyCheckoutBar({
    required this.selectedPlan,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.onPlanSelected,
    required this.onPurchase,
    required this.onDismiss,
    required this.onRestore,
    required this.purchaseInFlight,
    required this.isBusy,
    required this.ctaLabel,
    super.key,
    this.hasMonthly = true,
    this.hasYearly = true,
    this.confirmLine,
  });

  final PaywallPlan selectedPlan;
  final String? monthlyPrice;
  final String? yearlyPrice;
  final ValueChanged<PaywallPlan> onPlanSelected;
  final VoidCallback onPurchase;
  final VoidCallback onDismiss;
  final VoidCallback onRestore;
  final bool purchaseInFlight;
  final bool isBusy;
  final String ctaLabel;
  final bool hasMonthly;
  final bool hasYearly;
  final String? confirmLine;

  @override
  Widget build(BuildContext context) {
    final selectedPrice = selectedPlan == PaywallPlan.yearly
        ? yearlyPrice
        : monthlyPrice;

    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: VoiceMemoryColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasMonthly || hasYearly)
                Row(
                  children: [
                    if (hasYearly)
                      Expanded(
                        child: _PlanChip(
                          label: ArchivePaywallPlanCopy.annualLabel,
                          price: yearlyPrice,
                          selected: selectedPlan == PaywallPlan.yearly,
                          onTap: isBusy
                              ? null
                              : () => onPlanSelected(PaywallPlan.yearly),
                        ),
                      ),
                    if (hasMonthly && hasYearly) const SizedBox(width: 10),
                    if (hasMonthly)
                      Expanded(
                        child: _PlanChip(
                          label: ArchivePaywallPlanCopy.monthlyLabel,
                          price: monthlyPrice,
                          selected: selectedPlan == PaywallPlan.monthly,
                          onTap: isBusy
                              ? null
                              : () => onPlanSelected(PaywallPlan.monthly),
                        ),
                      ),
                  ],
                ),
              if (selectedPrice != null) ...[
                const SizedBox(height: 8),
                Text(
                  selectedPrice,
                  key: const Key('paywall_sticky_selected_price'),
                  textAlign: TextAlign.center,
                  style: ArchiveMobileTypography.explanationBody(context)
                      .copyWith(
                        color: VoiceMemoryColors.primaryIndigo,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              if (confirmLine != null) ...[
                const SizedBox(height: 6),
                Text(
                  confirmLine!,
                  key: const Key('paywall_app_store_confirm_line'),
                  textAlign: TextAlign.center,
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton(
                onPressed: isBusy ? null : onPurchase,
                style: FilledButton.styleFrom(
                  backgroundColor: VoiceMemoryColors.primaryIndigo,
                  foregroundColor: VoiceMemoryColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  purchaseInFlight
                      ? ArchivePaywallCopy.purchaseStarting
                      : ctaLabel,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 0,
                children: [
                  TextButton(
                    onPressed: isBusy ? null : onDismiss,
                    child: const Text(ConsumerUiCopy.paywallSecondaryCta),
                  ),
                  TextButton(
                    onPressed: isBusy ? null : onRestore,
                    child: Text(ConsumerUiCopy.restorePurchases),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? price;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      hint: selected ? null : 'Selects this plan',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.08)
                  : VoiceMemoryColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? VoiceMemoryColors.primaryIndigo
                    : VoiceMemoryColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: ArchiveMobileTypography.listTitle(context).copyWith(
                    fontSize: 13,
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    price!,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}