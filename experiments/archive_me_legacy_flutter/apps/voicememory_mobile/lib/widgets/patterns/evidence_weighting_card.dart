import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/correction_memory/correction_memory_engine.dart';
import '../../features/evidence_weighting/evidence_weighting_analytics.dart';
import '../../features/evidence_weighting/evidence_weighting_copy.dart';
import '../../features/evidence_weighting/evidence_weighting_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Explains how ArchiveMe weights recent vs older evidence — no monetisation CTA.
class EvidenceWeightingCard extends StatefulWidget {
  const EvidenceWeightingCard({
    super.key,
    required this.result,
    required this.source,
  });

  const EvidenceWeightingCard.test({
    super.key,
    required this.result,
    required this.source,
  });

  final EvidenceWeightingResult result;
  final String source;

  @override
  State<EvidenceWeightingCard> createState() => _EvidenceWeightingCardState();
}

class _EvidenceWeightingCardState extends State<EvidenceWeightingCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    EvidenceWeightingAnalytics.seen(
      source: widget.source,
      result: widget.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('evidence_weighting_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            EvidenceWeightingCopy.title,
            key: const Key('evidence_weighting_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            EvidenceWeightingCopy.body,
            key: const Key('evidence_weighting_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final state in widget.result.displayStates) ...[
            Text(
              EvidenceWeightingCopy.labelFor(state),
              key: Key('evidence_weighting_state_${state.name}'),
              style: labelStyle,
            ),
            const SizedBox(height: 2),
            Text(
              CorrectionMemoryEngine.evidenceExplanationFor(
                correction: widget.result.correctionMemory,
                fallback: EvidenceWeightingCopy.explanationFor(state),
                isRepeatedState: state == EvidenceWeightState.repeated,
              ),
              key: Key('evidence_weighting_explanation_${state.name}'),
              style: bodyStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            EvidenceWeightingCopy.footer,
            key: const Key('evidence_weighting_footer'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            EvidenceWeightingCopy.differentiationLine,
            key: const Key('evidence_weighting_differentiation_line'),
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
