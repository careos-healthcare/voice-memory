import 'package:archiveme_mobile/features/archive_review/archive_range_review_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Compact card summarising what the archive remembers from a period.
class ArchiveRangeReviewCard extends StatelessWidget {
  const ArchiveRangeReviewCard({
    required this.review, super.key,
    this.onOpenReview,
    this.onUseCheck,
  });

  final ArchiveRangeReview review;
  final VoidCallback? onOpenReview;
  final void Function(String nextCheck)? onUseCheck;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Archive review',
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            review.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            review.dateRangeLabel,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${review.momentCount} ${review.momentCount == 1 ? 'moment' : 'moments'}'
            '${review.patternCount > 0 ? ' · ${review.patternCount} ${review.patternCount == 1 ? 'pattern' : 'patterns'}' : ''}',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13),
          ),
          if (review.hasEnoughData && review.mainLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.mainLine,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
          ],
          if (!review.hasEnoughData) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Record a few more moments in this period.',
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 14, height: 1.45),
            ),
          ],
          if (review.lighterLine != null &&
              review.type != ArchiveRangeReviewType.lighter) ...[
            const SizedBox(height: AppSpacing.xs),
            _line(review.lighterLine!),
          ],
          if (review.heavierLine != null &&
              review.type != ArchiveRangeReviewType.heavier) ...[
            const SizedBox(height: AppSpacing.xs),
            _line(review.heavierLine!),
          ],
          if (review.changedLine != null &&
              review.type != ArchiveRangeReviewType.changed) ...[
            const SizedBox(height: AppSpacing.xs),
            _line(review.changedLine!),
          ],
          if (review.helpedLine != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _line(review.helpedLine!),
          ],
          if (review.hasNextCheck) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.nextCheck!,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (onOpenReview != null)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onOpenReview,
                child: const Text('Open review'),
              ),
            ),
          if (review.hasNextCheck && onUseCheck != null) ...[
            if (onOpenReview != null) const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => onUseCheck!(review.nextCheck!.trim()),
                child: const Text('Use this check'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String text) => Text(
    text,
    style: VoiceMemoryTypography.bodyStyle(
      color: AppColors.textSecondary,
    ).copyWith(fontSize: 13, height: 1.4),
  );
}