import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/patterns/trial_usefulness_prompt.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Shows how today's reflection compares with yesterday's watch-for commitment.
class ReturnComparisonCard extends StatefulWidget {
  const ReturnComparisonCard({required this.comparison, super.key});

  final ReturnComparison comparison;

  @override
  State<ReturnComparisonCard> createState() => _ReturnComparisonCardState();
}

class _ReturnComparisonCardState extends State<ReturnComparisonCard> {
  @override
  void initState() {
    super.initState();
    unawaited(ActivationTracker.trackComparisonViewed());
  }

  ReturnComparison get comparison => widget.comparison;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  Widget build(BuildContext context) {
    final chips = comparison.chips.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.returnComparisonCardTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            comparison.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            comparison.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final chip in chips) _Chip(label: chip)],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _labelValue(
            ConsumerUiCopy.returnComparisonYesterdayLabel,
            comparison.yesterdayWatchFor,
          ),
          const SizedBox(height: AppSpacing.sm),
          _labelValue(
            ConsumerUiCopy.returnComparisonTodayLabel,
            comparison.todayReflectionSummary,
          ),
          if (TrialMode.enabled) ...[
            const SizedBox(height: AppSpacing.md),
            const TrialUsefulnessPrompt(),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () => context.go('/record'),
              child: const Text(
                ConsumerUiCopy.returnComparisonRecordAnotherCta,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () => context.go('/belief-changes'),
              child: const Text(
                ConsumerUiCopy.tomorrowReturnStatusSeeChangedCta,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(height: 1.4, fontSize: 13),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ReturnComparisonCardState._warmBorder),
      ),
      child: Text(
        label,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 13),
      ),
    );
  }
}