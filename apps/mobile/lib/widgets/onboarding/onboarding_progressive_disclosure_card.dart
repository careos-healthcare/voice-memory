import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/settings/locked_feature_placeholder.dart';
import 'package:flutter/material.dart';

/// First-run preview of tools that stay locked until the archive has a rhythm.
class OnboardingProgressiveDisclosureCard extends StatelessWidget {
  const OnboardingProgressiveDisclosureCard({
    super.key,
    this.snapshot = UserMilestoneSnapshot.empty,
  });

  final UserMilestoneSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('onboarding_progressive_disclosure_card'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        color: AppColors.backgroundPrimary,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProgressiveDisclosureCopy.onboardingTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            ProgressiveDisclosureCopy.onboardingBody,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          LockedFeaturePlaceholder(
            title: ProgressiveDisclosureCopy.beliefShiftTitle,
            subtitle: ProgressiveDisclosureCopy.beliefShiftSubtitle,
            surface: ProgressiveSurface.beliefShiftGraphs,
            snapshot: snapshot,
          ),
          LockedFeaturePlaceholder(
            title: ProgressiveDisclosureCopy.vectorTitle,
            subtitle: ProgressiveDisclosureCopy.vectorSubtitle,
            surface: ProgressiveSurface.vectorRetrievalHyperparameters,
            snapshot: snapshot,
          ),
          LockedFeaturePlaceholder(
            title: ProgressiveDisclosureCopy.ragTitle,
            subtitle: ProgressiveDisclosureCopy.ragSubtitle,
            surface: ProgressiveSurface.deepRagConfiguration,
            snapshot: snapshot,
          ),
        ],
      ),
    );
  }
}
