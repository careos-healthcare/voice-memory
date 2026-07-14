import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/beta_improvement/beta_improvement_model.dart';
import '../../features/beta_improvement/beta_improvement_recommendation_gate.dart';
import '../../features/beta_improvement/pro_utility_copy_fix.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Beta-only active improvement branch indicator — internal only.
class BetaImprovementActiveBranchCard extends StatelessWidget {
  const BetaImprovementActiveBranchCard({
    super.key,
    this.compact = false,
    this.branchOverride,
  });

  final bool compact;
  final BetaImprovementBranch? branchOverride;

  @override
  Widget build(BuildContext context) {
    if (!ArchiveBetaMissionGate.isEnabled) {
      return const SizedBox.shrink(
        key: Key('beta_improvement_active_branch_hidden'),
      );
    }

    final branch =
        branchOverride ?? BetaImprovementRecommendationGate.activeBranch();
    final utilityPreviews = branch == BetaImprovementBranch.proUtility
        ? [
            ProUtilityCopyFix.historyPreview,
            ProUtilityCopyFix.exportPreview,
            '${ProUtilityCopyFix.reportPreview} ${ProUtilityCopyFix.plannedSuffix}',
          ]
        : null;

    return Container(
      key: const Key('beta_improvement_active_branch_card'),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Active beta improvement branch',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            BetaImprovementRecommendationGate.branchLabel(branch),
            key: const Key('beta_improvement_active_branch_label'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            branch == BetaImprovementBranch.none
                ? 'Baseline V1 copy only. Log tester outcomes to activate one branch.'
                : 'Only this branch copy is emphasized in live UI for matching evidence states.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (utilityPreviews != null) ...[
            const SizedBox(height: 8),
            Text(
              ProUtilityCopyFix.previewLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            for (final preview in utilityPreviews)
              Text(
                preview,
                key: Key('beta_improvement_utility_${preview.hashCode}'),
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
          ],
        ],
      ),
    );
  }
}
