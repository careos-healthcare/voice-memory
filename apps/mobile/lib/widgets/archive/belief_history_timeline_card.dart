import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/belief_history_timeline.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Belief change over time — earlier vs current, not a generic journal list.
class BeliefHistoryTimelineCard extends StatelessWidget {
  const BeliefHistoryTimelineCard({required this.timeline, super.key});

  final BeliefHistoryTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('belief_history_timeline_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            timeline.title,
            key: const Key('belief_history_timeline_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            timeline.body,
            key: const Key('belief_history_timeline_body'),
            style: bodyStyle,
          ),
          if (timeline.contextAwareSummaryLine case final contextSummary?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              contextSummary,
              key: const Key('belief_history_timeline_context_summary'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (timeline.contextAwareDetailLine case final contextDetail?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              contextDetail,
              key: const Key('belief_history_timeline_context_detail'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefHistoryTimelineCopy.earlierBeliefLabel,
            key: const Key('belief_history_timeline_earlier_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            timeline.earlierBelief,
            key: const Key('belief_history_timeline_earlier_belief'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefHistoryTimelineCopy.currentBeliefLabel,
            key: const Key('belief_history_timeline_current_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            timeline.currentBelief,
            key: const Key('belief_history_timeline_current_belief'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefHistoryTimelineCopy.whatChangedLabel,
            key: const Key('belief_history_timeline_change_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            timeline.whatChangedLine,
            key: const Key('belief_history_timeline_change_line'),
            style: bodyStyle,
          ),
          if (timeline.evidenceRows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              BeliefHistoryTimelineCopy.evidenceLabel,
              key: const Key('belief_history_timeline_evidence_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < timeline.evidenceRows.length; i++) ...[
              Text(
                timeline.evidenceRows[i],
                key: Key('belief_history_timeline_evidence_$i'),
                style: bodyStyle,
              ),
              if (i < timeline.evidenceRows.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ],
      ),
    );
  }
}