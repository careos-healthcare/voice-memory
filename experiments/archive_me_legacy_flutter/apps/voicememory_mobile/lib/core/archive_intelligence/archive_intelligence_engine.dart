import '../../features/archive_state_delta/archive_state_snapshot.dart';
import '../../features/archive_state_object/archive_state_object.dart';
import '../../features/archive_v1/archive_v1_builder.dart';
import '../../features/archive_v1/archive_v1_models.dart';
import '../../features/belief_evolution/belief_evolution_service.dart';
import '../../features/discover/discover_engine.dart';
import '../../features/discover/discover_local.dart';
import '../../features/discover/discover_models.dart';
import '../../features/insights/archive_insight.dart';
import '../../features/insights/archive_insights_engine.dart';
import '../../models/journal_entry.dart';

/// Canonical journal-backed analytical facade.
///
/// Theory, change feed, belief surface inputs, predictions, discovery, and
/// proof-aware insights now enter presentation and API layers through one
/// orchestration boundary.
class ArchiveIntelligenceEngine {
  const ArchiveIntelligenceEngine({
    this.archiveBuilder = const ArchiveV1Builder(),
    this.insightsEngine = const ArchiveInsightsEngine(),
    this.discoveryEngine = const DiscoverYourselfEngine(),
  });

  final ArchiveV1Builder archiveBuilder;
  final ArchiveInsightsEngine insightsEngine;
  final DiscoverYourselfEngine discoveryEngine;

  Future<ArchiveIntelligenceSnapshot> synthesize({
    required List<JournalEntry> entries,
    required BeliefEvolutionService evolutionService,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? baseline,
    DiscoverLocalFeed? discoverFeed,
    Map<String, int>? themeBaseline,
    String? currentBelief,
    List<({String statement, int confidence})>? candidateBeliefs,
  }) async {
    final archive = await buildArchiveView(
      entries: entries,
      evolutionService: evolutionService,
      state: state,
      baseline: baseline,
    );
    final discovery = buildDiscovery(
      entries: entries,
      state: state,
      themeBaseline: themeBaseline,
    );
    final insights = buildInsights(
      entries: entries,
      discoverFeed: discoverFeed,
      currentBelief: currentBelief ?? archive.belief?.statement,
      candidateBeliefs: candidateBeliefs,
    );
    return ArchiveIntelligenceSnapshot(
      archive: archive,
      insights: insights,
      discovery: discovery,
    );
  }

  Future<ArchiveV1View> buildArchiveView({
    required List<JournalEntry> entries,
    required BeliefEvolutionService evolutionService,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? baseline,
  }) {
    return archiveBuilder.build(
      entries: entries,
      state: state,
      baseline: baseline,
      evolutionService: evolutionService,
    );
  }

  ArchiveInsightsSnapshot buildInsights({
    required List<JournalEntry> entries,
    DiscoverLocalFeed? discoverFeed,
    String? currentBelief,
    List<({String statement, int confidence})>? candidateBeliefs,
  }) {
    return insightsEngine.build(
      entries: entries,
      discoverFeed: discoverFeed,
      currentBelief: currentBelief,
      candidateBeliefs: candidateBeliefs,
    );
  }

  DiscoverYourselfSnapshot buildDiscovery({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    Map<String, int>? themeBaseline,
    bool useCache = true,
  }) {
    return discoveryEngine.build(
      entries: entries,
      state: state,
      themeBaseline: themeBaseline,
      useCache: useCache,
    );
  }

  DiscoverArchiveAnswer? answerArchiveQuestion({
    required String prompt,
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    return discoveryEngine.answerArchiveQuestion(
      prompt: prompt,
      entries: entries,
      state: state,
    );
  }
}

class ArchiveIntelligenceSnapshot {
  const ArchiveIntelligenceSnapshot({
    required this.archive,
    required this.insights,
    required this.discovery,
  });

  final ArchiveV1View archive;
  final ArchiveInsightsSnapshot insights;
  final DiscoverYourselfSnapshot discovery;
}
