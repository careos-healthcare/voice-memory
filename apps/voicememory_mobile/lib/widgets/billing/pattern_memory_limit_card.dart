import 'package:flutter/material.dart';

import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Gentle memory-limit upsell — long-term pattern memory, not premium AI.
class PatternMemoryLimitCard extends StatelessWidget {
  const PatternMemoryLimitCard({
    super.key,
    required this.onUnlock,
  });

  final VoidCallback onUnlock;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.patternMemoryGrowingTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConsumerUiCopy.freeKeepsSevenKeyMoments,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 4),
          Text(
            ConsumerUiCopy.proKeepsFullMemory,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, height: 1.45, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onUnlock,
              child: const Text(ConsumerUiCopy.unlockFullMemoryCta),
            ),
          ),
        ],
      ),
    );
  }
}
