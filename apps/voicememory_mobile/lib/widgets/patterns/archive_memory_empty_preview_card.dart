import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Day-zero preview of what ArchiveMe will remember once enough moments exist.
class ArchiveMemoryEmptyPreviewCard extends StatefulWidget {
  const ArchiveMemoryEmptyPreviewCard({super.key, required this.onRecord});

  final VoidCallback onRecord;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  State<ArchiveMemoryEmptyPreviewCard> createState() =>
      _ArchiveMemoryEmptyPreviewCardState();
}

class _ArchiveMemoryEmptyPreviewCardState
    extends State<ArchiveMemoryEmptyPreviewCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveMemoryPreviewShown();
  }

  void _onRecord() {
    ActivationTracker.trackArchiveMemoryPreviewCtaTapped();
    widget.onRecord();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ArchiveMemoryEmptyPreviewCard._warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArchiveMemoryEmptyPreviewCard._warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.archiveMemoryPreviewTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConsumerUiCopy.archiveMemoryPreviewBody,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final bullet in ConsumerUiCopy.archiveMemoryPreviewBullets) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 14),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _onRecord,
              child: const Text(ConsumerUiCopy.archiveMemoryPreviewCta),
            ),
          ),
        ],
      ),
    );
  }
}
