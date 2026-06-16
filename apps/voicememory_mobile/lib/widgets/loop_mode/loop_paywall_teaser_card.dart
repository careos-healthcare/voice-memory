import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../billing/revenuecat_service.dart';
import '../../design/archive_mobile_typography.dart';
import '../../features/acquisition/acquisition_cohort_coordinator.dart';
import '../../features/activation/activation_tracker.dart';
import '../../features/loop_mode/loop_mode_model.dart';
import '../../models/entitlement.dart';
import '../../product/loop_mode_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Soft Pro teaser after a confirmed capacity loop review — not a hard wall.
class LoopPaywallTeaserCard extends StatefulWidget {
  const LoopPaywallTeaserCard({
    super.key,
    required this.shouldShow,
    required this.entitlements,
    this.loopModeId,
    this.onDismissed,
  });

  final bool shouldShow;
  final PremiumEntitlements? entitlements;
  final String? loopModeId;
  final VoidCallback? onDismissed;

  @override
  State<LoopPaywallTeaserCard> createState() => _LoopPaywallTeaserCardState();
}

class _LoopPaywallTeaserCardState extends State<LoopPaywallTeaserCard> {
  bool _shownTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackShownIfVisible());
  }

  @override
  void didUpdateWidget(covariant LoopPaywallTeaserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackShownIfVisible());
  }

  void _trackShownIfVisible() {
    if (_shownTracked) return;
    if (!widget.shouldShow || widget.entitlements?.isPro == true) return;
    _shownTracked = true;
    ActivationTracker.trackLoopPaywallTeaserShown();
    AcquisitionCohortCoordinator.markPaywallTeaserShown();
  }

  void _openPro() {
    ActivationTracker.trackLoopPaywallTeaserTapped();
    AcquisitionCohortCoordinator.markPaywallTeaserTapped();
    if (widget.loopModeId == LoopModeIds.proveEnough) {
      ActivationTracker.trackProvePaywallTeaserTapped();
    }
    if (RevenueCatService.instance.isConfigured) {
      context.push('/subscription');
    }
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldShow) return const SizedBox.shrink();
    if (widget.entitlements?.isPro == true) return const SizedBox.shrink();

    final billingReady = RevenueCatService.instance.isConfigured;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.accentLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LoopModeCopy.paywallHeadlineForLoop(widget.loopModeId),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            LoopModeCopy.paywallBodyForLoop(widget.loopModeId),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final bullet in LoopModeCopy.paywallBulletsForLoop(
            widget.loopModeId,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '• $bullet',
                style: ArchiveMobileTypography.explanationBody(context),
              ),
            ),
          if (!billingReady) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              LoopModeCopy.paywallPurchasesUnavailable,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: billingReady ? _openPro : null,
            child: Text(LoopModeCopy.paywallAfterLoopSeePro),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: widget.onDismissed,
            child: Text(LoopModeCopy.paywallAfterLoopNotNow),
          ),
        ],
      ),
    );
  }
}
