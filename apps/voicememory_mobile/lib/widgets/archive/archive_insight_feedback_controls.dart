import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/archive_insight_feedback.dart';
import '../../features/activation/archive_insight_feedback_adaptation.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Compact local feedback row for archive belief/review insight cards.
class ArchiveInsightFeedbackControls extends StatefulWidget {
  const ArchiveInsightFeedbackControls({
    super.key,
    required this.insightId,
    this.onHidden,
    this.onFeedbackChanged,
  });

  final String insightId;
  final VoidCallback? onHidden;
  final VoidCallback? onFeedbackChanged;

  @override
  State<ArchiveInsightFeedbackControls> createState() =>
      _ArchiveInsightFeedbackControlsState();
}

class _ArchiveInsightFeedbackControlsState
    extends State<ArchiveInsightFeedbackControls> {
  bool _whyExpanded = false;
  bool _showFeelsRightConfirmation = false;
  bool _showCorrectionEditor = false;
  late final TextEditingController _correctionController;

  @override
  void initState() {
    super.initState();
    _correctionController = TextEditingController(
      text: ArchiveInsightFeedbackStore.correctionNote(widget.insightId) ?? '',
    );
  }

  @override
  void dispose() {
    _correctionController.dispose();
    super.dispose();
  }

  Future<void> _record(ArchiveInsightFeedbackChoice choice) async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    ArchiveInsightFeedbackStore.record(widget.insightId, choice);
    if (choice == ArchiveInsightFeedbackChoice.feelsRight) {
      _showFeelsRightConfirmation = true;
      _showCorrectionEditor = false;
    }
    if (choice == ArchiveInsightFeedbackChoice.notQuite) {
      _showFeelsRightConfirmation = false;
      _showCorrectionEditor = true;
      _correctionController.text =
          ArchiveInsightFeedbackStore.correctionNote(widget.insightId) ?? '';
    }
    widget.onFeedbackChanged?.call();
    if (mounted) setState(() {});
  }

  Future<void> _saveCorrectionNote() async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    final saved = ArchiveInsightFeedbackStore.saveCorrectionNote(
      widget.insightId,
      _correctionController.text,
    );
    if (!saved) return;
    _showCorrectionEditor = false;
    widget.onFeedbackChanged?.call();
    if (mounted) setState(() {});
  }

  void _skipCorrectionNote() {
    _showCorrectionEditor = false;
    if (mounted) setState(() {});
  }

  Future<void> _hide() async {
    await ArchiveInsightFeedbackStore.ensureLoaded();
    ArchiveInsightFeedbackStore.hide(widget.insightId);
    widget.onHidden?.call();
    widget.onFeedbackChanged?.call();
    if (mounted) setState(() {});
  }

  Widget _buildCorrectionContext(TextStyle explainStyle) {
    if (!ArchiveInsightFeedbackStore.hasCorrectionNote(widget.insightId)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        Text(
          ArchiveInsightFeedbackCopy.correctionMarkedNotQuite,
          key: const Key('archive_insight_feedback_correction_marked'),
          style: explainStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ArchiveInsightFeedbackAdaptation.correctionNoteLineFor(
            widget.insightId,
          ),
          key: const Key('archive_insight_feedback_correction_saved_note'),
          style: explainStyle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chipStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.accentPrimary, fontWeight: FontWeight.w600);
    final explainStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

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
        if (_showCorrectionEditor) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            ArchiveInsightFeedbackCopy.correctionAffordance,
            key: const Key('archive_insight_feedback_correction_affordance'),
            style: explainStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: const Key('archive_insight_feedback_correction_field'),
            controller: _correctionController,
            maxLength: ArchiveInsightFeedbackStore.maxCorrectionNoteLength,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: ArchiveInsightFeedbackCopy.correctionPlaceholder,
              isDense: true,
              counterText: '',
            ),
            style: explainStyle.copyWith(color: AppColors.textPrimary),
          ),
          Row(
            children: [
              TextButton(
                key: const Key('archive_insight_feedback_correction_save'),
                onPressed: _saveCorrectionNote,
                child: Text(
                  ArchiveInsightFeedbackCopy.correctionSaveCta,
                  style: chipStyle,
                ),
              ),
              TextButton(
                key: const Key('archive_insight_feedback_correction_skip'),
                onPressed: _skipCorrectionNote,
                child: Text(
                  ArchiveInsightFeedbackCopy.correctionSkipCta,
                  style: chipStyle,
                ),
              ),
            ],
          ),
        ],
        if (!_showCorrectionEditor) _buildCorrectionContext(explainStyle),
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
          if (ArchiveInsightFeedbackStore.hasCorrectionNote(
            widget.insightId,
          )) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              ArchiveInsightFeedbackCopy.correctionMarkedNotQuite,
              key: const Key('archive_insight_feedback_why_correction_marked'),
              style: explainStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ArchiveInsightFeedbackAdaptation.correctionNoteLineFor(
                widget.insightId,
              ),
              key: const Key('archive_insight_feedback_why_correction_note'),
              style: explainStyle,
            ),
          ],
        ],
        if (_showFeelsRightConfirmation) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveInsightFeedbackAdaptationCopy.savedUsefulFeedback,
            key: const Key('archive_insight_feedback_feels_right_confirmation'),
            style: explainStyle,
          ),
        ],
      ],
    );
  }
}

/// Hides [childBuilder] output locally when the user dismisses an insight card.
class ArchiveInsightFeedbackHost extends StatefulWidget {
  const ArchiveInsightFeedbackHost({
    super.key,
    required this.insightId,
    required this.showControls,
    required this.childBuilder,
  });

  final String insightId;
  final bool showControls;
  final WidgetBuilder childBuilder;

  @override
  State<ArchiveInsightFeedbackHost> createState() =>
      _ArchiveInsightFeedbackHostState();
}

class _ArchiveInsightFeedbackHostState
    extends State<ArchiveInsightFeedbackHost> {
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
        widget.childBuilder(context),
        if (widget.showControls)
          ArchiveInsightFeedbackControls(
            insightId: widget.insightId,
            onHidden: _onHidden,
            onFeedbackChanged: () => setState(() {}),
          ),
      ],
    );
  }
}
