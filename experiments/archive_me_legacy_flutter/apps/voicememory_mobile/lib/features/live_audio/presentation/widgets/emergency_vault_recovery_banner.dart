import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

/// Inline feedback and actions when encrypted audio survives an interrupted session.
class EmergencyVaultRecoveryBanner extends StatelessWidget {
  const EmergencyVaultRecoveryBanner({
    super.key,
    required this.recoveredChunkCount,
    required this.totalDuration,
    required this.onRecover,
    required this.onDiscard,
    this.isBusy = false,
  });

  final int recoveredChunkCount;
  final Duration totalDuration;
  final VoidCallback? onRecover;
  final VoidCallback? onDiscard;
  final bool isBusy;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chunkLabel = recoveredChunkCount == 1 ? 'chunk' : 'chunks';

    return Material(
      color: AppColors.surfaceAlt,
      elevation: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.restore_page_rounded,
              color: AppColors.accentPrimary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unsaved audio recovered',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Found ${_formatDuration(totalDuration)} '
                    '($recoveredChunkCount $chunkLabel) from an interrupted recording.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: isBusy ? null : onDiscard,
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: isBusy ? null : onRecover,
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }
}
