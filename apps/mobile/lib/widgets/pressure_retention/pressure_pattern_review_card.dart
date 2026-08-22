import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_pattern_review_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// The Pressure Pattern Review — the strongest return/paywall moment, shown
/// once the archive holds 5+ pressure entries.
///
/// Free users see the title plus the "what keeps repeating" preview and a
/// locked "Unlock full review" row that opens the existing subscription flow.
/// Pro users see every section.
class PressurePatternReviewCard extends StatelessWidget {
  const PressurePatternReviewCard({
    required this.review, required this.isPro, super.key,
    this.onUnlock,
  });

  final PressurePatternReview review;
  final bool isPro;

  /// Opens the Pro upgrade path from the locked row (free only).
  final VoidCallback? onUnlock;

  static const lockedRowLabel = 'Unlock full review';
  static const lockedHint =
      "Your full review — costs, changes, and next week's experiment — is "
      'part of ArchiveMe Pro.';

  @override
  Widget build(BuildContext context) {
    if (!review.hasReview) return const SizedBox.shrink();

    return Container(
      key: const Key('pressure_pattern_review_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFBF6EE),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 20,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  PressurePatternReview.title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Built from ${review.entryCount} pressure moments on this device.',
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (review.repeatingSummary != null)
            _section(
              context,
              PressurePatternReview.repeatingSectionTitle,
              review.repeatingSummary!,
            ),
          if (isPro) ..._fullSections(context) else ..._lockedSections(context),
        ],
      ),
    );
  }

  List<Widget> _fullSections(BuildContext context) {
    return [
      Column(
        key: const Key('pressure_pattern_review_full'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (review.strongestTrigger != null)
            _section(
              context,
              'Strongest repeated trigger',
              review.strongestTrigger!,
            ),
          if (review.likelyCost != null)
            _section(
              context,
              PressurePatternReview.costSectionTitle,
              'The most likely cost so far: ${review.likelyCost!.toLowerCase()}.',
            ),
          _section(
            context,
            PressurePatternReview.changeSectionTitle,
            review.changeSummary ?? PressurePatternReview.noChangeCopy,
          ),
          _section(
            context,
            PressurePatternReview.experimentSectionTitle,
            review.experimentSuggestion,
          ),
          Text(
            'Confidence: ${review.confidence.label}',
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    ];
  }

  List<Widget> _lockedSections(BuildContext context) {
    return [
      const SizedBox(height: AppSpacing.sm),
      Text(
        lockedHint,
        style: ArchiveMobileTypography.body(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.sm),
      InkWell(
        key: const Key('pressure_pattern_review_locked'),
        onTap: onUnlock,
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  lockedRowLabel,
                  style: ArchiveMobileTypography.body(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}