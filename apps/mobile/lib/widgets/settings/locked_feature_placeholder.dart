import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Locked advanced-tool row with a calm progress bar for beginners.
class LockedFeaturePlaceholder extends StatelessWidget {
  const LockedFeaturePlaceholder({
    super.key,
    required this.title,
    required this.subtitle,
    required this.surface,
    required this.snapshot,
  });

  final String title;
  final String subtitle;
  final ProgressiveSurface surface;
  final UserMilestoneSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final requirement = ProgressiveDisclosure.requirementFor(surface);
    final progress = snapshot.progressToward(surface);
    final hint = ProgressiveDisclosureCopy.lockedHint(
      entriesNeeded: requirement.minEntries,
      daysNeeded: requirement.minActiveDays,
      entriesHave: snapshot.journalEntryCount,
      daysHave: snapshot.daysActive,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              key: Key('locked_feature_progress_${surface.name}'),
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.borderSubtle,
              color: AppColors.accentPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
