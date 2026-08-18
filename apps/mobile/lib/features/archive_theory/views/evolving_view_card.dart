import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/archive_theory/views/theory_page_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EvolvingViewCard extends StatelessWidget {
  const EvolvingViewCard({
    required this.snapshot, super.key,
    this.minReflections = 5,
    this.reflectionCount = 0,
  });

  final EvolvingViewSnapshot snapshot;
  final int minReflections;
  final int reflectionCount;

  @override
  Widget build(BuildContext context) {
    if (reflectionCount < minReflections || snapshot.totalTheories == 0) {
      return const SizedBox.shrink();
    }

    final updated = snapshot.lastUpdated == null
        ? null
        : DateFormat.yMMMd().format(snapshot.lastUpdated!.toLocal());

    return Container(
      key: const Key('evolving_view_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            EvolvingViewCardCopy.headline,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            EvolvingViewCardCopy.subline,
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _metric(context, EvolvingViewCardCopy.totalTheories, '${snapshot.totalTheories}'),
              _metric(context, EvolvingViewCardCopy.underReview, '${snapshot.underReviewCount}'),
              _metric(context, EvolvingViewCardCopy.strengthening, '${snapshot.strengtheningCount}'),
              _metric(
                context,
                EvolvingViewCardCopy.weakeningResolved,
                '${snapshot.weakeningOrResolvedCount}',
              ),
            ],
          ),
          if (updated != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${EvolvingViewCardCopy.lastUpdated}: $updated',
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ArchiveMobileTypography.responsiveHelper(context)),
          Text(
            value,
            style: ArchiveMobileTypography.listTitle(context).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}