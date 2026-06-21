import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/archive_memory/archive_evolution_model.dart';
import '../../features/archive_proof/archive_change_timeline_metrics_store.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';
import 'archive_timeline_truth_feedback_card.dart';

/// Compact preview of how one pattern has changed over time.
class ArchiveEvolutionTimelineCard extends StatefulWidget {
  const ArchiveEvolutionTimelineCard({
    super.key,
    required this.timeline,
    this.onOpenTimeline,
    this.onUseCheck,
    this.showOpenTimeline = true,
    this.metricsStore,
    this.showTruthFeedback = true,
  });

  final ArchiveEvolutionTimeline timeline;
  final VoidCallback? onOpenTimeline;

  /// Creates tomorrow's check-in from [nextCheck].
  final void Function(String nextCheck)? onUseCheck;

  /// When false, hides the open-timeline link (archive clean view handles it).
  final bool showOpenTimeline;

  final ArchiveChangeTimelineMetricsStore? metricsStore;

  /// Beta truth question after the user expands or opens the timeline.
  final bool showTruthFeedback;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  State<ArchiveEvolutionTimelineCard> createState() =>
      _ArchiveEvolutionTimelineCardState();
}

class _ArchiveEvolutionTimelineCardState
    extends State<ArchiveEvolutionTimelineCard> {
  bool _checkSet = false;
  bool _expanded = false;
  bool _showFeedback = false;
  bool _feedbackAnswered = false;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveTimelineShown();
    widget.metricsStore?.markTimelineViewed();
  }

  Future<void> _engageTimeline({required bool expanded}) async {
    if (expanded) {
      await widget.metricsStore?.markTimelineExpanded();
    }
    if (!mounted) return;
    setState(() {
      _expanded = expanded || _expanded;
      _showFeedback =
          widget.showTruthFeedback && widget.metricsStore != null && expanded;
    });
  }

  void _openTimeline() {
    ActivationTracker.trackArchiveTimelineOpened();
    unawaited(_engageTimeline(expanded: true));
    widget.onOpenTimeline?.call();
  }

  Future<void> _expandInline() async {
    await _engageTimeline(expanded: true);
  }

  void _useCheck(String nextCheck) {
    ActivationTracker.trackArchiveTimelineUseCheckTapped();
    widget.onUseCheck?.call(nextCheck);
    setState(() => _checkSet = true);
  }

  @override
  Widget build(BuildContext context) {
    final previewCount = _expanded ? widget.timeline.events.length : 4;
    final preview = widget.timeline.events.take(previewCount).toList();
    final hasNextCheck = widget.timeline.hasNextCheck;
    return Container(
      key: const Key('archive_evolution_timeline_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ArchiveEvolutionTimelineCard._warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArchiveEvolutionTimelineCard._warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pattern timeline',
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ConsumerUiCopy.archiveTimelineSubtitle,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final event in preview) ...[
            _eventRow(event),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (!_expanded && widget.timeline.events.length > 4) ...[
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('archive_timeline_expand_inline'),
                onPressed: _expandInline,
                child: const Text('See how this changed'),
              ),
            ),
          ],
          if (widget.showOpenTimeline)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('archive_timeline_open_full'),
                onPressed: _openTimeline,
                child: const Text('Open timeline'),
              ),
            ),
          if (_showFeedback && !_feedbackAnswered) ...[
            const SizedBox(height: AppSpacing.sm),
            ArchiveTimelineTruthFeedbackCard(
              store: widget.metricsStore!,
              onAnswered: () => setState(() => _feedbackAnswered = true),
            ),
          ],
          if (hasNextCheck && widget.onUseCheck != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _checkSet
                    ? null
                    : () => _useCheck(widget.timeline.nextCheck!.trim()),
                child: Text(
                  _checkSet
                      ? ConsumerUiCopy.resultNextCheckConfirmation
                      : 'Use this check',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _eventRow(ArchiveEvolutionEvent event) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            _dateLabel(event.date),
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                event.body,
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 13, height: 1.35),
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
