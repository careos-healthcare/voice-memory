import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/pattern_memory/habit_proof_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Patterns-screen proof: why it is worth continuing to check this pattern.
class HabitProofCard extends StatefulWidget {
  const HabitProofCard({
    super.key,
    required this.proof,
    this.onUseNext,
  });

  final HabitProofMoment proof;

  /// Creates tomorrow's check-in from [proof.nextLine]. Shown only when set.
  final VoidCallback? onUseNext;

  static const String title = 'Why keep checking?';
  static const String cta = 'Use next check';

  static const Color _surface = Color(0xFFFBF1E6);
  static const Color _border = Color(0xFFEAD9C2);

  @override
  State<HabitProofCard> createState() => _HabitProofCardState();
}

class _HabitProofCardState extends State<HabitProofCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackHabitProofCardShown();
  }

  void _onTap() {
    ActivationTracker.trackHabitProofCtaTapped();
    widget.onUseNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    final proof = widget.proof;
    final hasNext = proof.nextLine != null && proof.nextLine!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: HabitProofCard._surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HabitProofCard._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            HabitProofCard.title,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            proof.headline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            proof.body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            proof.proofLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
          ),
          if (hasNext) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              proof.nextLine!,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: widget.onUseNext == null ? null : _onTap,
                child: const Text(HabitProofCard.cta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
