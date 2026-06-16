import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/first_60_second_state.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// B. First save immediate value — shown once, right after the very first
/// successful save. The value is preservation plus future comparison:
/// nothing here claims a pattern after one entry.
class FirstRecordingValueCard extends StatelessWidget {
  const FirstRecordingValueCard({
    super.key,
    required this.onViewArchive,
    required this.onRecordAnother,
  });

  /// Opens the existing archive view.
  final VoidCallback onViewArchive;

  /// Starts the existing recording flow again.
  final VoidCallback onRecordAnother;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.first60ValueCardSeen,
      entryCount: 1,
      stage: First60Stage.firstSave.id,
      source: 'record',
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_60_value_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0F7F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            First60Copy.valueTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            First60Copy.valueBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            First60Copy.valueSecondLine,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('first_60_view_archive_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.first60ArchiveOpened,
                entryCount: 1,
                stage: First60Stage.firstSave.id,
                source: 'value_card',
              );
              onViewArchive();
            },
            child: const Text(First60Copy.valueCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('first_60_record_another_cta'),
            onPressed: onRecordAnother,
            child: const Text(First60Copy.valueSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            First60Copy.valueReassurance,
            textAlign: TextAlign.center,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
