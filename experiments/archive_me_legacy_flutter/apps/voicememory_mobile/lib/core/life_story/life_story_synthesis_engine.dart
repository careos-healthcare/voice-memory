import '../engines/ai_time_machine_engine.dart';
import '../engines/evidence_coaching_engine.dart';
import '../engines/goal_evidence_engine.dart';
import '../engines/identity_evolution_engine.dart';
import '../engines/life_chapters_engine.dart';
import '../engines/life_story_engine.dart';
import '../engines/long_term_predictor_engine.dart';
import '../engines/memory_timeline_engine.dart';
import '../engines/relationship_memory_engine.dart';
import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import '../../features/relationships/relationship_dynamics_synthesis.dart';
import '../../services/ai/local_semantic_store.dart';

/// Canonical graph-backed synthesis for the user's evolving life story.
///
/// Individual engines remain small deterministic analyzers, while this facade
/// is the only orchestration point consumed by providers and presentation.
class LifeStorySynthesisEngine {
  const LifeStorySynthesisEngine(this.graph);

  final PersonalKnowledgeGraph graph;

  LifeStorySynthesisSnapshot synthesize({DateTime? identityBoundary}) {
    final boundary = identityBoundary ?? _evidenceMidpoint();
    return LifeStorySynthesisSnapshot(
      graph: graph,
      story: LifeStoryEngine(graph).build(),
      chapters: LifeChaptersEngine(graph).detect(),
      identityShifts: IdentityEvolutionEngine(
        graph,
      ).analyze(boundary: boundary),
      relationships: RelationshipMemoryEngine(graph).analyze(),
      goals: GoalEvidenceEngine(graph).build(),
      coachingObservations: EvidenceCoachingEngine(graph).find(),
      forecasts: LongTermPredictorEngine(graph).forecast(),
      timelineCorrelations: MemoryTimelineEngine(graph).correlateAnchorEvents(),
      timeMachine: AITimeMachineEngine(graph),
    );
  }

  Future<RelationshipDynamicsReview> synthesizeRelationshipDynamics({
    required GraphNode person,
    required LocalSemanticStore semanticStore,
    required RelationshipCloudSynthesizer cloudSynthesizer,
  }) => RelationshipDynamicsSynthesis(
    graph: graph,
    semanticStore: semanticStore,
    cloudSynthesizer: cloudSynthesizer,
  ).synthesize(person);

  DateTime _evidenceMidpoint() {
    final dates =
        graph.nodes
            .expand((node) => node.evidence)
            .map((evidence) => evidence.observedAt.toUtc())
            .toList()
          ..sort();
    if (dates.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return dates[dates.length ~/ 2];
  }
}

class LifeStorySynthesisSnapshot {
  const LifeStorySynthesisSnapshot({
    required this.graph,
    required this.story,
    required this.chapters,
    required this.identityShifts,
    required this.relationships,
    required this.goals,
    required this.coachingObservations,
    required this.forecasts,
    required this.timelineCorrelations,
    required this.timeMachine,
  });

  final PersonalKnowledgeGraph graph;
  final LifeStory story;
  final List<LifeChapter> chapters;
  final List<IdentityBeliefShift> identityShifts;
  final List<RelationshipMemory> relationships;
  final List<GoalEvidenceRecord> goals;
  final List<EvidenceCoachingObservation> coachingObservations;
  final List<ConditionalTrajectoryForecast> forecasts;
  final List<TimelineCorrelation> timelineCorrelations;
  final AITimeMachineEngine timeMachine;
}
