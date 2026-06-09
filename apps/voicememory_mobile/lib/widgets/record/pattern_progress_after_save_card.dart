import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/pattern_memory/pattern_progress_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Post-save payoff: "here is what changed because you kept checking this".
class PatternProgressAfterSaveCard extends StatefulWidget {
  const PatternProgressAfterSaveCard({
    super.key,
    required this.progress,
    this.onUseNext,
  });

  final PatternProgressMoment progress;

  /// Creates tomorrow's check-in from [PatternProgressMoment.nextLine].
  final VoidCallback? onUseNext;

  static const String title = 'What changed';
  static const String useThisNextCta = 'Use this next';

  static const Color _surface = Color(0xFFF1F7F4);
  static const Color _border = Color(0xFFD7E8E0);

  @override
  State<PatternProgressAfterSaveCard> createState() =>
      _PatternProgressAfterSaveCardState();
}

class _PatternProgressAfterSaveCardState
    extends State<PatternProgressAfterSaveCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackPatternProgressCardShown();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final beforeOrHelped = p.helpedLine ?? p.beforeLine;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: PatternProgressAfterSaveCard._surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PatternProgressAfterSaveCard._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PatternProgressAfterSaveCard.title,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            p.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            p.body,
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
            p.nextLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          if (widget.onUseNext != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: widget.onUseNext,
                child: const Text(PatternProgressAfterSaveCard.useThisNextCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
