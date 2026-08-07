import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../product/consumer_ui_copy.dart';
import '../../features/archive_memory/archive_memory_summary_model.dart';
import '../../features/archive_memory/memory_quality_engine.dart';
import '../../features/archive_memory/memory_quality_model.dart';
import '../../features/feedback/archive_feedback_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';
import '../feedback/archive_feedback_chips.dart';
import 'memory_quality_chip.dart';

/// "What ArchiveMe remembers" — one clear, plain-language summary of a pattern
/// the archive has been building over time.
class ArchiveMemorySummaryCard extends StatefulWidget {
  const ArchiveMemorySummaryCard({
    super.key,
    required this.summary,
    this.onOpenPatternMap,
    this.onFindMoments,
    this.onUseCheck,
    this.showEntryLinks = true,
    this.showFeedback = true,
    this.quality,
  });

  final ArchiveMemorySummary summary;

  /// Opens the full Pattern map.
  final VoidCallback? onOpenPatternMap;

  /// Opens Key moments to revisit related days.
  final VoidCallback? onFindMoments;

  /// Fires with the next check question when the user taps "Use this check".
  final void Function(String nextCheck)? onUseCheck;

  /// When false, hides duplicate navigation links (archive clean view handles them).
  final bool showEntryLinks;

  /// When true, shows one feedback row below the summary.
  final bool showFeedback;

  /// When set, replaces the static clarity label with a quality chip.
  final MemoryQuality? quality;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  State<ArchiveMemorySummaryCard> createState() =>
      _ArchiveMemorySummaryCardState();
}

class _ArchiveMemorySummaryCardState extends State<ArchiveMemorySummaryCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveMemorySummaryShown();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final quality =
        widget.quality ??
        buildMemoryQuality(summary: summary, keyMoments: const []);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ArchiveMemorySummaryCard._warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArchiveMemorySummaryCard._warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What ArchiveMe remembers',
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            ConsumerUiCopy.positioningBasedOnMoments,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (quality.shouldShow)
            MemoryQualityChip(quality: quality)
          else
            Text(
              summary.clarityLabel,
              style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                fontSize: 18,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.primaryMemoryLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
          ),
          _line(summary.startsBeforeLine),
          _line(summary.helpedLine),
          _line(summary.heavierLine),
          _line(summary.changedLine),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.basedOnLine,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12),
          ),
          if (summary.hasNextCheck) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Next check',
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              summary.nextCheck!,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _onUseCheck,
                child: const Text('Use this check'),
              ),
            ),
          ],
          if (widget.showEntryLinks) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onOpenPatternMap,
                    child: const Text('Open pattern map'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onFindMoments,
                    child: const Text('Find related moments'),
                  ),
                ),
              ],
            ),
          ],
          if (widget.showFeedback)
            ArchiveFeedbackChips(
              targetType: ArchiveFeedbackTargetType.archiveMemory,
              targetId: summary.id,
              patternTitle: summary.patternTitle,
              resultHint: summary.nextCheck,
            ),
        ],
      ),
    );
  }

  Widget _line(String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        value,
        style: VoiceMemoryTypography.bodyStyle(
          color: AppColors.textPrimary,
        ).copyWith(fontSize: 15, height: 1.4),
      ),
    );
  }

  void _onOpenPatternMap() {
    ActivationTracker.trackArchiveMemoryOpenPatternMapTapped();
    widget.onOpenPatternMap?.call();
  }

  void _onFindMoments() {
    ActivationTracker.trackArchiveMemoryFindMomentsTapped();
    widget.onFindMoments?.call();
  }

  void _onUseCheck() {
    final next = widget.summary.nextCheck?.trim() ?? '';
    if (next.isEmpty) return;
    ActivationTracker.trackArchiveMemoryUseCheckTapped();
    widget.onUseCheck?.call(next);
  }
}
