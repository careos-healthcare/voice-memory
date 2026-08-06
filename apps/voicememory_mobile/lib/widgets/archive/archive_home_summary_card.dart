import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/archive_home_summary.dart';
import '../../features/activation/archive_insight_feedback.dart';
import '../../features/activation/archive_insight_feedback_adaptation.dart';
import '../../features/pressure_retention/shareable_archive_proof_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../pressure_retention/shareable_archive_proof_card.dart';
import 'archive_insight_feedback_controls.dart';

/// Archive Home command center — belief, change, evidence, and next action.
class ArchiveHomeSummaryCard extends StatelessWidget {
  const ArchiveHomeSummaryCard({
    super.key,
    required this.summary,
    required this.onPrimary,
    this.onSecondary,
    this.shareProof,
  });

  final ArchiveHomeSummary summary;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final ShareableArchiveProof? shareProof;

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
      insightId: ArchiveInsightFeedbackStore.archiveHomeId(summary.stage),
      showControls: ArchiveInsightFeedbackGate.showForArchiveHome(
        summary.stage,
      ),
      childBuilder: (context) {
        const target = ArchiveInsightTarget.archiveHome;
        final adaptedBody = ArchiveInsightFeedbackAdaptation.adaptedCopyFor(
          summary.body,
          target,
          archiveHomeStage: summary.stage,
        );
        final adaptedSubtitle = summary.subtitle == null
            ? null
            : ArchiveInsightFeedbackAdaptation.adaptedCopyFor(
                summary.subtitle!,
                target,
                archiveHomeStage: summary.stage,
              );

        return Container(
          key: const Key('archive_home_summary_card'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: VoiceMemoryCards.standard(
            background: AppColors.backgroundSecondary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary.title.isNotEmpty) ...[
                Text(
                  summary.title,
                  key: const Key('archive_home_summary_title'),
                  style: titleStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              if (adaptedSubtitle case final subtitle?) ...[
                Text(
                  subtitle,
                  key: const Key('archive_home_summary_subtitle'),
                  style: bodyStyle,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                adaptedBody,
                key: const Key('archive_home_summary_body'),
                style: bodyStyle,
              ),
              if (summary.footnoteLine case final footnote?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  footnote,
                  key: const Key('archive_home_summary_footnote'),
                  style: footnoteStyle,
                ),
              ],
              if (summary.contextAwareSummaryLine
                  case final contextSummary?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  contextSummary,
                  key: const Key('archive_home_summary_context_summary'),
                  style: footnoteStyle,
                ),
              ],
              if (summary.contextAwareDetailLine case final contextDetail?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  contextDetail,
                  key: const Key('archive_home_summary_context_detail'),
                  style: footnoteStyle,
                ),
              ],
              if (summary.currentBeliefLine case final belief?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  ArchiveHomeSummaryCopy.beliefLabel,
                  key: const Key('archive_home_summary_belief_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  belief,
                  key: const Key('archive_home_summary_belief_line'),
                  style: bodyStyle,
                ),
              ],
              if (summary.whatChangedLine case final changed?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  ArchiveHomeSummaryCopy.whatChangedLabel,
                  key: const Key('archive_home_summary_change_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  changed,
                  key: const Key('archive_home_summary_change_line'),
                  style: bodyStyle,
                ),
              ],
              if (summary.evidenceRows.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  ArchiveHomeSummaryCopy.evidenceLabel,
                  key: const Key('archive_home_summary_evidence_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < summary.evidenceRows.length; i++) ...[
                  Text(
                    summary.evidenceRows[i],
                    key: Key('archive_home_summary_evidence_$i'),
                    style: bodyStyle,
                  ),
                  if (i < summary.evidenceRows.length - 1)
                    const SizedBox(height: AppSpacing.xs),
                ],
              ],
              if (summary.nextActionLine case final nextAction?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  ArchiveHomeSummaryCopy.nextActionLabel,
                  key: const Key('archive_home_summary_next_label'),
                  style: labelStyle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  nextAction,
                  key: const Key('archive_home_summary_next_line'),
                  style: bodyStyle,
                ),
              ],
              if (summary.primaryCta != null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  key: const Key('archive_home_summary_primary_cta'),
                  onPressed: onPrimary,
                  child: Text(summary.primaryCta!),
                ),
              ],
              if (onSecondary != null && summary.secondaryCta != null) ...[
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: const Key('archive_home_summary_secondary_cta'),
                  onPressed: onSecondary,
                  child: Text(summary.secondaryCta!),
                ),
              ],
              if (shareProof?.hasProof == true) ...[
                const SizedBox(height: AppSpacing.lg),
                ShareableArchiveProofCard(proof: shareProof!),
              ],
            ],
          ),
        );
      },
    );
  }
}
