import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/repeat_return_check/repeat_return_check_analytics.dart';
import '../../features/repeat_return_check/repeat_return_check_change_proof.dart';
import '../../features/repeat_return_check/repeat_return_check_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Change-over-time proof from user repeat return checks — ready state only.
class RepeatReturnCheckChangeProofCard extends StatelessWidget {
  const RepeatReturnCheckChangeProofCard({
    super.key,
    required this.proof,
    required this.entryCount,
    required this.surface,
    this.onRecordNext,
    this.showRecordNextCta = true,
  });

  final RepeatReturnCheckChangeProof proof;
  final int entryCount;
  final String surface;
  final VoidCallback? onRecordNext;
  final bool showRecordNextCta;

  @override
  Widget build(BuildContext context) {
    RepeatReturnCheckAnalytics.recordChangeProofSeen(
      latestChoice: proof.latestChoice,
      entryCount: entryCount,
      surface: surface,
    );

    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final supportStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('repeat_return_check_change_proof_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            proof.title,
            key: const Key('repeat_return_check_change_proof_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            proof.body,
            key: const Key('repeat_return_check_change_proof_body'),
            style: bodyStyle,
          ),
          if (proof.supportLine != null && proof.supportLine!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              proof.supportLine!,
              key: const Key('repeat_return_check_change_proof_support'),
              style: supportStyle,
            ),
          ],
          if (showRecordNextCta && onRecordNext != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('repeat_return_check_change_proof_record_next'),
                onPressed: onRecordNext,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.accentPrimary,
                ),
                child: Text(RepeatReturnCheckCopy.changeProofRecordNextCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
