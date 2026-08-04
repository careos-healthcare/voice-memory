import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

import '../../core/graph/graph_node.dart';
import '../../features/ai_engines/models/ai_accuracy_feedback.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import '../../features/ai_engines/models/hypothesis_evolution.dart';
import '../../services/app_services.dart';
import '../../services/ai/ai_accuracy_feedback_coordinator.dart';
import '../../services/ai/ai_accuracy_feedback_store.dart';
import '../../services/hallucination_guard/hallucination_guard_service.dart';
import 'ai_accuracy_bar.dart';
import 'citation_playback_widget.dart';
import 'charts/confidence_evolution_chart.dart';

/// Progressive disclosure for the five mandatory explainability pillars.
class AiExplainabilityCard extends StatelessWidget {
  const AiExplainabilityCard({
    super.key,
    required this.explainability,
    this.title = 'Why this conclusion?',
    this.hallucinationGuard,
    this.onPlaybackIntent,
    this.feedbackId,
    this.engine = 'ai_explainability',
    this.linkedNodeIds = const {},
    this.linkedEdgeIds = const {},
    this.onAccuracyFeedback,
  });

  final AiExplainability explainability;
  final String title;
  final HallucinationGuardService? hallucinationGuard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;
  final String? feedbackId;
  final String engine;
  final Set<String> linkedNodeIds;
  final Set<String> linkedEdgeIds;
  final AiAccuracyFeedbackSubmit? onAccuracyFeedback;

  @override
  Widget build(BuildContext context) {
    final guard =
        hallucinationGuard ??
        HallucinationGuardService(
          loadEntry: AppServices.isInitialized
              ? AppServices.instance.journalStore.getById
              : (_) async => null,
        );
    final confidenceLabel = explainability.confidenceKnown
        ? '${explainability.confidence}% confidence'
        : 'Confidence: Unknown';
    final conclusionId = feedbackId ?? _feedbackId(explainability, title);
    final initialFeedback =
        explainability.accuracyFeedback ??
        AiAccuracyFeedback(
          conclusionId: conclusionId,
          confidencePercentage: explainability.confidencePercentage,
          engine: engine,
        );
    final evolutionHistory = explainability.evolutionHistory.isNotEmpty
        ? explainability.evolutionHistory
        : [
            ConfidenceSnapshot(
              date: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              confidenceScore: explainability.confidencePercentage,
              triggeringEvidence: explainability.evidence.first,
              deltaReasoning:
                  'Current confidence based on the cited evidence available.',
            ),
          ];
    return Semantics(
      container: true,
      label:
          '${explainability.isLegacy ? 'Legacy Synthesis. ' : ''}'
          '$title, $confidenceLabel, expandable',
      child: Card(
        key: const Key('ai_explainability_card'),
        margin: EdgeInsets.zero,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!explainability.isLegacy)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AiAccuracyBar(
                    initialFeedback: initialFeedback,
                    showConfidence: false,
                    loadFeedback: AppServices.isInitialized
                        ? () => AiAccuracyFeedbackStore(
                            AppServices.instance.prefs,
                          ).load(conclusionId)
                        : null,
                    onSubmit:
                        onAccuracyFeedback ??
                        (state, note) =>
                            const AiAccuracyFeedbackCoordinator().submit(
                              conclusionId: conclusionId,
                              engine: engine,
                              confidencePercentage:
                                  explainability.confidencePercentage,
                              state: state,
                              citations: explainability.evidence,
                              correctionNote: note,
                              linkedNodeIds: linkedNodeIds,
                              linkedEdgeIds: linkedEdgeIds,
                            ),
                  ),
                ),
              ExpansionTile(
                key: const Key('ai_explainability_expand'),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    if (explainability.isLegacy) ...[
                      const SizedBox(height: 4),
                      const Chip(
                        key: Key('ai_explainability_legacy_badge'),
                        label: Text('Legacy Synthesis'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                subtitle: explainability.confidenceKnown
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConfidenceEvolutionSparkline(
                            theoryId: explainability.theoryId ?? conclusionId,
                            history: evolutionHistory,
                            guard: guard,
                            onPlaybackIntent: onPlaybackIntent,
                          ),
                        ),
                      )
                    : Text(confidenceLabel),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pillar(
                    key: const Key('ai_explainability_confidence'),
                    title: 'Confidence',
                    child: Text(
                      explainability.confidenceKnown
                          ? '${explainability.confidence} out of 100, constrained by '
                                '${explainability.evidence.length} cited '
                                '${explainability.evidence.length == 1 ? 'source' : 'sources'}.'
                          : 'Confidence was not stored in this older synthesis.',
                    ),
                  ),
                  _Pillar(
                    key: const Key('ai_explainability_evidence'),
                    title: 'Evidence',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final source in explainability.externalSources)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Chip(
                              key: Key('external-evidence-${source.nodeId}'),
                              avatar: Icon(
                                source.source == ExternalSource.appleHealth
                                    ? Icons.favorite
                                    : Icons.music_note,
                                color:
                                    source.source == ExternalSource.appleHealth
                                    ? const Color(0xFFFF4D7D)
                                    : const Color(0xFF1ED760),
                              ),
                              label: Text(
                                '${source.source == ExternalSource.appleHealth ? 'Apple Health' : 'Spotify'} · ${source.label} · verified external source',
                              ),
                            ),
                          ),
                        for (final source in explainability.evidence)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: explainability.isLegacy
                                ? Chip(
                                    label: Text(
                                      'Legacy source · “${source.exactQuote}”',
                                    ),
                                  )
                                : CitationPlaybackWidget(
                                    citation: source,
                                    guard: guard,
                                    onPlaybackIntent: onPlaybackIntent,
                                  ),
                          ),
                      ],
                    ),
                  ),
                  _Pillar(
                    key: const Key('ai_explainability_reasoning'),
                    title: 'Reasoning',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < explainability.reasoning.length;
                          index++
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${index + 1}. ${explainability.reasoning[index]}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  _Pillar(
                    key: const Key('ai_explainability_alternative'),
                    title: 'Alternative explanation',
                    child: Text(explainability.alternativeExplanation),
                  ),
                  _Pillar(
                    key: const Key('ai_explainability_uncertainty'),
                    title: 'Uncertainty',
                    child: Text(explainability.uncertainty),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _feedbackId(AiExplainability value, String title) {
    final source = [
      title,
      value.confidence.toString(),
      ...value.evidence.map(
        (item) => '${item.sourceEntryId}:${item.startUtf16}:${item.endUtf16}',
      ),
    ].join('|');
    return 'ai-${sha256.convert(source.codeUnits).toString().substring(0, 24)}';
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
