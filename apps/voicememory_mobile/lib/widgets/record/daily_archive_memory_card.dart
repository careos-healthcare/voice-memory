import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/empty_archive_experience.dart';
import '../../features/come_back_tomorrow/come_back_tomorrow_v2_copy.dart';
import '../../features/daily_archive_memory/daily_archive_memory_analytics.dart';
import '../../features/daily_archive_memory/daily_archive_memory_copy.dart';
import '../../features/daily_archive_memory/daily_archive_memory_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Quiet returning-user memory card on Record ready.
class DailyArchiveMemoryCard extends StatefulWidget {
  const DailyArchiveMemoryCard({
    super.key,
    required this.memory,
    required this.entryCount,
    required this.source,
    this.onRecord,
    this.onTypeInstead,
    this.onNotToday,
    this.onViewPatternDetails,
    this.showFocusedCaptureActions = false,
  });

  final DailyArchiveMemoryResult memory;
  final int entryCount;
  final String source;
  final VoidCallback? onRecord;
  final VoidCallback? onTypeInstead;
  final VoidCallback? onNotToday;
  final VoidCallback? onViewPatternDetails;

  /// Primary voice/type/not-today actions on the card for watch-target returns.
  final bool showFocusedCaptureActions;

  @override
  State<DailyArchiveMemoryCard> createState() => _DailyArchiveMemoryCardState();
}

class _DailyArchiveMemoryCardState extends State<DailyArchiveMemoryCard> {
  bool _seenTracked = false;
  var _dismissedToday = false;

  @override
  void initState() {
    super.initState();
    _trackSeen();
  }

  void _trackSeen() {
    if (_seenTracked) return;
    _seenTracked = true;
    DailyArchiveMemoryAnalytics.seen(
      source: widget.source,
      entryCount: widget.entryCount,
      hasWatchTarget: widget.memory.hasWatchTarget,
    );
  }

  void _onRecord() {
    DailyArchiveMemoryAnalytics.ctaTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: 'record_what_happened',
    );
    widget.onRecord?.call();
  }

  void _onTypeInstead() {
    DailyArchiveMemoryAnalytics.ctaTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: 'type_instead',
    );
    widget.onTypeInstead?.call();
  }

  void _onNotToday() {
    DailyArchiveMemoryAnalytics.ctaTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: 'not_today',
    );
    widget.onNotToday?.call();
    if (!mounted) return;
    setState(() => _dismissedToday = true);
  }

  void _onViewPatternDetails() {
    DailyArchiveMemoryAnalytics.ctaTapped(
      source: widget.source,
      entryCount: widget.entryCount,
      actionType: 'view_pattern_details',
    );
    widget.onViewPatternDetails?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedToday) return const SizedBox.shrink();

    final titleStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);
    final phraseStyle = bodyStyle.copyWith(
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
    );
    final actionStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.accentPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    final focused = widget.showFocusedCaptureActions && widget.memory.hasWatchTarget;

    return Container(
      key: const Key('daily_archive_memory_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF7F8FA)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.memory.title,
            key: const Key('daily_archive_memory_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.memory.body,
            key: const Key('daily_archive_memory_body'),
            style: secondaryStyle,
          ),
          if (widget.memory.watchPhrase != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              DailyArchiveMemoryCopy.quotedWatchPhrase(
                widget.memory.watchPhrase!,
              ),
              key: const Key('daily_archive_memory_watch_phrase'),
              style: phraseStyle,
            ),
          ],
          if (widget.memory.footer != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.memory.footer!,
              key: const Key('daily_archive_memory_footer'),
              style: secondaryStyle,
            ),
          ],
          if (focused && widget.onRecord != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('daily_archive_memory_record_cta'),
              onPressed: _onRecord,
              child: Text(DailyArchiveMemoryCopy.recordCta),
            ),
          ],
          if (focused && widget.onTypeInstead != null) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('daily_archive_memory_type_instead_cta'),
              onPressed: _onTypeInstead,
              child: Text(EmptyArchiveCopy.typeInsteadCta),
            ),
          ],
          if (focused && widget.onNotToday != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('daily_archive_memory_not_today_cta'),
              onPressed: _onNotToday,
              child: Text(ComeBackTomorrowV2Copy.notToday),
            ),
          ],
          if (!focused && widget.onRecord != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('daily_archive_memory_record_cta'),
                onPressed: _onRecord,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  DailyArchiveMemoryCopy.recordCta,
                  style: actionStyle,
                ),
              ),
            ),
          ],
          if (!focused &&
              widget.memory.canShowPatternDetail &&
              widget.onViewPatternDetails != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('daily_archive_memory_pattern_details_cta'),
                onPressed: _onViewPatternDetails,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  DailyArchiveMemoryCopy.viewPatternDetailsCta,
                  style: actionStyle.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
