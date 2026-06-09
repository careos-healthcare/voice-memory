import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/pattern_memory/pattern_memory_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Patterns surface: how ArchiveMe remembers one pattern across check-ins.
class PatternMemoryCard extends StatelessWidget {
  const PatternMemoryCard({super.key, required this.memory});

  final PatternMemory memory;

  static const String recordNextCta = 'Record next check-in';

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  static String statusLine(PatternMemoryStatus status) {
    switch (status) {
      case PatternMemoryStatus.forming:
        return 'ArchiveMe is starting to remember this pattern.';
      case PatternMemoryStatus.active:
        return 'This pattern keeps showing up.';
      case PatternMemoryStatus.easing:
        return 'This pattern may be getting lighter.';
      case PatternMemoryStatus.needsAttention:
        return 'This pattern may need more attention.';
      case PatternMemoryStatus.changing:
        return 'This pattern is changing.';
    }
  }

  static String lastResultLabel(String? lastResult) {
    switch (lastResult) {
      case PatternMemoryResultHint.same:
        return 'showed up';
      case PatternMemoryResultHint.lighter:
        return 'lighter';
      case PatternMemoryResultHint.heavier:
        return 'heavier';
      case PatternMemoryResultHint.changed:
        return 'changed';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final beforeMoments = memory.commonBeforeMoments.take(2).toList();
    final showHarder = memory.status == PatternMemoryStatus.needsAttention;
    final secondaryMoments =
        (showHarder ? memory.harderMoments : memory.helpedMoments)
            .take(2)
            .toList();
    final secondaryLabel = showHarder ? 'What made it heavier' : 'What helped';
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
            statusLine(memory.status),
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 16),
          ),
          if (memory.patternTitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              memory.patternTitle,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Checked ${memory.checkInCount} times · Last time: '
            '${lastResultLabel(memory.lastResult)}',
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, height: 1.4),
          ),
          if (beforeMoments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _label('Before it shows up'),
            const SizedBox(height: AppSpacing.xs),
            for (final m in beforeMoments) _moment(m),
          ],
          if (secondaryMoments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _label(secondaryLabel),
            const SizedBox(height: AppSpacing.xs),
            for (final m in secondaryMoments) _moment(m),
          ],
          if (nextQuestion != null && nextQuestion.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _label('What to check next'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              nextQuestion,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () => context.go('/record'),
              child: const Text(recordNextCta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: VoiceMemoryTypography.bodyStyle(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  Widget _moment(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '· $text',
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 14, height: 1.4),
      ),
    );
  }
}
