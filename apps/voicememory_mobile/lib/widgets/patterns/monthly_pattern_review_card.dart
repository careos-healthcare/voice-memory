import 'package:flutter/material.dart';

import '../../features/monthly_review/monthly_pattern_review_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// A simple monthly recap: what kept repeating, what got lighter or heavier,
/// what helped, and one check to carry into next month.
class MonthlyPatternReviewCard extends StatelessWidget {
  const MonthlyPatternReviewCard({
    super.key,
    required this.review,
    this.onUseCheck,
    this.showTitle = true,
  });

  final MonthlyPatternReview review;

  /// Fires with the next check question when the user taps the CTA.
  final void Function(String nextCheck)? onUseCheck;

  /// When false the "This month" heading is hidden (e.g. under an app bar).
  final bool showTitle;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

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
          if (showTitle) ...[
            Text(
              'This month',
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            review.monthLabel,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            review.confidenceLabel,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          _section('This kept repeating', review.keptRepeating),
          _section('This got lighter', review.gotLighter),
          _section('This got heavier', review.gotHeavier),
          _section('This helped', review.helped),
          _section('One check for next month', review.nextCheck,
              emphasize: true),
          if (review.hasNextCheck && onUseCheck != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => onUseCheck!(review.nextCheck!.trim()),
                child: const Text('Use next month\u2019s check'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String label, String? value, {bool emphasize = false}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(
              fontSize: emphasize ? 16 : 15,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
