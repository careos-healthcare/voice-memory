import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/explainable_conclusion/change_dimensions.dart';
import '../../features/explainable_conclusion/explainable_conclusion.dart';
import '../../features/explainable_conclusion/explainable_conclusion_widgets.dart';
import '../../features/structured_markers/structured_marker_comparison.dart';
import '../../features/structured_markers/structured_markers.dart';
import '../../services/evidence_receipt_analytics.dart';
import '../../theme/app_spacing.dart';
import 'post_save_conclusion_view.dart';

/// Expanded detail for one post-save conclusion.
///
/// Everything the compact card deliberately withholds lives here: every
/// quotation, the complete chronology, which dimensions actually moved, the
/// alternative explanation and its rationale, the method, the full uncertainty
/// note and all source actions.
///
/// The expansion is a sheet, so its open state lives only in the widget tree.
/// Nothing about it is written to storage and it never survives the session.
class PostSaveEvidenceDetailSheet extends StatelessWidget {
  const PostSaveEvidenceDetailSheet({
    super.key,
    required this.view,
    this.onEvidenceSelected,
    this.onAudioEvidenceSelected,
    this.nextQuestion,
    this.onRecordNext,
    this.markers = const {},
  });

  final PostSaveConclusionView view;
  final ExplainableEvidenceNavigation? onEvidenceSelected;
  final ExplainableEvidenceNavigation? onAudioEvidenceSelected;
  final String? nextQuestion;
  final ValueChanged<String?>? onRecordNext;

  /// Optional ten-second-check markers, keyed by entry id. They only ever add a
  /// dimension the cited words cannot compare on their own.
  final Map<String, StructuredMarkers> markers;

  static Future<void> show(
    BuildContext context, {
    required PostSaveConclusionView view,
    ExplainableEvidenceNavigation? onEvidenceSelected,
    ExplainableEvidenceNavigation? onAudioEvidenceSelected,
    String? nextQuestion,
    ValueChanged<String?>? onRecordNext,
    Map<String, StructuredMarkers> markers = const {},
  }) {
    unawaited(
      EvidenceReceiptAnalytics.receiptOpened(
        evidenceCount: view.evidenceCount,
        origin: 'record_post_save',
      ),
    );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => PostSaveEvidenceDetailSheet(
        view: view,
        onEvidenceSelected: onEvidenceSelected,
        onAudioEvidenceSelected: onAudioEvidenceSelected,
        nextQuestion: nextQuestion,
        onRecordNext: onRecordNext,
        markers: markers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = view.conclusion.value;
    final alternative = value.alternatives.isEmpty
        ? null
        : value.alternativeExplanation;
    final changedDimensions = StructuredMarkerComparison.forConclusion(
      view.conclusion,
      markers: markers,
    ).changed;
    return SafeArea(
      key: const Key('post_save_evidence_detail_sheet'),
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          Focus(
            autofocus: true,
            child: Semantics(
              header: true,
              child: Text(
                'All evidence',
                key: const Key('post_save_detail_title'),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${view.evidenceCountLabel} · ${view.confidenceBandLabel}',
            key: const Key('post_save_detail_evidence_count'),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SectionHeader(
            'Every quotation',
            key: const Key('post_save_detail_quotations'),
          ),
          for (final citation in value.evidence)
            _DetailEvidenceRow(
              citation: citation,
              evidenceCount: view.evidenceCount,
              onSelected: onEvidenceSelected,
              onAudioSelected: onAudioEvidenceSelected,
            ),
          const SizedBox(height: AppSpacing.sm),
          _SectionHeader(
            'Chronology',
            key: const Key('post_save_detail_chronology'),
          ),
          for (final citation in view.chronology)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                [
                  PostSaveConclusionView.temporalLabel(citation.temporalRole),
                  ?PostSaveConclusionView.formatFullDate(
                    citation.sourceCapturedAt,
                  ),
                  PostSaveConclusionView.sourceLabel(citation.sourceType),
                ].join(' · '),
              ),
            ),
          if (changedDimensions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _SectionHeader(
              'What changed',
              key: const Key('post_save_detail_changed_dimensions'),
            ),
            for (final movement in changedDimensions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  _movementSummary(movement),
                  key: ValueKey(
                    'post_save_detail_dimension_${movement.dimension.name}',
                  ),
                  softWrap: true,
                ),
              ),
          ],
          if (alternative != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _SectionHeader(
              'Alternative explanation',
              key: const Key('post_save_detail_alternative'),
            ),
            Text(
              alternative.statement,
              key: const Key('post_save_detail_alternative_statement'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              alternative.rationale,
              key: const Key('post_save_detail_alternative_rationale'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _SectionHeader('Method', key: const Key('post_save_detail_method')),
          for (final step in value.reasoning)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(step),
            ),
          const SizedBox(height: AppSpacing.sm),
          _SectionHeader(
            'Uncertainty',
            key: const Key('post_save_detail_uncertainty'),
          ),
          Text(
            value.uncertaintyNote,
            key: const Key('post_save_detail_uncertainty_note'),
          ),
          if (nextQuestion != null && onRecordNext != null) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionHeader(
              'A useful question for next time',
              key: const Key('post_save_detail_next_question_header'),
            ),
            Text(
              nextQuestion!,
              key: const Key('post_save_detail_next_question'),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton.icon(
              key: const Key('post_save_detail_record_next'),
              onPressed: () {
                Navigator.of(context).pop();
                onRecordNext!(nextQuestion);
              },
              icon: const Icon(Icons.mic_none),
              label: const Text('Record another moment'),
            ),
          ],
        ],
      ),
    );
  }
}

/// "how it turned out: more" is not English. An ordered ending reads as more or
/// less settled; every other dimension already reads correctly.
String _movementSummary(DimensionMovement movement) {
  if (movement.dimension != ChangeDimension.outcome) return movement.summary;
  return switch (movement.direction) {
    DimensionDirection.increased => '${movement.dimension.label}: more settled',
    DimensionDirection.decreased => '${movement.dimension.label}: less settled',
    _ => movement.summary,
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class _DetailEvidenceRow extends StatelessWidget {
  const _DetailEvidenceRow({
    required this.citation,
    required this.evidenceCount,
    required this.onSelected,
    required this.onAudioSelected,
  });

  final TranscriptEvidenceCitation citation;
  final int evidenceCount;
  final ExplainableEvidenceNavigation? onSelected;
  final ExplainableEvidenceNavigation? onAudioSelected;

  Future<void> _open(BuildContext context) async {
    final playsAudio = citation.hasPlayableAudio && onAudioSelected != null;
    final selected = playsAudio ? onAudioSelected : onSelected;
    if (selected == null) return;
    unawaited(
      EvidenceReceiptAnalytics.sourceMomentOpened(
        hasPlayableAudio: playsAudio,
        origin: 'record_post_save',
      ),
    );
    await Future<void>.sync(() => selected(context, citation));
  }

  @override
  Widget build(BuildContext context) {
    final playsAudio = citation.hasPlayableAudio && onAudioSelected != null;
    final actionable = playsAudio || onSelected != null;
    final date = PostSaveConclusionView.formatFullDate(
      citation.sourceCapturedAt,
    );
    final audioTimestamp = PostSaveConclusionView.formatAudioTimestamp(
      citation.audioTimestampMs,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      key: ValueKey(
        'post_save_detail_evidence_${citation.entryId}_${citation.startUtf16}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“${citation.quote.trim()}”',
            key: ValueKey(
              'post_save_detail_quote_${citation.entryId}_${citation.startUtf16}',
            ),
            softWrap: true,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            [
              PostSaveConclusionView.temporalLabel(citation.temporalRole),
              ?date,
              PostSaveConclusionView.sourceLabel(citation.sourceType),
              if (audioTimestamp != null) 'Audio $audioTimestamp',
            ].join(' · '),
          ),
          if (actionable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey(
                  'post_save_detail_open_${citation.entryId}_${citation.startUtf16}',
                ),
                onPressed: () => unawaited(_open(context)),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: Icon(
                  playsAudio ? Icons.play_arrow : Icons.open_in_new,
                  size: 20,
                ),
                label: const Text('Open exact moment'),
              ),
            ),
        ],
      ),
    );
  }
}
