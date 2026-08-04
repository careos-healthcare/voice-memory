import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/prove_enough/monthly_ambition_pressure_review_model.dart';
import '../../features/prove_enough/monthly_ambition_pressure_review_navigation.dart';
import '../../features/retention/retention_metrics_tracker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact monthly review entry point for prove_enough surfaces.
class MonthlyAmbitionPressureReviewCard extends StatelessWidget {
  const MonthlyAmbitionPressureReviewCard({
    super.key,
    required this.review,
    required this.canViewFull,
    this.onOpen,
    this.onSeePro,
  });

  final MonthlyAmbitionPressureReview review;
  final bool canViewFull;
  final VoidCallback? onOpen;
  final VoidCallback? onSeePro;

  @override
  Widget build(BuildContext context) {
    if (!canViewFull) {
      return _ProPreviewCard(onSeePro: onSeePro);
    }

    return Container(
      key: const Key('monthly_ambition_pressure_review_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FBFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            MonthlyAmbitionPressureReview.screenTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            review.monthLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            review.direction.copy,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('monthly_ambition_pressure_review_open_cta'),
            onPressed: () {
              onOpen?.call();
              unawaited(
                RetentionMetricsTracker.track(
                  RetentionMetricsTracker.monthlyReviewOpened,
                ),
              );
              MonthlyAmbitionPressureReviewNavigation.open(context);
            },
            child: const Text('Open monthly review'),
          ),
        ],
      ),
    );
  }
}

class _ProPreviewCard extends StatelessWidget {
  const _ProPreviewCard({this.onSeePro});

  final VoidCallback? onSeePro;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('monthly_ambition_pressure_review_pro_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.accentLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            MonthlyAmbitionPressureReview.proPreviewTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            MonthlyAmbitionPressureReview.proPreviewBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('monthly_ambition_pressure_review_see_pro_cta'),
            onPressed: onSeePro,
            child: const Text(MonthlyAmbitionPressureReview.proPreviewCta),
          ),
        ],
      ),
    );
  }
}
