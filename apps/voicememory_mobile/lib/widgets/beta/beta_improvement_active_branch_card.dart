import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/beta_improvement/beta_improvement_model.dart';
import '../../features/beta_improvement/beta_improvement_recommendation_gate.dart';
import '../../features/beta_improvement/pro_packaging_copy_fix.dart';
import '../../features/beta_improvement/pro_utility_copy_fix.dart';
import '../../features/beta_improvement/proof_to_pro_path_engine.dart';
import '../../features/beta_improvement/proof_emotional_clarity_copy_fix.dart';
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

    final proofToProOverride = ProofToProPathEngine.isProofToProOverride();
    final branch =
        branchOverride ?? BetaImprovementRecommendationGate.activeBranch();
    final utilityPreviews = branch == BetaImprovementBranch.proUtility
        ? [
            '${ProUtilityCopyFix.historyTitle}: ${ProUtilityCopyFix.historyBody}',
            '${ProUtilityCopyFix.exportTitle}: ${ProUtilityCopyFix.exportBody}',
            '${ProUtilityCopyFix.privateReportTitle}: ${ProUtilityCopyFix.privateReportBody} ${ProUtilityCopyFix.plannedSuffix}',
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
            proofToProOverride
                ? 'Proof-to-Pro path (paired override)'
                : BetaImprovementRecommendationGate.branchLabel(branch),
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
          if (proofToProOverride) ...[
            const SizedBox(height: 8),
            Text(
              'Preview: ${ProofEmotionalClarityCopyFix.headline} → ${ProPackagingCopyFix.proofBridge}',
              key: const Key('beta_improvement_proof_to_pro_preview'),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            Text(
              'Override: --dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=proofToPro',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          if (branch == BetaImprovementBranch.proPackaging) ...[
            const SizedBox(height: 8),
            Text(
              'Preview: ${ProPackagingCopyFix.headline}',
              key: const Key('beta_improvement_pro_packaging_preview'),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            Text(
              ProPackagingCopyFix.whyPayLine,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            Text(
              'Override: --dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=proPackaging',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          if (branch == BetaImprovementBranch.proofEmotionalClarity) ...[
            const SizedBox(height: 8),
            Text(
              'Preview: ${ProofEmotionalClarityCopyFix.headline}',
              key: const Key('beta_improvement_proof_clarity_preview'),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            Text(
              'Override: --dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=proofEmotionalClarity',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          if (branch == BetaImprovementBranch.proUtility) ...[
            const SizedBox(height: 8),
            Text(
              'Preview: ${ProUtilityCopyFix.headline}',
              key: const Key('beta_improvement_pro_utility_preview'),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            Text(
              'Override: --dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=proUtility',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
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
