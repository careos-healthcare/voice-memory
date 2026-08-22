import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/breakthrough_tracking/breakthrough_shift_detector.dart';
import 'package:archiveme_mobile/features/breakthrough_tracking/breakthrough_tracking_engine.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// High-impact Breakthrough card for mobile insight feeds.
class BreakthroughInsightCard extends StatelessWidget {
  const BreakthroughInsightCard({
    required this.shift, super.key,
  });

  final BreakthroughShift shift;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('breakthrough_insight_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: 0.15),
            AppColors.surfaceAlt.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                BreakthroughFeedCopy.eyebrow,
                style: ArchiveMobileTypography.cardLabel(context).copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            shift.headline,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          if (shift.detailLine != null) ...[
            const SizedBox(height: 4),
            Text(
              shift.detailLine!,
              style: ArchiveMobileTypography.explanationBody(context).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            BreakthroughFeedCopy.body,
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps breakthrough shifts to [ArchiveInsightKind.breakthrough] for taxonomy wiring.
ArchiveInsightKind breakthroughInsightKind() => ArchiveInsightKind.breakthrough;