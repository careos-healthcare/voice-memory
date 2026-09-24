import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_analytics.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_copy.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/cues/emotional_cues.dart';
import 'package:flutter/material.dart';

/// Explains how ArchiveMe weights recent vs older evidence — no monetisation CTA.
class EvidenceWeightingCard extends StatefulWidget {
  const EvidenceWeightingCard({
    required this.result,
    required this.source,
    super.key,
  });

  const EvidenceWeightingCard.test({
    required this.result,
    required this.source,
    super.key,
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

    final ink = Theme.of(context).colorScheme.onSurface;
    final bodyStyle = TextStyle(
      fontSize: 16,
      height: 1.45,
      color: ink.withValues(alpha: 0.62),
    );

    return Padding(
      key: const Key('evidence_weighting_card'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            EvidenceWeightingCopy.title,
            key: const Key('evidence_weighting_title'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: ink.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            EvidenceWeightingCopy.body,
            key: const Key('evidence_weighting_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final state in widget.result.displayStates)
            EmotionalWeightCue(
              labelKey: Key('evidence_weighting_state_${state.name}'),
              lineKey: Key('evidence_weighting_explanation_${state.name}'),
              label: EvidenceWeightingCopy.labelFor(state),
              state: state,
              line: CorrectionMemoryEngine.evidenceExplanationFor(
                correction: widget.result.correctionMemory,
                fallback: EvidenceWeightingCopy.explanationFor(state),
                isRepeatedState: state == EvidenceWeightState.repeated,
              ),
            ),
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
