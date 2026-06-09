import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Improved empty state for Pressure Insights when there is no data yet.
/// Points the user at the single action that unlocks everything else.
class PressureInsightsEmptyState extends StatelessWidget {
  const PressureInsightsEmptyState({super.key, required this.onLogPressure});

  final VoidCallback onLogPressure;

  static const title = 'Your archive needs one pressure moment first.';
  static const body =
      "Log the moment you feel behind, keep going, or can't stop. ArchiveMe "
      'will start showing where that pressure repeats.';
  static const ctaLabel = 'Log pressure moment';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_insights_empty_state'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.bolt_outlined,
            size: 28,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: ArchiveMobileTypography.body(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('pressure_insights_empty_cta'),
            onPressed: onLogPressure,
            icon: const Icon(Icons.bolt_outlined),
            label: const Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}
