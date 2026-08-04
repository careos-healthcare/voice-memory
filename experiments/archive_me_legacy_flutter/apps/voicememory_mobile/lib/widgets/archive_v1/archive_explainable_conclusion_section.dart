import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/archive_evidence/archive_evidence.dart';
import '../../features/archive_synthesis/archive_synthesis_models.dart';
import '../../features/archive_v1/archive_v1_models.dart';
import '../../features/explainable_conclusion/auditable_conclusion_trust_policy.dart';
import '../../features/explainable_conclusion/explainable_conclusion_mappers.dart';
import '../../features/explainable_conclusion/explainable_conclusion_widgets.dart';
import '../../features/insight_feedback/insight_feedback_store.dart';
import '../../services/app_services.dart';

/// The only rendering path for AI-authored archive synthesis conclusions.
class ArchiveExplainableConclusionSection extends StatelessWidget {
  const ArchiveExplainableConclusionSection({
    super.key,
    required this.view,
    required this.conclusions,
  });

  final ArchiveV1View view;
  final List<ArchiveSynthesisConclusion> conclusions;

  @override
  Widget build(BuildContext context) {
    final transcripts = {
      for (final entry in archiveEligibleEvidenceEntries(view.eligibleEntries))
        entry.id: entry.transcript,
    };
    final mapped = conclusions
        .map(
          (source) => ExplainableConclusionMappers.fromArchiveSynthesis(
            source: source,
            canonicalTranscripts: transcripts,
          ),
        )
        .toList();
    final gated = mapped
        .map(
          (result) => result.conclusion == null
              ? null
              : AuditableConclusionTrustPolicy.rankBest(
                  candidates: [result.conclusion!],
                  canonicalTranscripts: transcripts,
                  feedback: InsightFeedbackStore.cached,
                )?.conclusion,
        )
        .toList();
    // Artifact-level fail closed: never show a partial AI synthesis.
    if (gated.any((item) => item == null)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in gated)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExplainableConclusionCard(
              conclusion: item!,
              onEvidenceSelected: (context, citation) =>
                  context.push('/entry/${citation.entryId}'),
              onShowHistory: () async {
                if (!AppServices.isInitialized) return;
                final entries = await AppServices
                    .instance
                    .explainabilityHistoryStore
                    .byConclusionId(item.value.id);
                if (!context.mounted) return;
                await ExplainableHistorySheet.show(
                  context,
                  entries: entries,
                  canonicalTranscripts: transcripts,
                  onEvidenceSelected: (context, citation) =>
                      context.push('/entry/${citation.entryId}'),
                );
              },
            ),
          ),
      ],
    );
  }
}
