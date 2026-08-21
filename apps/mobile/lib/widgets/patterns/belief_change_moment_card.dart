import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_analytics.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/belief_changes/ui/belief_change_pattern_card.dart';
import 'package:archiveme_mobile/features/pro_packaging/pro_value_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/common/contextual_privacy_reassurance.dart';
import 'package:archiveme_mobile/widgets/common/pro_packaging_bridge_line.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_change_timeline_card.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Emotional payoff when a repeat pattern may be softening — evidence only.
class BeliefChangeMomentCard extends StatefulWidget {
  const BeliefChangeMomentCard({
    required this.moment,
    required this.entryCount,
    required this.source,
    super.key,
    this.compact = false,
    this.showPrivacyReassurance = true,
    this.showProPackagingBridge = true,
  });

  final BeliefChangeMoment moment;
  final int entryCount;
  final String source;
  final bool compact;
  final bool showPrivacyReassurance;
  final bool showProPackagingBridge;

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
    unawaited(
      ArchiveChangeTimelineCard.showSheet(
        context,
        timeline: timeline,
        entryCount: widget.entryCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    return BeliefChangePatternCard(
      key: const Key('belief_change_moment_card'),
      moment: widget.moment,
      compact: widget.compact,
      footer: widget.showProPackagingBridge || widget.showPrivacyReassurance
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.moment.canViewChangeTimeline) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('belief_change_moment_timeline_cta'),
                      onPressed: _openChangeTimeline,
                      child: const Text(
                        BeliefChangeMomentCopy.viewChangeTimelineCta,
                      ),
                    ),
                  ),
                ],
                if (widget.showProPackagingBridge) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const ProPackagingBridgeLine(
                    line: ProPackagingCopy.bridgeAfterBeliefChange,
                    lineKey: Key('pro_packaging_bridge_belief_change'),
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
            )
          : null,
    );
  }
}
