import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pattern_lifecycle/pattern_lifecycle_analytics.dart';
import 'package:archiveme_mobile/features/pattern_lifecycle/pattern_lifecycle_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// Compact lifecycle row — label chip + one helper sentence.
class PatternLifecycleBadge extends StatefulWidget {
  const PatternLifecycleBadge({
    required this.lifecycle,
    required this.entryCount,
    required this.source,
    super.key,
    this.showBody = true,
    this.compact = true,
    this.skipAnalytics = false,
    this.onViewEvidence,
  });

  final PatternLifecycle lifecycle;
  final int entryCount;
  final String source;
  final bool showBody;
  final bool compact;
  final bool skipAnalytics;
  final VoidCallback? onViewEvidence;

  @override
  State<PatternLifecycleBadge> createState() => _PatternLifecycleBadgeState();
}

class _PatternLifecycleBadgeState extends State<PatternLifecycleBadge> {
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _trackSeen();
  }

  void _trackSeen() {
    if (widget.skipAnalytics || _tracked) return;
    _tracked = true;
    PatternLifecycleAnalytics.seen(
      source: widget.source,
      entryCount: widget.entryCount,
      lifecycleState: widget.lifecycle.state.analyticsValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lifecycle.shouldShow) return const SizedBox.shrink();

    final chipStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      fontSize: widget.compact ? 12 : 13,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 12, height: 1.35);

    return Column(
      key: Key('pattern_lifecycle_badge_${widget.lifecycle.state.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              key: Key('pattern_lifecycle_chip_${widget.lifecycle.state.name}'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                widget.lifecycle.lifecycleRowLabel,
                key: Key(
                  'pattern_lifecycle_label_${widget.lifecycle.state.name}',
                ),
                style: chipStyle,
              ),
            ),
            if (widget.onViewEvidence != null ||
                widget.lifecycle.contributingEntryIds.isNotEmpty)
              ViewEvidenceInlineLink(
                key: const Key('pattern_lifecycle_view_evidence'),
                entryIds: widget.lifecycle.contributingEntryIds,
                surface: 'pattern_lifecycle',
                onViewEvidence: widget.onViewEvidence,
              ),
          ],
        ),
        if (widget.showBody) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.lifecycle.body,
            key: Key('pattern_lifecycle_body_${widget.lifecycle.state.name}'),
            style: bodyStyle,
          ),
        ],
      ],
    );
  }
}
