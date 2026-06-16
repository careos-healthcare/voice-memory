import 'package:flutter/material.dart';

import '../../billing/purchase_intent_return_cue.dart';
import '../../design/archive_mobile_typography.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Calm, dismissible return cue for a purchase start that never completed.
/// Routes to the existing paywall; never blocks recording or free use, and
/// never implies the user failed to buy.
class PurchaseIntentReturnCueCard extends StatelessWidget {
  const PurchaseIntentReturnCueCard({
    super.key,
    required this.intent,
    required this.onSeePro,
    required this.onDismiss,
  });

  final PendingPurchaseIntent intent;
  final VoidCallback onSeePro;
  final VoidCallback onDismiss;

  void _track(String event) {
    ActivationFunnelAnalytics.track(
      event,
      source: intent.source,
      plan: intent.plan,
      oncePerSession:
          event == ActivationFunnelAnalytics.purchaseIntentReturnCueSeen,
    );
  }

  @override
  Widget build(BuildContext context) {
    _track(ActivationFunnelAnalytics.purchaseIntentReturnCueSeen);

    return Container(
      key: const Key('purchase_intent_return_cue'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F5FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PurchaseIntentReturnCue.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PurchaseIntentReturnCue.body,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TextButton(
                  key: const Key('purchase_intent_return_cue_dismiss'),
                  onPressed: () {
                    _track(
                      ActivationFunnelAnalytics
                          .purchaseIntentReturnCueDismissed,
                    );
                    onDismiss();
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  child: const Text(
                    PurchaseIntentReturnCue.dismissLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: FilledButton(
                  key: const Key('purchase_intent_return_cue_cta'),
                  onPressed: () {
                    _track(
                      ActivationFunnelAnalytics.purchaseIntentReturnCueTapped,
                    );
                    onSeePro();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  child: const Text(
                    PurchaseIntentReturnCue.ctaLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
