import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/archive_insight_feedback.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Compact local feedback row for archive belief/review insight cards.
class ArchiveInsightFeedbackControls extends StatefulWidget {
  const ArchiveInsightFeedbackControls({
    super.key,
    required this.insightId,
    this.onHidden,
  });

  final String insightId;
  final VoidCallback? onHidden;

  @override
  State<ArchiveInsightFeedbackControls> createState() =>
      _ArchiveInsightFeedbackControlsState();
}

class _ArchiveInsightFeedbackControlsState
    extends State<ArchiveInsightFeedbackControls> {
  bool _whyExpanded = false;

  Future<void> _record(ArchiveInsightFeedbackChoice choice) async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    ArchiveInsightFeedbackStore.record(widget.insightId, choice);
    if (mounted) setState(() {});
  }

  Future<void> _hide() async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    ArchiveInsightFeedbackStore.hide(widget.insightId);
    widget.onHidden?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final chipStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.accentPrimary,
      fontWeight: FontWeight.w600,
    );
    final explainStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return Column(
      key: const Key('archive_insight_feedback_controls'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              key: const Key('archive_insight_feedback_feels_right'),
              onPressed: () => _record(ArchiveInsightFeedbackChoice.feelsRight),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                ArchiveInsightFeedbackCopy.feelsRight,
                style: chipStyle,
              ),
            ),
            TextButton(
              key: const Key('archive_insight_feedback_not_quite'),
              onPressed: () => _record(ArchiveInsightFeedbackChoice.notQuite),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                ArchiveInsightFeedbackCopy.notQuite,
                style: chipStyle,
              ),
            ),
            TextButton(
              key: const Key('archive_insight_feedback_hide'),
              onPressed: _hide,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                ArchiveInsightFeedbackCopy.hideThis,
                style: chipStyle,
              ),
            ),
            TextButton(
              key: const Key('archive_insight_feedback_why'),
              onPressed: () => setState(() => _whyExpanded = !_whyExpanded),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                ArchiveInsightFeedbackCopy.whySeeing,
                style: chipStyle,
              ),
            ),
          ],
        ),
        if (_whyExpanded) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveInsightFeedbackCopy.whySource,
            key: const Key('archive_insight_feedback_why_source'),
            style: explainStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveInsightFeedbackCopy.whyNotConclusion,
            key: const Key('archive_insight_feedback_why_not_conclusion'),
            style: explainStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveInsightFeedbackCopy.whyHide,
            key: const Key('archive_insight_feedback_why_hide'),
            style: explainStyle,
          ),
        ],
      ],
    );
  }
}

/// Hides [child] locally when the user dismisses an insight card.
class ArchiveInsightFeedbackHost extends StatefulWidget {
  const ArchiveInsightFeedbackHost({
    super.key,
    required this.insightId,
    required this.showControls,
    required this.child,
  });

  final String insightId;
  final bool showControls;
  final Widget child;

  @override
  State<ArchiveInsightFeedbackHost> createState() =>
      _ArchiveInsightFeedbackHostState();
}

class _ArchiveInsightFeedbackHostState extends State<ArchiveInsightFeedbackHost> {
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    _hidden = ArchiveInsightFeedbackStore.isHidden(widget.insightId);
    _refreshHidden();
  }

  Future<void> _refreshHidden() async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    if (!mounted) return;
    final hidden = ArchiveInsightFeedbackStore.isHidden(widget.insightId);
    if (hidden != _hidden) {
      setState(() => _hidden = hidden);
    }
  }

  void _onHidden() {
    setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) {
      return SizedBox.shrink(
        key: Key('archive_insight_feedback_hidden_${widget.insightId}'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.child,
        if (widget.showControls)
          ArchiveInsightFeedbackControls(
            insightId: widget.insightId,
            onHidden: _onHidden,
          ),
      ],
    );
  }
}
