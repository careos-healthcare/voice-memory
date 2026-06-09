import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/pattern_memory/pattern_progress_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Patterns surface: the clear payoff of repeated check-ins.
class PatternProgressCard extends StatelessWidget {
  const PatternProgressCard({
    super.key,
    required this.progress,
    this.showRecordCta = true,
  });

  final PatternProgressMoment progress;

  /// Hidden when a next-step card already provides the obvious action.
  final bool showRecordCta;

  static const String title = 'Pattern progress';
  static const String recordNextCta = 'Record next moment';

  static const Color _surface = Color(0xFFF1F7F4);
  static const Color _border = Color(0xFFD7E8E0);

  @override
  Widget build(BuildContext context) {
    final beforeOrHelped = progress.helpedLine ?? progress.beforeLine;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            progress.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            progress.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, height: 1.4),
          ),
          if (beforeOrHelped != null && beforeOrHelped.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              beforeOrHelped,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 14, height: 1.4, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            progress.nextLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          if (showRecordCta) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => context.go('/record'),
                child: const Text(recordNextCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
