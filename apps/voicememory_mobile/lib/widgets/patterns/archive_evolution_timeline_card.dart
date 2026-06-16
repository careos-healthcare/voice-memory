import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../features/archive_memory/archive_evolution_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Compact preview of how one pattern has changed over time.
class ArchiveEvolutionTimelineCard extends StatefulWidget {
  const ArchiveEvolutionTimelineCard({
    super.key,
    required this.timeline,
    this.onOpenTimeline,
    this.onUseCheck,
    this.showOpenTimeline = true,
  });

  final ArchiveEvolutionTimeline timeline;
  final VoidCallback? onOpenTimeline;

  /// Creates tomorrow's check-in from [nextCheck].
  final void Function(String nextCheck)? onUseCheck;

  /// When false, hides the open-timeline link (archive clean view handles it).
  final bool showOpenTimeline;

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = Color(0xFFF5E6D3);

  @override
  State<ArchiveEvolutionTimelineCard> createState() =>
      _ArchiveEvolutionTimelineCardState();
}

class _ArchiveEvolutionTimelineCardState
    extends State<ArchiveEvolutionTimelineCard> {
  bool _checkSet = false;

  @override
  void initState() {
    super.initState();
    ActivationTracker.trackArchiveTimelineShown();
  }

  void _openTimeline() {
    ActivationTracker.trackArchiveTimelineOpened();
    widget.onOpenTimeline?.call();
  }

  void _useCheck(String nextCheck) {
    ActivationTracker.trackArchiveTimelineUseCheckTapped();
    widget.onUseCheck?.call(nextCheck);
    setState(() => _checkSet = true);
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.timeline.events.take(4).toList();
    final hasNextCheck = widget.timeline.hasNextCheck;
    return Container(
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
          if (widget.showOpenTimeline)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _openTimeline,
                child: const Text('Open timeline'),
              ),
            ),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
