import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback_adaptation.dart';
import 'package:archiveme_mobile/features/activation/belief_update_payoff.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/archive/archive_insight_feedback_controls.dart';
import 'package:flutter/material.dart';

/// Four-plus entry payoff — cautious belief update with evidence snippets.
class BeliefUpdatePayoffCard extends StatelessWidget {
  const BeliefUpdatePayoffCard({
    required this.payoff,
    required this.onAddAnother,
    required this.onViewEvidence,
    super.key,
    this.showInlineActions = true,
  });

  final BeliefUpdatePayoff payoff;
  final VoidCallback onAddAnother;
  final VoidCallback onViewEvidence;
  final bool showInlineActions;

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

    return ArchiveInsightFeedbackHost(
      insightId: ArchiveInsightFeedbackStore.targetId(
        ArchiveInsightTarget.beliefUpdate,
      ),
      showControls: ArchiveInsightFeedbackGate.showForBeliefUpdate(),
      sourceEntryIds: payoff.sourceEntryIds,
      onViewEvidence: onViewEvidence,
      childBuilder: (context) {
        const target = ArchiveInsightTarget.beliefUpdate;
        final adaptedBody = ArchiveInsightFeedbackAdaptation.adaptedCopyFor(
          payoff.body,
          target,
        );

        return Container(
          key: const Key('belief_update_payoff_card'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: VoiceMemoryCards.standard(
            background: AppColors.backgroundSecondary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                payoff.title,
                key: const Key('belief_update_payoff_title'),
                style: titleStyle,
              ),
              if (payoff.stageLabel case final stage?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  stage,
                  key: const Key('belief_update_payoff_stage_label'),
                  style: labelStyle,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                adaptedBody,
                key: const Key('belief_update_payoff_body'),
                style: bodyStyle,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                BeliefUpdatePayoffCopy.currentBeliefLabel,
                key: const Key('belief_update_payoff_belief_label'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                payoff.currentBelief,
                key: const Key('belief_update_payoff_current_belief'),
                style: bodyStyle,
              ),
              if (payoff.evidenceRows.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  BeliefUpdatePayoffCopy.evidenceLabel,
                  key: const Key('belief_update_payoff_evidence_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < payoff.evidenceRows.length; i++) ...[
                  Text(
                    payoff.evidenceRows[i],
                    key: Key('belief_update_payoff_evidence_$i'),
                    style: bodyStyle,
                  ),
                  if (i < payoff.evidenceRows.length - 1)
                    const SizedBox(height: AppSpacing.xs),
                ],
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                BeliefUpdatePayoffCopy.whatChangedLabel,
                key: const Key('belief_update_payoff_change_label'),
                style: labelStyle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                payoff.whatChangedLine,
                key: const Key('belief_update_payoff_change_line'),
                style: bodyStyle,
              ),
              if (payoff.footnoteLine case final footnote?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  footnote,
                  key: const Key('belief_update_payoff_footnote'),
                  style: footnoteStyle,
                ),
              ],
              if (showInlineActions) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('belief_update_payoff_add_cta'),
                  onPressed: onAddAnother,
                  child: Text(payoff.primaryCta),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: const Key('belief_update_payoff_view_evidence_cta'),
                  onPressed: onViewEvidence,
                  child: Text(payoff.secondaryCta),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
