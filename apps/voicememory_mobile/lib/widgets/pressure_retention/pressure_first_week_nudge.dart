import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// First-week nudge shown when the user has only 1–2 pressure moments.
/// Sets honest expectations: a few more reveal whether it's a real pattern.
class PressureFirstWeekNudge extends StatelessWidget {
  const PressureFirstWeekNudge({super.key});

  static const title = 'Early signal';
  static const body =
      'Log a few more pressure moments this week to see whether this is a '
      'one-off or a repeating pattern.';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_first_week_nudge'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(
        background: AppColors.surfaceAlt,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.trending_up_outlined,
            size: 18,
            color: AppColors.accentSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ArchiveMobileTypography.cardLabel(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: ArchiveMobileTypography.body(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
