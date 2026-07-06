import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/belief_change/belief_change_moment_analytics.dart';
import '../../features/belief_change/belief_change_moment_copy.dart';
import '../../features/belief_change/belief_change_moment_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../common/contextual_privacy_reassurance.dart';
import 'archive_change_timeline_card.dart';

/// Emotional payoff when a repeat pattern may be softening — evidence only.
class BeliefChangeMomentCard extends StatefulWidget {
  const BeliefChangeMomentCard({
    super.key,
    required this.moment,
    required this.entryCount,
    required this.source,
    this.compact = false,
    this.showPrivacyReassurance = true,
  });

  final BeliefChangeMoment moment;
  final int entryCount;
  final String source;
  final bool compact;
  final bool showPrivacyReassurance;

  @override
  State<BeliefChangeMomentCard> createState() => _BeliefChangeMomentCardState();
}

class _BeliefChangeMomentCardState extends State<BeliefChangeMomentCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    BeliefChangeMomentAnalytics.seen(
      source: widget.source,
      entryCount: widget.entryCount,
      changeType: widget.moment.changeType,
    );
  }

  void _openChangeTimeline() {
    final timeline = widget.moment.timeline;
    if (timeline == null) return;
    ArchiveChangeTimelineCard.showSheet(
      context,
      timeline: timeline,
      entryCount: widget.entryCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();
    final moment = widget.moment;
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final labelStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      color: AppColors.textSecondary,
    );
    final exampleStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
    );
    final snippetStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.35,
    );

    return Container(
      key: const Key('belief_change_moment_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF4FAF7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            BeliefChangeMomentCopy.title,
            key: const Key('belief_change_moment_title'),
            style: titleStyle,
          ),
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              BeliefChangeMomentCopy.body,
              key: const Key('belief_change_moment_body'),
              style: bodyStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefChangeMomentCopy.beliefLine,
            key: const Key('belief_change_moment_belief_line'),
            style: labelStyle,
          ),
          const SizedBox(height: 2),
          Text(
            '"${moment.earlierBeliefExample}"',
            key: const Key('belief_change_moment_belief_example'),
            style: exampleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefChangeMomentCopy.changeLine,
            key: const Key('belief_change_moment_change_line'),
            style: labelStyle,
          ),
          const SizedBox(height: 2),
          Text(
            '"${moment.changeExample}"',
            key: const Key('belief_change_moment_change_example'),
            style: exampleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefChangeMomentCopy.evidenceHeading,
            key: const Key('belief_change_moment_evidence_heading'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${moment.earlierSnippet.label} "${moment.earlierSnippet.quote}"',
            key: const Key('belief_change_moment_earlier_snippet'),
            style: snippetStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${moment.laterSnippet.label} "${moment.laterSnippet.quote}"',
            key: const Key('belief_change_moment_later_snippet'),
            style: snippetStyle,
          ),
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              BeliefChangeMomentCopy.footer,
              key: const Key('belief_change_moment_footer'),
              style: bodyStyle,
            ),
          ],
          if (moment.canViewChangeTimeline) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('belief_change_moment_timeline_cta'),
                onPressed: _openChangeTimeline,
                child: const Text(BeliefChangeMomentCopy.viewChangeTimelineCta),
              ),
            ),
          ],
          if (widget.showPrivacyReassurance) ...[
            const SizedBox(height: AppSpacing.sm),
            ContextualPrivacyReassurance(
              source: widget.source,
              entryCount: widget.entryCount,
            ),
          ],
        ],
      ),
    );
  }
}
