import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/archive_insight_feedback.dart';
import '../../features/activation/archive_insight_feedback_adaptation.dart';
import '../../features/activation/belief_evidence_trail.dart';
import '../../features/activation/belief_history_timeline.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'archive_insight_feedback_controls.dart';

/// Proof trail sections for a belief update — not a generic journal list.
class BeliefEvidenceTrailCard extends StatelessWidget {
  const BeliefEvidenceTrailCard({
    super.key,
    required this.trail,
    this.onAddAnother,
  });

  final BeliefEvidenceTrail trail;
  final VoidCallback? onAddAnother;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    final footnoteStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    if (!trail.hasEnoughEvidence) {
      return Container(
        key: const Key('belief_evidence_trail_insufficient'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: AppColors.backgroundSecondary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(trail.title, style: titleStyle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              trail.insufficientBody ??
                  BeliefEvidenceTrailCopy.insufficientBody,
              key: const Key('belief_evidence_trail_insufficient_body'),
              style: bodyStyle,
            ),
          ],
        ),
      );
    }

    return ArchiveInsightFeedbackHost(
      insightId: ArchiveInsightFeedbackStore.targetId(
        ArchiveInsightTarget.beliefEvidence,
      ),
      showControls: ArchiveInsightFeedbackGate.showForBeliefEvidence(
        hasEnoughEvidence: trail.hasEnoughEvidence,
      ),
      childBuilder: (context) {
        const target = ArchiveInsightTarget.beliefEvidence;
        final adaptedChangeLine = trail.whatChangedLine == null
            ? null
            : ArchiveInsightFeedbackAdaptation.adaptedCopyFor(
                trail.whatChangedLine!,
                target,
              );

        return Container(
          key: const Key('belief_evidence_trail_card'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: VoiceMemoryCards.standard(
            background: AppColors.backgroundSecondary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (trail.notConclusionLine case final notConclusion?) ...[
                Text(
                  notConclusion,
                  key: const Key('belief_evidence_trail_not_conclusion'),
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              if (trail.sourceLine case final source?) ...[
                Text(
                  source,
                  key: const Key('belief_evidence_trail_source_line'),
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (trail.stageLabel case final stage?) ...[
                Text(
                  stage,
                  key: const Key('belief_evidence_trail_stage_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                BeliefEvidenceTrailCopy.currentBeliefLabel,
                key: const Key('belief_evidence_trail_belief_label'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                trail.currentBelief ?? '',
                key: const Key('belief_evidence_trail_current_belief'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                BeliefEvidenceTrailCopy.whatChangedLabel,
                key: const Key('belief_evidence_trail_change_label'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                adaptedChangeLine ?? '',
                key: const Key('belief_evidence_trail_change_line'),
                style: bodyStyle,
              ),
              if (trail.evidenceRows.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  BeliefEvidenceTrailCopy.evidenceLabel,
                  key: const Key('belief_evidence_trail_evidence_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < trail.evidenceRows.length; i++) ...[
                  Text(
                    trail.evidenceRows[i],
                    key: Key('belief_evidence_trail_evidence_$i'),
                    style: bodyStyle,
                  ),
                  if (i < trail.evidenceRows.length - 1)
                    const SizedBox(height: AppSpacing.xs),
                ],
              ],
              if (trail.uncertaintyLine case final uncertainty?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  BeliefEvidenceTrailCopy.stillUncertainLabel,
                  key: const Key('belief_evidence_trail_uncertain_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  uncertainty,
                  key: const Key('belief_evidence_trail_uncertainty_line'),
                  style: bodyStyle,
                ),
              ],
              if (trail.nextActionLine case final nextAction?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  BeliefEvidenceTrailCopy.addNextLabel,
                  key: const Key('belief_evidence_trail_add_next_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  nextAction,
                  key: const Key('belief_evidence_trail_next_action'),
                  style: bodyStyle,
                ),
              ],
              if (trail.footnoteLine case final footnote?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  footnote,
                  key: const Key('belief_evidence_trail_footnote'),
                  style: footnoteStyle,
                ),
              ],
              if (onAddAnother != null && trail.primaryCta != null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('belief_evidence_trail_add_cta'),
                  onPressed: onAddAnother,
                  child: Text(trail.primaryCta!),
                ),
              ],
              if (trail.historyTimeline case final history?) ...[
                const SizedBox(height: AppSpacing.lg),
                _BeliefHistorySection(timeline: history),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BeliefHistorySection extends StatelessWidget {
  const _BeliefHistorySection({required this.timeline});

  final BeliefHistoryTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          BeliefHistoryTimelineCopy.titleBuilding,
          key: const Key('belief_evidence_trail_history_heading'),
          style: labelStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          timeline.body,
          key: const Key('belief_evidence_trail_history_body'),
          style: bodyStyle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          BeliefHistoryTimelineCopy.earlierBeliefLabel,
          key: const Key('belief_evidence_trail_history_earlier_label'),
          style: labelStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          timeline.earlierBelief,
          key: const Key('belief_evidence_trail_history_earlier_belief'),
          style: bodyStyle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(BeliefHistoryTimelineCopy.currentBeliefLabel, style: labelStyle),
        const SizedBox(height: AppSpacing.xs),
        Text(
          timeline.currentBelief,
          key: const Key('belief_evidence_trail_history_current_belief'),
          style: bodyStyle,
        ),
      ],
    );
  }
}
