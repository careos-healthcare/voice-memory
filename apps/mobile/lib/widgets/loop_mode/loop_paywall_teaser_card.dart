import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/product/loop_mode_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Soft Pro teaser after a confirmed capacity loop review — not a hard wall.
class LoopPaywallTeaserCard extends StatefulWidget {
  const LoopPaywallTeaserCard({
    required this.shouldShow, required this.entitlements, super.key,
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
    unawaited(AcquisitionCohortCoordinator.markPaywallTeaserShown());
  }

  void _openPro() {
    ActivationTracker.trackLoopPaywallTeaserTapped();
    unawaited(AcquisitionCohortCoordinator.markPaywallTeaserTapped());
    if (widget.loopModeId == LoopModeIds.proveEnough) {
      ActivationTracker.trackProvePaywallTeaserTapped();
    }
    if (RevenueCatService.instance.isConfigured) {
      unawaited(context.push('/subscription'));
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
            child: const Text(LoopModeCopy.paywallAfterLoopSeePro),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: widget.onDismissed,
            child: const Text(LoopModeCopy.paywallAfterLoopNotNow),
          ),
        ],
      ),
    );
  }
}