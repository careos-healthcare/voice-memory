import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/pressure_weekly_recap_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// "Weekly pressure recap" card built from local entries in the last 7 days.
class PressureWeeklyRecapCard extends StatelessWidget {
  const PressureWeeklyRecapCard({super.key, required this.recap});

  final PressureWeeklyRecap recap;

  static const title = 'Weekly pressure recap';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_weekly_recap_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFDF8F3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            recap.sentence,
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (recap.hasData) ...[
            const SizedBox(height: AppSpacing.md),
            _row(context, 'Pressure moments', '${recap.count}'),
            if (recap.mostCommonOptionLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _row(context, 'Most common', recap.mostCommonOptionLabel!),
            ],
            if (recap.mostCommonContextLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _row(context, 'Most common context',
                  recap.mostCommonContextLabel!),
            ],
            const SizedBox(height: AppSpacing.xs),
            _row(context, 'Chose to stop', '${recap.choseToStopCount}'),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: ArchiveMobileTypography.body(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
