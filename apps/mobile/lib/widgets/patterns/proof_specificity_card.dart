import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/proof_specificity/proof_specificity_analytics.dart';
import 'package:archiveme_mobile/features/proof_specificity/proof_specificity_copy.dart';
import 'package:archiveme_mobile/features/proof_specificity/proof_specificity_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Explains why ArchiveMe noticed a repeat — safe labels only, no Pro CTA.
class ProofSpecificityCard extends StatefulWidget {
  const ProofSpecificityCard({required this.result, super.key});

  const ProofSpecificityCard.test({required this.result, super.key});

  final ProofSpecificityResult result;

  @override
  State<ProofSpecificityCard> createState() => _ProofSpecificityCardState();
}

class _ProofSpecificityCardState extends State<ProofSpecificityCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    ProofSpecificityAnalytics.seen(
      source: widget.result.source,
      result: widget.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('proof_specificity_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('proof_specificity_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('proof_specificity_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ProofSpecificityCopy.evidenceHeading,
            key: const Key('proof_specificity_evidence_heading'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (widget.result.usesFallbackEvidenceLine)
            Text(
              ProofSpecificityCopy.fallbackEvidenceLine,
              key: const Key('proof_specificity_fallback_evidence'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            )
          else
            for (final anchor in widget.result.evidenceAnchors)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  anchor,
                  key: Key('proof_specificity_anchor_${anchor.hashCode}'),
                  style: bodyStyle.copyWith(color: AppColors.textPrimary),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.boundaryLine,
            key: const Key('proof_specificity_boundary_line'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.correctionLine,
            key: const Key('proof_specificity_correction_line'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.differentiationLine,
            key: const Key('proof_specificity_differentiation_line'),
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}