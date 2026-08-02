import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/adaptive_question/adaptive_question_service.dart';
import '../../features/insight_feedback/insight_feedback_store.dart';
import '../../features/recording/domain/application/post_save_experience_coordinator.dart';
import '../../features/structured_markers/structured_marker_store.dart';
import '../../features/structured_markers/structured_markers.dart';
import '../../theme/app_spacing.dart';
import 'compact_auditable_conclusion_card.dart';
import 'evidence_grounded_next_question_card.dart';
import 'optional_structured_check_card.dart';

/// Thin renderer for the focused V1 post-save experience.
///
/// The order is fixed: the saved confirmation and editable transcript, then at
/// most one reduced conclusion with its strongest evidence and the correction
/// controls, then the optional ten-second check, then exactly one
/// evidence-grounded question. The saved words always come first, and the one
/// question always comes last.
class FocusedAuditablePostSaveSection extends StatefulWidget {
  const FocusedAuditablePostSaveSection({
    super.key,
    required this.experience,
    required this.onEditTranscript,
    required this.onOpenSavedMoment,
    required this.onRecordNext,
    this.analyticsOrigin = 'record_post_save',
  });

  final PostSaveExperience experience;
  final VoidCallback onEditTranscript;
  final VoidCallback onOpenSavedMoment;
  final ValueChanged<String?> onRecordNext;
  final String analyticsOrigin;

  @override
  State<FocusedAuditablePostSaveSection> createState() =>
      _FocusedAuditablePostSaveSectionState();
}

class _FocusedAuditablePostSaveSectionState
    extends State<FocusedAuditablePostSaveSection> {
  /// This archive's markers, keyed by entry id. Read once so the expanded
  /// evidence can compare the cited moments' markers, not just this one's.
  Map<String, StructuredMarkers> _markers = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadMarkers());
  }

  Future<void> _loadMarkers() async {
    final markers = await StructuredMarkerRepository.forArchive();
    if (!mounted || markers.isEmpty) return;
    setState(() => _markers = markers);
  }

  void _onMarkersChanged(StructuredMarkers markers) {
    setState(() {
      final next = Map.of(_markers);
      if (markers.isEmpty) {
        next.remove(markers.entryId);
      } else {
        next[markers.entryId] = markers;
      }
      _markers = next;
    });
    unawaited(StructuredMarkerRepository.save(markers));
  }

  @override
  Widget build(BuildContext context) {
    final experience = widget.experience;
    final onRecordNext = widget.onRecordNext;
    final conclusion = experience.conclusion;
    // One question, derived from this conclusion's own citations and the
    // reader's last correction. No evidence means no question at all.
    final question = AdaptiveQuestionService.next(
      conclusion: conclusion,
      latestCorrection: conclusion == null
          ? null
          : InsightFeedbackStore.latestForConclusionOrTemplate(
              conclusionId: conclusion.value.id,
              templateId: conclusion.value.theoryId,
            ),
      markers: _markers[experience.entry.id],
    );
    final content = Column(
      key: const Key('focused_auditable_post_save_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const Key('post_save_saved_confirmation'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saved.', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                const Text('Editable transcript'),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  experience.entry.transcript,
                  key: const Key('post_save_editable_transcript'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    TextButton(
                      key: const Key('post_save_type_what_you_said'),
                      onPressed: widget.onEditTranscript,
                      child: const Text('Edit transcript'),
                    ),
                    TextButton(
                      key: const Key('post_save_open_saved_moment'),
                      onPressed: widget.onOpenSavedMoment,
                      child: Text(
                        experience.entry.localAudioReference == null
                            ? 'Open saved moment'
                            : 'Open or play saved moment',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'One moment gives ArchiveMe an observation. Returning gives '
                  'it something real to compare.',
                  key: Key('post_save_supporting_line'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (conclusion != null)
          CompactAuditableConclusionCard(
            conclusion: conclusion,
            analyticsOrigin: widget.analyticsOrigin,
            markers: _markers,
            onRecordNext: onRecordNext,
            onEvidenceSelected: (context, citation) {
              context.push('/entry/${citation.entryId}');
            },
            onAudioEvidenceSelected: (context, citation) {
              final route = Uri(
                path: '/entry/${citation.entryId}',
                queryParameters: {
                  if (citation.audioTimestampMs != null)
                    'audioTimestampMs': citation.audioTimestampMs.toString(),
                },
              );
              context.push(route.toString());
            },
          )
        else ...[
          const Card(
            key: Key('focused_auditable_no_conclusion'),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Saved. ArchiveMe does not have enough evidence for a '
                'reliable observation yet.',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('focused_auditable_record_next'),
            onPressed: () => onRecordNext(experience.nextQuestion),
            icon: const Icon(Icons.mic_none),
            label: const Text('Record another moment'),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        OptionalStructuredCheckCard(
          entryId: experience.entry.id,
          initialMarkers: _markers[experience.entry.id],
          onChanged: _onMarkersChanged,
        ),
        if (question != null) ...[
          const SizedBox(height: AppSpacing.md),
          EvidenceGroundedNextQuestionCard(
            question: question,
            onRecordNext: onRecordNext,
          ),
        ],
      ],
    );
    // The saved words, the reading and the question must never be clipped. When
    // a caller hands this section a fixed height instead of a scrollable — or
    // when the reader is at the largest text scale — it scrolls itself.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? SingleChildScrollView(child: content)
          : content,
    );
  }
}
