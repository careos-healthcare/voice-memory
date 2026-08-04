import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../features/onboarding/record_return_pro_state.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_colors.dart';
import '../../theme/voicememory_cards.dart';

/// First-save payoff — one calm saved state with a single next-step path.
class FirstSaveEvidenceCard extends StatelessWidget {
  const FirstSaveEvidenceCard({
    super.key,
    required this.onViewArchive,
    required this.onRecordAnother,
    required this.onDoneForToday,
  });

  final VoidCallback onViewArchive;
  final VoidCallback onRecordAnother;
  final VoidCallback onDoneForToday;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: VoiceMemoryColors.captureSuccess,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  RecordReturnProCopy.evidenceTitle,
                  key: const Key('first_save_post_save_title'),
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ).copyWith(color: VoiceMemoryColors.captureSuccess),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.evidenceBody,
            key: const Key('first_save_post_save_body'),
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordReturnProCopy.evidenceSecondLine,
            key: const Key('first_save_post_save_reassurance'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('first_save_done_for_today_cta'),
            onPressed: onDoneForToday,
            child: const Text(VisibleArchiveProofCopy.firstSaveDoneForTodayCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
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
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: const Key('first_save_record_another_cta'),
              onPressed: onRecordAnother,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: const Text(RecordReturnProCopy.evidenceRecordAnother),
            ),
          ),
        ],
      ),
    );
  }
}
