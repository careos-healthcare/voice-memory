import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/record_return_pro_state.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// E. Pro archive continuity — soft bridge after first save or archive view.
/// Never interrupts recording; resolved once via [RecordReturnProStore].
class ProArchiveContinuityCard extends StatelessWidget {
  const ProArchiveContinuityCard({
    super.key,
    required this.entryCount,
    required this.source,
    required this.onSeePro,
    required this.onNotNow,
  });

  final int entryCount;
  final String source;
  final VoidCallback onSeePro;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.proArchiveContinuitySeen,
      entryCount: entryCount,
      stage: RecordReturnProStage.proBridge.id,
      source: source,
      oncePerSession: true,
    );
    return Container(
      key: const Key('pro_archive_continuity_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RecordReturnProCopy.proTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.proBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.proContinuityLine,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pro_archive_continuity_not_now'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.proArchiveContinuityDismissed,
                      entryCount: entryCount,
                      stage: RecordReturnProStage.proBridge.id,
                      source: source,
                    );
                    onNotNow();
                  },
                  child: const Text(RecordReturnProCopy.proSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('pro_archive_continuity_see_pro'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.proArchiveContinuityTapped,
                      entryCount: entryCount,
                      stage: RecordReturnProStage.proBridge.id,
                      source: source,
                    );
                    onSeePro();
                  },
                  child: const Text(RecordReturnProCopy.proCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
