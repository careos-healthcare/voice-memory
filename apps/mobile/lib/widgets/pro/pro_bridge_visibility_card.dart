import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_timing_loosen_analytics.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_analytics.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Post-proof Pro bridge — routes to the existing paywall only.
class ProBridgeVisibilityCard extends StatefulWidget {
  const ProBridgeVisibilityCard({
    required this.result, required this.onSeePro, required this.onDismiss, super.key,
  });

  final ProBridgeVisibilityResult result;
  final VoidCallback onSeePro;
  final VoidCallback onDismiss;

  @override
  State<ProBridgeVisibilityCard> createState() =>
      _ProBridgeVisibilityCardState();
}

class _ProBridgeVisibilityCardState extends State<ProBridgeVisibilityCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ProBridgeVisibilityAnalytics.seen(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      triggerReason: widget.result.triggerReason,
      hasTimelineProof: widget.result.hasTimelineProof,
      feedbackState: widget.result.feedbackState.analyticsValue,
    );
    if (widget.result.triggerReason != null) {
      ProBridgeTimingLoosenAnalytics.seen(
        source: widget.result.source,
        surface: widget.result.surface.analyticsValue,
        entryCount: widget.result.entryCount,
        triggerReason: widget.result.triggerReason!,
        confidenceLevel: widget.result.confidenceLevel?.analyticsValue,
        hasSafeAnchor: widget.result.hasSafeAnchor,
      );
    }
  }

  void _handleSeePro() {
    ProBridgeVisibilityAnalytics.ctaTapped(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      triggerReason: widget.result.triggerReason,
      hasTimelineProof: widget.result.hasTimelineProof,
      feedbackState: widget.result.feedbackState.analyticsValue,
    );
    if (widget.result.triggerReason != null) {
      ProBridgeTimingLoosenAnalytics.ctaTapped(
        source: widget.result.source,
        surface: widget.result.surface.analyticsValue,
        entryCount: widget.result.entryCount,
        triggerReason: widget.result.triggerReason!,
        confidenceLevel: widget.result.confidenceLevel?.analyticsValue,
        hasSafeAnchor: widget.result.hasSafeAnchor,
      );
    }
    widget.onSeePro();
  }

  void _handleDismiss() {
    ProBridgeVisibilityAnalytics.dismissed(
      source: widget.result.source,
      surface: widget.result.surface.analyticsValue,
      entryCount: widget.result.entryCount,
      triggerReason: widget.result.triggerReason,
      hasTimelineProof: widget.result.hasTimelineProof,
      feedbackState: widget.result.feedbackState.analyticsValue,
    );
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('pro_bridge_visibility_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('pro_bridge_visibility_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.body,
            key: const Key('pro_bridge_visibility_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pro_bridge_visibility_dismiss'),
                  onPressed: _handleDismiss,
                  child: Text(widget.result.secondary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('pro_bridge_visibility_cta'),
                  onPressed: _handleSeePro,
                  child: Text(widget.result.cta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}