import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Trial-only: one-tap usefulness rating after a return comparison.
class TrialUsefulnessPrompt extends StatelessWidget {
  const TrialUsefulnessPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Was this useful?',
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('Yes, useful', ActivationTracker.trackUsefulnessYes),
            _chip('Sort of', ActivationTracker.trackUsefulnessSortOf),
            _chip('Not really', ActivationTracker.trackUsefulnessNotReally),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, Future<void> Function() onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: () => onTap(),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.warmBorder),
      labelStyle: VoiceMemoryTypography.bodyStyle(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: 13),
    );
  }
}