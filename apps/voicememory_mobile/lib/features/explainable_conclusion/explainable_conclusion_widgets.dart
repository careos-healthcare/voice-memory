import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../services/evidence_receipt_analytics.dart';
import '../insight_feedback/explainable_conclusion_feedback_coordinator.dart';
import '../insight_feedback/insight_feedback_models.dart';
import '../monetization/data/product_value_delivery_recorder.dart';
import 'explainability_history_store.dart';
import 'explainable_conclusion.dart';
import 'explainable_conclusion_validator.dart';

typedef ExplainableEvidenceNavigation =
    FutureOr<void> Function(
      BuildContext context,
      TranscriptEvidenceCitation citation,
    );
typedef ExplainableSheetAction = FutureOr<void> Function();
typedef ExplainableFeedbackSubmission =
    FutureOr<void> Function(
      InsightFeedbackChoice choice,
      String? correctionNote,
    );

class ExplainableConclusionCard extends StatefulWidget {
  const ExplainableConclusionCard({
    super.key,
    required this.conclusion,
    this.onEvidenceSelected,
    this.onAudioEvidenceSelected,
    this.onShowAlternatives,
    this.onShowHistory,
    this.onFeedbackSubmitted,
    this.analyticsOrigin = 'receipt',
  });

  final ValidatedExplainableConclusion conclusion;
  final ExplainableEvidenceNavigation? onEvidenceSelected;
  final ExplainableEvidenceNavigation? onAudioEvidenceSelected;
  final ExplainableSheetAction? onShowAlternatives;
  final ExplainableSheetAction? onShowHistory;
  final ExplainableFeedbackSubmission? onFeedbackSubmitted;
  final String analyticsOrigin;

  @override
  State<ExplainableConclusionCard> createState() =>
      _ExplainableConclusionCardState();
}

class _ExplainableConclusionCardState extends State<ExplainableConclusionCard> {
  final FocusNode _historyFocus = FocusNode(
    debugLabel: 'explainability history',
  );
  bool _hidden = false;
  bool _feedbackBusy = false;
  InsightFeedbackChoice? _submittedFeedback;

  @override
  void initState() {
    super.initState();
    _trackDisplayed();
  }

  @override
  void didUpdateWidget(covariant ExplainableConclusionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conclusion.value.id != widget.conclusion.value.id) {
      _trackDisplayed();
    }
  }

  void _trackDisplayed() {
    final value = widget.conclusion.value;
    final evidenceCount = _distinctEvidenceCount(value);
    // The artifact is on screen, which is the last of the five conditions
    // that make free value genuinely delivered.
    unawaited(ProductValueDeliveryRecorder.markRendered(widget.conclusion));
    if (widget.analyticsOrigin == 'record_post_save' &&
        value.kind == ExplainableInsightKind.observation) {
      unawaited(
        EvidenceReceiptAnalytics.postSaveObservationShown(
          evidenceCount: evidenceCount,
          confidenceBand: value.confidenceBand.name,
        ),
      );
    } else if (widget.analyticsOrigin == 'record_post_save' &&
        value.kind == ExplainableInsightKind.change &&
        evidenceCount == 2) {
      unawaited(
        EvidenceReceiptAnalytics.earlyComparisonShown(
          evidenceCount: 2,
          confidenceBand: value.confidenceBand.name,
          origin: widget.analyticsOrigin,
        ),
      );
    } else {
      unawaited(
        EvidenceReceiptAnalytics.auditableConclusionShown(
          kind: value.kind.name,
          evidenceCount: evidenceCount,
          confidenceBand: value.confidenceBand.name,
          origin: widget.analyticsOrigin,
        ),
      );
    }
  }

  Future<void> _submitFeedback(
    InsightFeedbackChoice choice, {
    String? correctionNote,
  }) async {
    if (_feedbackBusy) return;
    setState(() => _feedbackBusy = true);
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
        _submittedFeedback = choice;
        _hidden =
            choice == InsightFeedbackChoice.hide ||
            choice == InsightFeedbackChoice.wrongAngle ||
            choice == InsightFeedbackChoice.tooGeneric;
      });
    } finally {
      if (mounted) setState(() => _feedbackBusy = false);
    }
  }

  Future<void> _askWrongAngle() async {
    var correctionText = '';
    final correction = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('What did ArchiveMe misunderstand?'),
        content: TextField(
          key: const Key('explainable_correction_input'),
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
    await _submitFeedback(
      InsightFeedbackChoice.wrongAngle,
      correctionNote: correction,
    );
  }

  @override
  void dispose() {
    _historyFocus.dispose();
    super.dispose();
  }

  Future<void> _showHistory() async {
    final action = widget.onShowHistory;
    if (action == null) return;
    await Future<void>.sync(action);
    if (mounted) _historyFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final value = widget.conclusion.value;
    final evidenceCount = _distinctEvidenceCount(value);
    final label = _conclusionLabel(value, evidenceCount);
    final historyAction = const CustomSemanticsAction(
      label: 'View conclusion history',
    );
    final customActions = <CustomSemanticsAction, VoidCallback>{};
    if (widget.onShowHistory != null) {
      customActions[historyAction] = () => unawaited(_showHistory());
    }
    return Card(
      key: const Key('explainable_conclusion_card'),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Evidence-backed insight',
        customSemanticsActions: customActions,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                label: '$label. ${value.statement}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        key: const Key('explainable_conclusion_label'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value.statement,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                label: 'Why ArchiveMe noticed this',
                child: ExcludeSemantics(
                  child: Text(
                    'Why ArchiveMe noticed this',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(value.reasoning.first),
              const SizedBox(height: 12),
              for (final citation in value.evidence)
                _EvidenceRow(
                  citation: citation,
                  onSelected: widget.onEvidenceSelected,
                  onAudioSelected: widget.onAudioEvidenceSelected,
                  evidenceCount: value.evidence.length,
                  analyticsOrigin: widget.analyticsOrigin,
                ),
              const SizedBox(height: 8),
              Semantics(
                label:
                    'Based on $evidenceCount saved '
                    '${evidenceCount == 1 ? 'moment' : 'moments'}. '
                    '${value.confidenceLabel}.',
                child: ExcludeSemantics(
                  child: Text(
                    'Based on $evidenceCount saved '
                    '${evidenceCount == 1 ? 'moment' : 'moments'} · '
                    '${value.confidenceLabel}',
                    key: const Key('explainable_evidence_count'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value.uncertaintyNote,
                key: const Key('explainable_uncertainty'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Alternative explanation',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                value.alternativeExplanation.statement,
                key: const Key('explainable_alternative_inline'),
              ),
              const SizedBox(height: 4),
              Text(
                value.alternativeExplanation.rationale,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (value.correctionNote?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Semantics(
                  label: 'Corrected by you',
                  child: Text(
                    'Corrected by you',
                    key: const Key('explainable_corrected_by_user'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
              if (value.reasoning.length > 1)
                ExpansionTile(
                  key: const Key('explainable_reasoning_disclosure'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('More about this observation'),
                  children: [
                    for (final step in value.reasoning.skip(1))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(step),
                        ),
                      ),
                  ],
                ),
              const Divider(),
              const Text(
                'ArchiveMe can be wrong. You decide whether the '
                'interpretation fits.',
                key: Key('explainable_correction_explanation'),
              ),
              const SizedBox(height: 8),
              Semantics(
                container: true,
                label: 'Correct this interpretation',
                child: Wrap(
                  key: const Key('explainable_correction_controls'),
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _FeedbackButton(
                      key: const Key('explainable_feedback_accurate'),
                      label: 'Accurate',
                      selected:
                          _submittedFeedback == InsightFeedbackChoice.accurate,
                      enabled: !_feedbackBusy,
                      onPressed: () =>
                          _submitFeedback(InsightFeedbackChoice.accurate),
                    ),
                    _FeedbackButton(
                      key: const Key('explainable_feedback_wrong_angle'),
                      label: 'Wrong angle',
                      selected:
                          _submittedFeedback ==
                          InsightFeedbackChoice.wrongAngle,
                      enabled: !_feedbackBusy,
                      onPressed: _askWrongAngle,
                    ),
                    _FeedbackButton(
                      key: const Key('explainable_feedback_too_generic'),
                      label: 'Too generic',
                      selected:
                          _submittedFeedback ==
                          InsightFeedbackChoice.tooGeneric,
                      enabled: !_feedbackBusy,
                      onPressed: () =>
                          _submitFeedback(InsightFeedbackChoice.tooGeneric),
                    ),
                    _FeedbackButton(
                      key: const Key('explainable_feedback_hide'),
                      label: 'Hide',
                      selected: false,
                      enabled: !_feedbackBusy,
                      onPressed: () =>
                          _submitFeedback(InsightFeedbackChoice.hide),
                    ),
                  ],
                ),
              ),
              if (widget.onShowHistory != null)
                Focus(
                  focusNode: _historyFocus,
                  child: TextButton(
                    key: const Key('explainable_history_button'),
                    onPressed: _showHistory,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('History'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static int _distinctEvidenceCount(ExplainableConclusion conclusion) =>
      conclusion.evidence.map((citation) => citation.entryId).toSet().length;

  static String _conclusionLabel(
    ExplainableConclusion conclusion,
    int evidenceCount,
  ) => switch (conclusion.kind) {
    ExplainableInsightKind.observation => 'Possible read',
    ExplainableInsightKind.change => 'Possible change',
    ExplainableInsightKind.pattern =>
      evidenceCount >= 3 ? 'Supported pattern' : 'Possible repeat',
  };
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
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
  Widget build(BuildContext context) {
    return Semantics(
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
}

class _EvidenceRow extends StatefulWidget {
  const _EvidenceRow({
    required this.citation,
    required this.onSelected,
    required this.onAudioSelected,
    required this.evidenceCount,
    required this.analyticsOrigin,
  });

  final TranscriptEvidenceCitation citation;
  final ExplainableEvidenceNavigation? onSelected;
  final ExplainableEvidenceNavigation? onAudioSelected;
  final int evidenceCount;
  final String analyticsOrigin;

  @override
  State<_EvidenceRow> createState() => _EvidenceRowState();
}

class _EvidenceRowState extends State<_EvidenceRow> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'explainable evidence');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final selected =
        widget.citation.hasPlayableAudio && widget.onAudioSelected != null
        ? widget.onAudioSelected
        : widget.onSelected;
    if (selected == null) return;
    unawaited(
      EvidenceReceiptAnalytics.receiptOpened(
        evidenceCount: widget.evidenceCount,
        origin: widget.analyticsOrigin,
      ),
    );
    unawaited(
      EvidenceReceiptAnalytics.sourceMomentOpened(
        hasPlayableAudio:
            widget.citation.hasPlayableAudio && widget.onAudioSelected != null,
        origin: widget.analyticsOrigin,
      ),
    );
    await Future<void>.sync(() => selected(context, widget.citation));
    if (mounted) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final citation = widget.citation;
    final playsAudio =
        citation.hasPlayableAudio && widget.onAudioSelected != null;
    final actionable = playsAudio || widget.onSelected != null;
    const openAction = CustomSemanticsAction(label: 'Open exact moment');
    final sourceDate = _sourceDate(citation.sourceCapturedAt);
    final temporalLabel = switch (citation.temporalRole) {
      EvidenceTemporalRole.then => 'Then',
      EvidenceTemporalRole.now => 'Now',
      EvidenceTemporalRole.single => 'Supporting moment',
    };
    final sourceLabel = switch (citation.sourceType) {
      EvidenceSourceType.voice => 'Voice',
      EvidenceSourceType.text => 'Text',
      EvidenceSourceType.unknown => 'Unknown',
    };
    final audioTimestamp = _audioTimestamp(citation.audioTimestampMs);
    final excerpt = _boundedExcerpt(citation.quote);
    return Focus(
      focusNode: _focusNode,
      child: Semantics(
        button: actionable,
        label:
            '$temporalLabel. $excerpt. '
            '${sourceDate == null ? '' : 'Captured $sourceDate. '}'
            '$sourceLabel source.'
            '${audioTimestamp == null ? '' : ' Audio at $audioTimestamp.'}',
        hint: actionable
            ? playsAudio
                  ? 'Open and play supporting audio'
                  : 'Open source moment'
            : null,
        customSemanticsActions: actionable ? {openAction: _open} : null,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            key: ValueKey(
              'explainable_evidence_${citation.entryId}_${citation.startUtf16}',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“$excerpt”',
                  key: ValueKey(
                    'explainable_quote_${citation.entryId}_${citation.startUtf16}',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    temporalLabel,
                    ?sourceDate,
                    sourceLabel,
                    if (audioTimestamp != null) 'Audio $audioTimestamp',
                  ].join(' · '),
                ),
                if (actionable)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: ValueKey(
                        'open_exact_moment_${citation.entryId}_${citation.startUtf16}',
                      ),
                      onPressed: _open,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: Icon(
                        playsAudio ? Icons.play_arrow : Icons.open_in_new,
                        size: 20,
                      ),
                      label: const Text('Open exact moment'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _boundedExcerpt(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 240) return trimmed;
    return '${trimmed.substring(0, 237).trimRight()}…';
  }

  static String? _audioTimestamp(int? milliseconds) {
    if (milliseconds == null || milliseconds < 0) return null;
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  static String? _sourceDate(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class ExplainableAlternativesSheet extends StatelessWidget {
  const ExplainableAlternativesSheet({super.key, required this.conclusion});

  final ValidatedExplainableConclusion conclusion;

  static Future<void> show(
    BuildContext context, {
    required ValidatedExplainableConclusion conclusion,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => ExplainableAlternativesSheet(conclusion: conclusion),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: const Key('explainable_alternatives_sheet'),
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Focus(
            autofocus: true,
            child: Semantics(
              header: true,
              child: Text(
                'Other explanations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final alternative in conclusion.value.alternatives)
            Semantics(
              container: true,
              label: '${alternative.statement}. ${alternative.rationale}',
              child: ExcludeSemantics(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(alternative.statement),
                  subtitle: Text(alternative.rationale),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ExplainableHistorySheet extends StatefulWidget {
  const ExplainableHistorySheet({
    super.key,
    required this.entries,
    required this.canonicalTranscripts,
    this.onEvidenceSelected,
  });

  final List<ExplainabilityHistoryEntry> entries;
  final Map<String, String> canonicalTranscripts;
  final ExplainableEvidenceNavigation? onEvidenceSelected;

  static Future<void> show(
    BuildContext context, {
    required List<ExplainabilityHistoryEntry> entries,
    required Map<String, String> canonicalTranscripts,
    ExplainableEvidenceNavigation? onEvidenceSelected,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ExplainableHistorySheet(
      entries: entries,
      canonicalTranscripts: canonicalTranscripts,
      onEvidenceSelected: onEvidenceSelected,
    ),
  );

  @override
  State<ExplainableHistorySheet> createState() =>
      _ExplainableHistorySheetState();
}

class _ExplainableHistorySheetState extends State<ExplainableHistorySheet> {
  final Set<int> _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final entry in widget.entries)
        if (ExplainableConclusionRenderGate.visible(
              entry.conclusion,
              canonicalTranscripts: widget.canonicalTranscripts,
            )
            case final gated?)
          (entry: entry, gated: gated),
    ];
    return SafeArea(
      key: const Key('explainable_history_sheet'),
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Focus(
            autofocus: true,
            child: Semantics(
              header: true,
              child: Text(
                'Conclusion history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No validated history available.'),
            ),
          for (var index = 0; index < visible.length; index++)
            _historyEntry(visible[index], index),
        ],
      ),
    );
  }

  Widget _historyEntry(
    ({ExplainabilityHistoryEntry entry, ValidatedExplainableConclusion gated})
    item,
    int index,
  ) {
    final expanded = _expanded.contains(index);
    final version = item.entry.conclusion.historyVersion;
    final label =
        'Version $version, ${item.gated.value.statement}, '
        '${item.gated.value.confidenceLabel}';
    final action = CustomSemanticsAction(
      label: expanded ? 'Collapse version $version' : 'Expand version $version',
    );
    void toggle() {
      setState(() {
        if (expanded) {
          _expanded.remove(index);
        } else {
          _expanded.add(index);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: Key('explainable_history_version_$version'),
          button: true,
          expanded: expanded,
          label: label,
          hint: expanded
              ? 'Collapse version details'
              : 'Expand version details',
          customSemanticsActions: {action: toggle},
          child: ExcludeSemantics(
            child: InkWell(
              onTap: toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.gated.value.statement,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Version $version · '
                              '${item.gated.value.confidenceLabel}',
                            ),
                          ],
                        ),
                      ),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExplainableConclusionCard(
              conclusion: item.gated,
              onEvidenceSelected: widget.onEvidenceSelected,
            ),
          ),
      ],
    );
  }
}

class ValidatingExplainableConclusionCard extends StatelessWidget {
  const ValidatingExplainableConclusionCard({
    super.key,
    required this.conclusion,
    required this.canonicalTranscripts,
    this.onEvidenceSelected,
  });

  final ExplainableConclusion conclusion;
  final Map<String, String> canonicalTranscripts;
  final ExplainableEvidenceNavigation? onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    final gated = ExplainableConclusionRenderGate.visible(
      conclusion,
      canonicalTranscripts: canonicalTranscripts,
    );
    if (gated == null) return const EvidenceReceiptUnavailableState();
    return ExplainableConclusionCard(
      conclusion: gated,
      onEvidenceSelected: onEvidenceSelected,
    );
  }
}

class EvidenceReceiptUnavailableState extends StatelessWidget {
  const EvidenceReceiptUnavailableState({
    super.key,
    this.sourceWasDeleted = false,
  });

  final bool sourceWasDeleted;

  @override
  Widget build(BuildContext context) {
    final message = sourceWasDeleted
        ? 'A supporting moment is no longer available.'
        : 'ArchiveMe is still learning from this moment. Your saved words '
              'remain available without an unsupported observation.';
    return Semantics(
      key: const Key('evidence_receipt_unavailable'),
      container: true,
      label: message,
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message),
          ),
        ),
      ),
    );
  }
}
