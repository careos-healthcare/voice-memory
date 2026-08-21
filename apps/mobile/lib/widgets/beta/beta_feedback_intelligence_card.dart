import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_analytics.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_copy.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_model.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_store.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/beta/beta_feedback_intelligence_sheet.dart';
import 'package:flutter/material.dart';

/// Beta-only feedback card — opens structured beta feedback sheet.
class BetaFeedbackIntelligenceCard extends StatefulWidget {
  const BetaFeedbackIntelligenceCard({
    required this.surface, required this.entryCount, required this.reachedFirstProof, super.key,
    this.compact = false,
    this.onSubmitted,
  });

  final BetaFeedbackIntelligenceSurface surface;
  final int entryCount;
  final bool reachedFirstProof;
  final bool compact;
  final VoidCallback? onSubmitted;

  @override
  State<BetaFeedbackIntelligenceCard> createState() =>
      _BetaFeedbackIntelligenceCardState();
}

class _BetaFeedbackIntelligenceCardState
    extends State<BetaFeedbackIntelligenceCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    final state = BetaFeedbackIntelligenceStore.cached;
    BetaFeedbackIntelligenceAnalytics.seen(
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
      reachedFirstProof: widget.reachedFirstProof,
      sawProBridge: state.hasSeenProEvidenceBridge,
    );
  }

  Future<void> _openSheet() async {
    final state = BetaFeedbackIntelligenceStore.cached;
    BetaFeedbackIntelligenceAnalytics.opened(
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
      reachedFirstProof: widget.reachedFirstProof,
      sawProBridge: state.hasSeenProEvidenceBridge,
    );
    await BetaFeedbackIntelligenceSheet.show(
      context,
      source: widget.surface.analyticsValue,
      entryCount: widget.entryCount,
      reachedFirstProof: widget.reachedFirstProof,
      onSubmitted: widget.onSubmitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: Key(
        widget.compact
            ? 'beta_feedback_intelligence_card_compact'
            : 'beta_feedback_intelligence_card',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            BetaFeedbackIntelligenceCopy.cardTitle,
            key: const Key('beta_feedback_intelligence_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            BetaFeedbackIntelligenceCopy.cardBody,
            key: const Key('beta_feedback_intelligence_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('beta_feedback_intelligence_cta'),
            onPressed: _openSheet,
            child: const Text(BetaFeedbackIntelligenceCopy.cardCta),
          ),
        ],
      ),
    );
  }
}