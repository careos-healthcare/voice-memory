import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/record_return_pro_state.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// B. First save payoff — archive started, one more moment to compare.
class FirstSaveEvidenceCard extends StatelessWidget {
  const FirstSaveEvidenceCard({
    super.key,
    required this.onViewArchive,
    required this.onRecordAnother,
  });

  final VoidCallback onViewArchive;
  final VoidCallback onRecordAnother;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.firstSaveEvidenceSeen,
      entryCount: 1,
      stage: RecordReturnProStage.evidence.id,
      source: 'record',
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_save_archive_started_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0F7F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RecordReturnProCopy.evidenceTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.evidenceBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.evidenceSecondLine,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('first_save_record_another_cta'),
            onPressed: onRecordAnother,
            child: const Text(RecordReturnProCopy.evidenceRecordAnother),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('first_save_view_archive_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.firstSaveEvidenceViewArchiveTapped,
                entryCount: 1,
                stage: RecordReturnProStage.evidence.id,
                source: 'record',
              );
              onViewArchive();
            },
            child: const Text(RecordReturnProCopy.evidenceViewArchive),
          ),
        ],
      ),
    );
  }
}
