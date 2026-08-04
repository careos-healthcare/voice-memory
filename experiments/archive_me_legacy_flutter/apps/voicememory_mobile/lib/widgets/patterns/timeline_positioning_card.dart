import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/timeline_positioning/timeline_positioning_analytics.dart';
import '../../features/timeline_positioning/timeline_positioning_copy.dart';
import '../../features/timeline_positioning/timeline_positioning_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Positions ArchiveMe as a timeline, not a chat — no subscription CTA.
class TimelinePositioningCard extends StatefulWidget {
  const TimelinePositioningCard({
    super.key,
    required this.result,
    required this.source,
    this.compact = false,
  });

  const TimelinePositioningCard.test({
    super.key,
    required this.result,
    required this.source,
    this.compact = false,
  });

  final TimelinePositioningResult result;
  final String source;
  final bool compact;

  @override
  State<TimelinePositioningCard> createState() =>
      _TimelinePositioningCardState();
}

class _TimelinePositioningCardState extends State<TimelinePositioningCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    TimelinePositioningAnalytics.seen(
      source: widget.source,
      result: widget.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final bulletStyle = bodyStyle.copyWith(color: AppColors.textPrimary);

    return Container(
      key: const Key('timeline_positioning_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('timeline_positioning_title'),
            style: widget.compact
                ? ArchiveMobileTypography.cardLabel(context).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  )
                : ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('timeline_positioning_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.result.differentiationLine,
            key: const Key('timeline_positioning_differentiation_line'),
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Timeline',
            key: const Key('timeline_positioning_bullets_heading'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final bullet in widget.result.timelineBullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: bulletStyle),
                  Expanded(
                    child: Text(
                      bullet,
                      key: Key(TimelinePositioningCopy.bulletKey(bullet)),
                      style: bulletStyle,
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.result.proBridgeLine,
              key: const Key('timeline_positioning_pro_bridge_line'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}
