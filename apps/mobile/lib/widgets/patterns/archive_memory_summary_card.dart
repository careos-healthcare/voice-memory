import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:archiveme_mobile/features/archive_memory/memory_quality_engine.dart';
import 'package:archiveme_mobile/features/archive_memory/memory_quality_model.dart';
import 'package:archiveme_mobile/features/feedback/archive_feedback_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/feedback/archive_feedback_chips.dart';
import 'package:archiveme_mobile/widgets/patterns/memory_quality_chip.dart';
import 'package:flutter/material.dart';

/// "What Thoughtprint remembers" — one clear, plain-language summary of a pattern
/// the archive has been building over time.
class ThoughtprintmorySummaryCard extends StatefulWidget {
  const ThoughtprintmorySummaryCard({
    required this.summary, super.key,
    this.onOpenPatternMap,
    this.onFindMoments,
    this.onUseCheck,
    this.showEntryLinks = true,
    this.showFeedback = true,
    this.quality,
  });

  final ThoughtprintmorySummary summary;

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
  State<ThoughtprintmorySummaryCard> createState() =>
      _ThoughtprintmorySummaryCardState();
}

class _ThoughtprintmorySummaryCardState extends State<ThoughtprintmorySummaryCard> {
  @override
  void initState() {
    super.initState();
    ActivationTracker.trackThoughtprintmorySummaryShown();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final quality =
        widget.quality ??
        buildMemoryQuality(summary: summary);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ThoughtprintmorySummaryCard._warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThoughtprintmorySummaryCard._warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What Thoughtprint remembers',
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
    ActivationTracker.trackThoughtprintmoryOpenPatternMapTapped();
    widget.onOpenPatternMap?.call();
  }

  void _onFindMoments() {
    ActivationTracker.trackThoughtprintmoryFindMomentsTapped();
    widget.onFindMoments?.call();
  }

  void _onUseCheck() {
    final next = widget.summary.nextCheck?.trim() ?? '';
    if (next.isEmpty) return;
    ActivationTracker.trackThoughtprintmoryUseCheckTapped();
    widget.onUseCheck?.call(next);
  }
}