import 'package:flutter/material.dart';

import '../../features/pattern_memory/pattern_memory_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Compact post-save card: shows that ArchiveMe is remembering this pattern.
class PatternMemoryAfterSaveCard extends StatelessWidget {
  const PatternMemoryAfterSaveCard({
    super.key,
    required this.memory,
    this.onUseNext,
  });

  final PatternMemory memory;

  /// Creates tomorrow's check-in using [PatternMemory.nextBestQuestion].
  final VoidCallback? onUseNext;

  static const String title = 'This pattern is building a memory';
  static const String whatToCheckNextLabel = 'What to check next';
  static const String useThisNextCta = 'Use this next';

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  Widget build(BuildContext context) {
    final nextQuestion = memory.nextBestQuestion;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row('Checked ${memory.checkInCount} times'),
          _row('Showed up again ${memory.showedAgainCount} times'),
          _row('Felt lighter ${memory.lighterCount} times'),
          _row('Felt heavier ${memory.heavierCount} times'),
          if (nextQuestion != null && nextQuestion.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              whatToCheckNextLabel,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              nextQuestion,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
            if (onUseNext != null) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: onUseNext,
                  child: const Text(useThisNextCta),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _row(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 14, height: 1.4),
      ),
    );
  }
}
