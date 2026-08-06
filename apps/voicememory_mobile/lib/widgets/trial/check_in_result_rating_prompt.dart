import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/trial/hook_diagnosis_model.dart';
import '../../features/trial/hook_diagnosis_tracker.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// One-tap usefulness rating after check-in loop is closed.
class CheckInResultRatingPrompt extends StatefulWidget {
  const CheckInResultRatingPrompt({
    super.key,
    required this.checkInId,
    this.onRated,
  });

  final String checkInId;
  final VoidCallback? onRated;

  @override
  State<CheckInResultRatingPrompt> createState() =>
      _CheckInResultRatingPromptState();
}

class _CheckInResultRatingPromptState extends State<CheckInResultRatingPrompt> {
  bool _showNotUsefulFollowUp = false;
  bool _finished = false;

  void _onRating(String rating) {
    HookDiagnosisTracker.trackCheckInResultRated(
      checkInId: widget.checkInId,
      rating: rating,
    );
    switch (rating) {
      case HookDiagnosisRating.yes:
        ActivationTracker.trackActivationResultRatedUseful();
      case HookDiagnosisRating.sortOf:
        ActivationTracker.trackActivationResultRatedSortOf();
      case HookDiagnosisRating.notReally:
        ActivationTracker.trackActivationResultRatedNotUseful();
    }
    if (rating == HookDiagnosisRating.notReally) {
      setState(() => _showNotUsefulFollowUp = true);
      return;
    }
    setState(() => _finished = true);
    widget.onRated?.call();
  }

  void _onNotUsefulReason(String reason) {
    HookDiagnosisTracker.trackCheckInResultNotUsefulReason(
      checkInId: widget.checkInId,
      reason: reason,
    );
    setState(() {
      _showNotUsefulFollowUp = false;
      _finished = true;
    });
    widget.onRated?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        if (!_showNotUsefulFollowUp) ...[
          Text(
            ConsumerUiCopy.checkInResultUsefulPrompt,
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
        ] else ...[
          Text(
            ConsumerUiCopy.checkInResultNotUsefulFollowUp,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _reasonChip('Too vague', HookDiagnosisNotUsefulReason.tooVague),
              _reasonChip(
                'Not accurate',
                HookDiagnosisNotUsefulReason.notAccurate,
              ),
              _reasonChip(
                'I already knew this',
                HookDiagnosisNotUsefulReason.alreadyKnewThis,
              ),
              _reasonChip('Confusing', HookDiagnosisNotUsefulReason.confusing),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(String label, String rating) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _onRating(rating),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.warmBorder),
      labelStyle: VoiceMemoryTypography.bodyStyle(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: 13),
    );
  }

  Widget _reasonChip(String label, String reason) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _onNotUsefulReason(reason),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.warmBorder),
      labelStyle: VoiceMemoryTypography.bodyStyle(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: 13),
    );
  }
}
