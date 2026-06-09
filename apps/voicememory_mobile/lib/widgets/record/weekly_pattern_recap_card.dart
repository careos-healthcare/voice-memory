import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/pattern_memory/weekly_pattern_recap_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Post check-in weekly payoff: what kept repeating this week.
class WeeklyPatternRecapCard extends StatefulWidget {
  const WeeklyPatternRecapCard({
    super.key,
    required this.recap,
    this.onUseNext,
  });

  final WeeklyPatternRecap recap;

  /// Creates tomorrow's check-in from [recap.nextQuestion]. Shown when set.
  final VoidCallback? onUseNext;

  static const String title = 'This week';
  static const String cta = 'Use this next week';

  static const Color _surface = Color(0xFFF4F0FB);
  static const Color _border = Color(0xFFE0D6F2);

  @override
  State<WeeklyPatternRecapCard> createState() => _WeeklyPatternRecapCardState();
}

class _WeeklyPatternRecapCardState extends State<WeeklyPatternRecapCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackWeeklyPatternRecapShown();
  }

  void _onTap() {
    ActivationTracker.trackWeeklyPatternRecapCtaTapped();
    widget.onUseNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    final recap = widget.recap;
    final hasNext =
        recap.nextQuestion != null && recap.nextQuestion!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: WeeklyPatternRecapCard._surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WeeklyPatternRecapCard._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            WeeklyPatternRecapCard.title,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            recap.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            recap.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, height: 1.4),
          ),
          if (recap.usefulLine != null && recap.usefulLine!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              recap.usefulLine!,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ],
          if (hasNext) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              recap.nextQuestion!,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: widget.onUseNext == null ? null : _onTap,
                child: const Text(WeeklyPatternRecapCard.cta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
