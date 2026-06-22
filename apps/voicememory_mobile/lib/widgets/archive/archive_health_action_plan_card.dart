import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/archive_health_action_plan.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact action plan card — concrete steps to improve archive evidence.
class ArchiveHealthActionPlanCard extends StatelessWidget {
  const ArchiveHealthActionPlanCard({
    super.key,
    required this.plan,
    required this.onPrimary,
    this.onSecondary,
  });

  final ArchiveHealthActionPlan plan;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    if (!plan.showCard) return const SizedBox.shrink();

    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final labelStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );

    return Container(
      key: const Key('archive_health_action_plan_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            plan.title,
            key: const Key('archive_health_action_plan_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            plan.subtitle,
            key: const Key('archive_health_action_plan_subtitle'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          if (plan.contextAwareSummaryLine case final contextSummary?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              contextSummary,
              key: const Key('archive_health_action_plan_context_summary'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (plan.contextAwareDetailLine case final contextDetail?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              contextDetail,
              key: const Key('archive_health_action_plan_context_detail'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.archiveHealthActionPlanItemsLabel,
            key: const Key('archive_health_action_plan_items_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var i = 0; i < plan.actionItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                plan.actionItems[i],
                key: Key('archive_health_action_plan_item_$i'),
                style: bodyStyle,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('archive_health_action_plan_primary_cta'),
            onPressed: onPrimary,
            child: Text(plan.primaryCta),
          ),
          if (onSecondary != null && plan.secondaryCta != null) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('archive_health_action_plan_secondary_cta'),
              onPressed: onSecondary,
              child: Text(plan.secondaryCta!),
            ),
          ],
        ],
      ),
    );
  }
}
