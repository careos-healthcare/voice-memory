import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// First-run demo: shows how moments become pattern memory over days.
class ArchiveMemoryDemoCard extends StatefulWidget {
  const ArchiveMemoryDemoCard({required this.onRecord, super.key});

  final VoidCallback onRecord;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  State<ArchiveMemoryDemoCard> createState() => _ArchiveMemoryDemoCardState();
}

class _ArchiveMemoryDemoCardState extends State<ArchiveMemoryDemoCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveMemoryDemoShown();
  }

  void _onRecord() {
    ActivationTracker.trackArchiveMemoryDemoCtaTapped();
    widget.onRecord();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ArchiveMemoryDemoCard._warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ArchiveMemoryDemoCard._warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.archiveMemoryDemoTitle,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in ConsumerUiCopy.archiveMemoryDemoRows) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                row,
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 14, height: 1.45),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            ConsumerUiCopy.archiveMemoryDemoRememberLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConsumerUiCopy.firstRecordPositioningLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _onRecord,
              child: const Text(ConsumerUiCopy.archiveMemoryDemoCta),
            ),
          ),
        ],
      ),
    );
  }
}