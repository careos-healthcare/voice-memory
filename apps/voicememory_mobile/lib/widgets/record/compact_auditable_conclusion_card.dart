import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/explainable_conclusion/explainable_conclusion.dart';
import '../../features/explainable_conclusion/explainable_conclusion_validator.dart';
import '../../features/explainable_conclusion/explainable_conclusion_widgets.dart';
import '../../features/insight_feedback/explainable_conclusion_feedback_coordinator.dart';
import '../../features/insight_feedback/insight_feedback_models.dart';
import '../../features/monetization/data/product_value_delivery_recorder.dart';
import '../../features/monetization/domain/product_value_delivery_ledger.dart';
import '../../features/structured_markers/structured_markers.dart';
import '../../services/evidence_receipt_analytics.dart';
import '../../services/product_analytics.dart';
import '../../theme/app_spacing.dart';
import 'post_save_conclusion_view.dart';
import 'post_save_evidence_detail_sheet.dart';

/// The default post-save result: one label, one sentence, one quote, one full
/// date, one evidence count, the correction controls and one primary action.
///
/// It is collapsed after every save. There is no confidence percentage — trust
/// is reported as a band, because a number implies a precision two moments
/// cannot support. Every remaining detail, including which dimensions moved, is
/// reachable only through the single "Check all evidence" action, and that
/// expansion is never written to storage.
class CompactAuditableConclusionCard extends StatefulWidget {
  const CompactAuditableConclusionCard({
    super.key,
    required this.conclusion,
    this.onEvidenceSelected,
    this.onAudioEvidenceSelected,
    this.onFeedbackSubmitted,
    this.nextQuestion,
    this.onRecordNext,
    this.markers = const {},
    this.analyticsOrigin = 'record_post_save',
  });

  final ValidatedExplainableConclusion conclusion;
  final ExplainableEvidenceNavigation? onEvidenceSelected;
  final ExplainableEvidenceNavigation? onAudioEvidenceSelected;
  final ExplainableFeedbackSubmission? onFeedbackSubmitted;
  final String? nextQuestion;
  final ValueChanged<String?>? onRecordNext;

  /// Optional ten-second-check markers, keyed by entry id. Secondary evidence:
  /// they are only read in the expanded state, and only for dimensions the
  /// cited words cannot compare.
  final Map<String, StructuredMarkers> markers;

  final String analyticsOrigin;

  @override
  State<CompactAuditableConclusionCard> createState() =>
      _CompactAuditableConclusionCardState();
}

class _CompactAuditableConclusionCardState
    extends State<CompactAuditableConclusionCard> {
  bool _hidden = false;
  bool _busy = false;
  InsightFeedbackChoice? _submitted;

  @override
  void initState() {
    super.initState();
    _trackDisplayed();
  }

  @override
  void didUpdateWidget(covariant CompactAuditableConclusionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conclusion.value.id != widget.conclusion.value.id) {
      _trackDisplayed();
    }
  }

  void _trackDisplayed() {
    final value = widget.conclusion.value;
    final view = PostSaveConclusionView.of(widget.conclusion);
    // This compact card is the shipping post-save renderer. Generation and
    // persistence alone never spend free proof; only this mounted renderer
    // can record actual delivery.
    unawaited(_recordRendered());
    if (value.kind == ExplainableInsightKind.observation) {
      unawaited(
        EvidenceReceiptAnalytics.postSaveObservationShown(
          evidenceCount: view.evidenceCount,
          confidenceBand: value.confidenceBand.name,
        ),
      );
      return;
    }
    if (value.kind == ExplainableInsightKind.change &&
        view.evidenceCount == 2) {
      unawaited(
        EvidenceReceiptAnalytics.earlyComparisonShown(
          evidenceCount: 2,
          confidenceBand: value.confidenceBand.name,
          origin: widget.analyticsOrigin,
        ),
      );
      return;
    }
    unawaited(
      EvidenceReceiptAnalytics.auditableConclusionShown(
        kind: value.kind.name,
        evidenceCount: view.evidenceCount,
        confidenceBand: value.confidenceBand.name,
        origin: widget.analyticsOrigin,
      ),
    );
  }

  Future<void> _recordRendered() async {
    final outcome = await ProductValueDeliveryRecorder.markRendered(
      widget.conclusion,
    );
    if (!outcome.consumedFreeProof ||
        widget.analyticsOrigin == 'record_post_save') {
      return;
    }
    final event = switch (outcome.kind) {
      DeliveredValueKind.observation => 'first_valid_observation_delivered',
      DeliveredValueKind.comparison => 'first_valid_comparison_delivered',
      null => null,
    };
    if (event == null) return;
    await ProductAnalytics.trackActivation(
      event,
      parameters: {'ui_origin': widget.analyticsOrigin},
    );
  }

  Future<void> _submit(
    InsightFeedbackChoice choice, {
    String? correctionNote,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final callback = widget.onFeedbackSubmitted;
      if (callback != null) {
        await Future<void>.sync(() => callback(choice, correctionNote));
      } else {
        await ExplainableConclusionFeedbackCoordinator.submit(
          conclusion: widget.conclusion,
          choice: choice,
          correctionNote: correctionNote,
          origin: widget.analyticsOrigin,
        );
      }
      if (!mounted) return;
      setState(() {
        _submitted = choice;
        _hidden = choice != InsightFeedbackChoice.accurate;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askWrongAngle() async {
    var correctionText = '';
    final correction = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('What did ArchiveMe misunderstand?'),
        content: TextField(
          key: const Key('post_save_correction_input'),
          onChanged: (value) => correctionText = value,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Optional correction'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(correctionText.trim()),
            child: const Text('Save correction'),
          ),
        ],
      ),
    );
    if (correction == null || !mounted) return;
    await _submit(InsightFeedbackChoice.wrongAngle, correctionNote: correction);
  }

  Future<void> _openDetail(PostSaveConclusionView view) =>
      PostSaveEvidenceDetailSheet.show(
        context,
        view: view,
        onEvidenceSelected: widget.onEvidenceSelected,
        onAudioEvidenceSelected: widget.onAudioEvidenceSelected,
        nextQuestion: widget.nextQuestion,
        onRecordNext: widget.onRecordNext,
        markers: widget.markers,
      );

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final view = PostSaveConclusionView.of(widget.conclusion);
    final quote = view.strongestQuote;
    final date = view.strongestDate;
    return Card(
      key: const Key('post_save_compact_conclusion'),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Evidence-backed insight',
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                container: true,
                label: '${view.label}. ${view.statement}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.label,
                        key: const Key('post_save_conclusion_label'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        view.statement,
                        key: const Key('post_save_conclusion_statement'),
                        softWrap: true,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              if (quote != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '“$quote”',
                  key: const Key('post_save_strongest_quote'),
                  softWrap: true,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
              if (date != null) ...[
                const SizedBox(height: 4),
                Text(
                  date,
                  key: const Key('post_save_evidence_date'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 4),
              Semantics(
                container: true,
                label:
                    '${view.evidenceCountLabel}. ${view.confidenceBandLabel}.',
                child: ExcludeSemantics(
                  child: Text(
                    '${view.evidenceCountLabel} · ${view.confidenceBandLabel}',
                    key: const Key('post_save_evidence_count'),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                container: true,
                label: 'Correct this interpretation',
                child: Wrap(
                  key: const Key('post_save_feedback_controls'),
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _CompactFeedbackButton(
                      key: const Key('post_save_feedback_accurate'),
                      label: 'Accurate',
                      selected: _submitted == InsightFeedbackChoice.accurate,
                      enabled: !_busy,
                      onPressed: () => _submit(InsightFeedbackChoice.accurate),
                    ),
                    _CompactFeedbackButton(
                      key: const Key('post_save_feedback_wrong_angle'),
                      label: 'Wrong angle',
                      selected: _submitted == InsightFeedbackChoice.wrongAngle,
                      enabled: !_busy,
                      onPressed: _askWrongAngle,
                    ),
                    _CompactFeedbackButton(
                      key: const Key('post_save_feedback_too_generic'),
                      label: 'Too generic',
                      selected: _submitted == InsightFeedbackChoice.tooGeneric,
                      enabled: !_busy,
                      onPressed: () =>
                          _submit(InsightFeedbackChoice.tooGeneric),
                    ),
                    _CompactFeedbackButton(
                      key: const Key('post_save_feedback_hide'),
                      label: 'Hide',
                      selected: false,
                      enabled: !_busy,
                      onPressed: () => _submit(InsightFeedbackChoice.hide),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('post_save_check_all_evidence'),
                  onPressed: () => unawaited(_openDetail(view)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Check all evidence'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactFeedbackButton extends StatelessWidget {
  const _CompactFeedbackButton({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text(label),
    ),
  );
}
