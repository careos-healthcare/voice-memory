import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_reactivity/archive_change_timeline.dart';
import '../../features/archive_reactivity/archive_change_timeline_metrics_store.dart';
import '../../product/consumer_ui_copy.dart';
import '../../services/app_services.dart';
import '../../theme/archive_loop_theme.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Vertical evidence timeline for how a pattern moves across recordings.
class ArchiveChangeTimelineCard extends StatefulWidget {
  const ArchiveChangeTimelineCard({
    super.key,
    required this.timeline,
    required this.surface,
    this.compact = false,
  });

  final ArchiveChangeTimeline timeline;
  final String surface;
  final bool compact;

  @override
  State<ArchiveChangeTimelineCard> createState() =>
      _ArchiveChangeTimelineCardState();
}

class _ArchiveChangeTimelineCardState extends State<ArchiveChangeTimelineCard> {
  bool _expanded = false;
  bool _showTruthFeedback = false;
  ArchiveTimelineTruthFeedback? _savedFeedback;
  bool _metricsLoaded = false;

  @override
  void initState() {
    super.initState();
    _bootstrapMetrics();
  }

  Future<void> _bootstrapMetrics() async {
    if (!widget.timeline.hasMeaningfulItems) return;
    if (!AppServices.isInitialized) return;
    final store = ArchiveChangeTimelineMetricsStore(AppServices.instance.prefs);
    await store.markTimelineViewed();
    final metrics = await store.load();
    if (!mounted) return;
    setState(() {
      _savedFeedback = metrics.truthFeedback;
      _metricsLoaded = true;
      _showTruthFeedback =
          metrics.timelineExpanded && metrics.truthFeedback == null;
    });
  }

  Future<void> _onExpand() async {
    setState(() => _expanded = true);
    if (!widget.timeline.hasMeaningfulItems) return;
    if (!AppServices.isInitialized) return;
    final store = ArchiveChangeTimelineMetricsStore(AppServices.instance.prefs);
    await store.markTimelineExpanded();
    final metrics = await store.load();
    if (!mounted) return;
    setState(() {
      _savedFeedback = metrics.truthFeedback;
      _showTruthFeedback = metrics.truthFeedback == null;
    });
  }

  Future<void> _submitFeedback(
    ArchiveTimelineTruthFeedback feedback, {
    String? note,
  }) async {
    if (!AppServices.isInitialized) return;
    await ArchiveChangeTimelineMetricsStore(
      AppServices.instance.prefs,
    ).saveTruthFeedback(feedback: feedback, note: note);
    if (!mounted) return;
    setState(() {
      _savedFeedback = feedback;
      _showTruthFeedback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.timeline.shouldDisplay) return const SizedBox.shrink();

    ArchiveChangeTimelineLog.shown(surface: widget.surface);

    final items = widget.timeline.timelineItems;
    final visibleCount = widget.compact && !_expanded ? 3 : items.length;
    final visibleItems = items.take(visibleCount).toList();
    final hasMore = items.length > visibleCount;

    return Container(
      key: Key('archive_change_timeline_card_${widget.surface}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: ArchiveLoopTheme.cardDecoration(
        background: ArchiveLoopTheme.loopCardAlt,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveChangeTimelineCopy.cardTitle,
            key: const Key('archive_change_timeline_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context)
                .copyWith(color: ArchiveLoopTheme.loopTextPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveChangeTimelineCopy.cardSubtitle,
            key: const Key('archive_change_timeline_subtitle'),
            style: VoiceMemoryTypography.metadataStyle(
              color: ArchiveLoopTheme.loopTextSecondary,
            ).copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.timeline.summaryLine,
            key: const Key('archive_change_timeline_summary'),
            style: VoiceMemoryTypography.bodyStyle(
              color: ArchiveLoopTheme.loopTextPrimary,
            ).copyWith(height: 1.45),
          ),
          if (widget.timeline.strongestChange != null && !widget.compact) ...[
            const SizedBox(height: AppSpacing.md),
            _HighlightBlock(
              label: 'Strongest change',
              item: widget.timeline.strongestChange!,
              onRecord: () =>
                  _onRecord(context, widget.timeline.strongestChange!),
            ),
          ],
          if (widget.timeline.helpfulChange != null &&
              widget.timeline.helpfulChange!.id !=
                  widget.timeline.strongestChange?.id) ...[
            const SizedBox(height: AppSpacing.sm),
            _HighlightBlock(
              label: 'Helpful change',
              item: widget.timeline.helpfulChange!,
              onRecord: () =>
                  _onRecord(context, widget.timeline.helpfulChange!),
              accent: ArchiveLoopTheme.loopAccentSoft,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < visibleItems.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _TimelineItemTile(
              item: visibleItems[i],
              isLast: i == visibleItems.length - 1 && !hasMore,
              onRecord: () => _onRecord(context, visibleItems[i]),
            ),
          ],
          if (hasMore) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('archive_change_timeline_expand'),
              onPressed: _onExpand,
              child: Text(
                'Show ${items.length - visibleCount} more',
                style: VoiceMemoryTypography.metadataStyle(
                  color: ArchiveLoopTheme.loopAccentSoft,
                ),
              ),
            ),
          ],
          if (_showTruthFeedback && _metricsLoaded) ...[
            const SizedBox(height: AppSpacing.md),
            _TruthFeedbackPanel(onComplete: _submitFeedback),
          ],
          if (_savedFeedback != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Thanks — ArchiveMe will keep watching this with your feedback.',
              key: const Key('archive_change_timeline_feedback_saved'),
              style: VoiceMemoryTypography.metadataStyle(
                color: ArchiveLoopTheme.loopTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onRecord(
    BuildContext context,
    ArchiveChangeTimelineItem item,
  ) async {
    ArchiveChangeTimelineLog.promptTapped(type: item.type);
    if (AppServices.isInitialized) {
      await ArchiveChangeTimelineMetricsStore(
        AppServices.instance.prefs,
      ).incrementPromptTap();
    }
    if (!context.mounted) return;
    context.go(ArchiveChangeTimelineResolver.recordRouteFor(item));
  }
}

typedef _TruthFeedbackComplete = Future<void> Function(
  ArchiveTimelineTruthFeedback feedback, {
  String? note,
});

class _TruthFeedbackPanel extends StatefulWidget {
  const _TruthFeedbackPanel({required this.onComplete});

  final _TruthFeedbackComplete onComplete;

  @override
  State<_TruthFeedbackPanel> createState() => _TruthFeedbackPanelState();
}

class _TruthFeedbackPanelState extends State<_TruthFeedbackPanel> {
  ArchiveTimelineTruthFeedback? _pendingFeedback;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _finish({
    required ArchiveTimelineTruthFeedback feedback,
    String? note,
  }) async {
    await widget.onComplete(feedback, note: note);
    if (!mounted) return;
    setState(() {
      _pendingFeedback = null;
      _noteController.clear();
    });
  }

  void _onRatingSelected(ArchiveTimelineTruthFeedback feedback) {
    if (feedback == ArchiveTimelineTruthFeedback.yes) {
      _finish(feedback: feedback);
      return;
    }
    setState(() => _pendingFeedback = feedback);
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingFeedback != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.checkInResultNotUsefulFollowUp,
            key: const Key('archive_change_timeline_truth_follow_up'),
            style: VoiceMemoryTypography.bodyStyle(
              color: ArchiveLoopTheme.loopTextPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('archive_change_timeline_truth_note'),
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Optional — a line is enough',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            style: VoiceMemoryTypography.bodyStyle(
              color: ArchiveLoopTheme.loopTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                key: const Key('archive_change_timeline_truth_submit'),
                onPressed: () => _finish(
                  feedback: _pendingFeedback!,
                  note: _noteController.text,
                ),
                style: ArchiveLoopTheme.secondaryCtaStyle(context),
                child: const Text('Save feedback'),
              ),
              TextButton(
                key: const Key('archive_change_timeline_truth_skip'),
                onPressed: () => _finish(feedback: _pendingFeedback!),
                child: Text(
                  'Skip',
                  style: VoiceMemoryTypography.metadataStyle(
                    color: ArchiveLoopTheme.loopTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Did this feel true?',
          key: const Key('archive_change_timeline_truth_question'),
          style: VoiceMemoryTypography.bodyStyle(
            color: ArchiveLoopTheme.loopTextPrimary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _FeedbackChip(
              key: const Key('archive_change_timeline_truth_yes'),
              label: 'Yes',
              onTap: () => _onRatingSelected(ArchiveTimelineTruthFeedback.yes),
            ),
            _FeedbackChip(
              key: const Key('archive_change_timeline_truth_partly'),
              label: 'Partly',
              onTap: () =>
                  _onRatingSelected(ArchiveTimelineTruthFeedback.partly),
            ),
            _FeedbackChip(
              key: const Key('archive_change_timeline_truth_not_really'),
              label: 'Not really',
              onTap: () =>
                  _onRatingSelected(ArchiveTimelineTruthFeedback.notReally),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: ArchiveLoopTheme.secondaryCtaStyle(context),
      child: Text(label),
    );
  }
}

class _HighlightBlock extends StatelessWidget {
  const _HighlightBlock({
    required this.label,
    required this.item,
    required this.onRecord,
    this.accent,
  });

  final String label;
  final ArchiveChangeTimelineItem item;
  final VoidCallback onRecord;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: ArchiveLoopTheme.cardDecoration(
        background: ArchiveLoopTheme.loopCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: VoiceMemoryTypography.metadataStyle(
              color: accent ?? ArchiveLoopTheme.loopTextSecondary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          _TimelineItemTile(item: item, onRecord: onRecord, dense: true),
        ],
      ),
    );
  }
}

class _TimelineItemTile extends StatelessWidget {
  const _TimelineItemTile({
    required this.item,
    required this.onRecord,
    this.dense = false,
    this.isLast = true,
  });

  final ArchiveChangeTimelineItem item;
  final VoidCallback onRecord;
  final bool dense;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineRail(isLast: isLast),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusChip(type: item.type),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.title,
                style: VoiceMemoryTypography.bodyStyle(
                  color: ArchiveLoopTheme.loopTextPrimary,
                ).copyWith(fontWeight: FontWeight.w600, height: 1.35),
              ),
              if (!dense) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.evidenceLine,
                  style: VoiceMemoryTypography.metadataStyle(
                    color: ArchiveLoopTheme.loopTextSecondary,
                  ).copyWith(height: 1.4),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.changeLine,
                  style: VoiceMemoryTypography.bodyStyle(
                    color: ArchiveLoopTheme.loopTextPrimary,
                  ).copyWith(height: 1.4),
                ),
              ],
              if (item.hasRecordPrompt) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: Key('archive_change_timeline_record_${item.id}'),
                    onPressed: onRecord,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      ArchiveChangeTimelineCopy.recordThisNextCta,
                      style: VoiceMemoryTypography.metadataStyle(
                        color: ArchiveLoopTheme.loopAccentSoft,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({required this.isLast});

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: ArchiveLoopTheme.loopAccentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: ArchiveLoopTheme.loopAccentSoft),
            ),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: denseHeight(context),
              color: ArchiveLoopTheme.loopAccentSoft,
            ),
        ],
      ),
    );
  }

  double denseHeight(BuildContext context) => 48;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.type});

  final ArchiveChangeTimelineItemType type;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      ArchiveChangeTimelineItemType.loopFirstSeen => 'First seen',
      ArchiveChangeTimelineItemType.loopRepeated => 'Repeated',
      ArchiveChangeTimelineItemType.urgencyIncreased => 'Louder',
      ArchiveChangeTimelineItemType.urgencySoftened => 'Softer',
      ArchiveChangeTimelineItemType.triggerRepeated => 'Repeated',
      ArchiveChangeTimelineItemType.helpfulActionAppeared => 'Helped',
      ArchiveChangeTimelineItemType.experimentStarted => 'Tested',
      ArchiveChangeTimelineItemType.experimentHelped => 'Helped',
      ArchiveChangeTimelineItemType.experimentPartlyHelped => 'Tested',
      ArchiveChangeTimelineItemType.experimentDidNotHelp => 'Tested',
      ArchiveChangeTimelineItemType.loopShifted => 'Shifted',
      ArchiveChangeTimelineItemType.unclearSignal => 'Watching',
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: ArchiveLoopTheme.loopAccentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: VoiceMemoryTypography.metadataStyle(
          color: ArchiveLoopTheme.loopTextSecondary,
        ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}
