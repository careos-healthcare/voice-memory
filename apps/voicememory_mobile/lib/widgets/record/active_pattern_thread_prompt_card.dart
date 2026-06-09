import 'package:flutter/material.dart';

import '../../features/tomorrow_return/active_pattern_thread_coordinator.dart';
import '../../features/tomorrow_return/active_pattern_thread_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Record screen prompt to continue an active named pattern thread.
class ActivePatternThreadPromptCard extends StatelessWidget {
  const ActivePatternThreadPromptCard({
    super.key,
    required this.thread,
    this.onAddMoment,
    this.onPause,
  });

  final ActivePatternThread thread;
  final VoidCallback? onAddMoment;
  final Future<void> Function()? onPause;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  Widget build(BuildContext context) {
    final statusLine =
        ActivePatternThreadCoordinator.recordStatusLine(thread);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.activePatternContinueTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            thread.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            statusLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onAddMoment,
              child: const Text(ConsumerUiCopy.activePatternAddMomentCta),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: () async {
                if (onPause != null) {
                  await onPause!();
                  return;
                }
                await ActivePatternThreadCoordinator.pauseThread();
              },
              child: const Text(ConsumerUiCopy.activePatternPauseCta),
            ),
          ),
        ],
      ),
    );
  }
}
