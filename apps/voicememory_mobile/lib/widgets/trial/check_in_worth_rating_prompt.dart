import 'package:flutter/material.dart';

import '../../features/trial/hook_diagnosis_model.dart';
import '../../features/trial/hook_diagnosis_tracker.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// One-tap rating after tomorrow check-in is created.
class CheckInWorthRatingPrompt extends StatelessWidget {
  const CheckInWorthRatingPrompt({
    super.key,
    required this.checkInId,
    this.onRated,
  });

  final String checkInId;
  final VoidCallback? onRated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppSpacing.lg),
        Text(
          ConsumerUiCopy.checkInWorthQuestionPrompt,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('Yes', HookDiagnosisRating.yes),
            _chip('Sort of', HookDiagnosisRating.sortOf),
            _chip('Not really', HookDiagnosisRating.notReally),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, String rating) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        HookDiagnosisTracker.trackCheckInQuestionRated(
          checkInId: checkInId,
          rating: rating,
        );
        onRated?.call();
      },
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.warmBorder),
      labelStyle: VoiceMemoryTypography.bodyStyle(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: 13),
    );
  }
}
