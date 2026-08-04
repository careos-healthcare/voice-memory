import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/archive_intelligence/archive_intelligence_engine.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/life_story/life_story_synthesis_engine.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_service.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  test('Life Story synthesis owns all graph-backed analytical slices', () {
    final graph = PersonalKnowledgeGraph(nodes: const []);

    final snapshot = LifeStorySynthesisEngine(graph).synthesize();

    expect(snapshot.graph, same(graph));
    expect(snapshot.story.isEmpty, isTrue);
    expect(snapshot.chapters, isEmpty);
    expect(snapshot.identityShifts, isEmpty);
    expect(snapshot.relationships, isEmpty);
    expect(snapshot.goals, isEmpty);
    expect(snapshot.coachingObservations, isEmpty);
    expect(snapshot.forecasts, isEmpty);
    expect(snapshot.timelineCorrelations, isEmpty);
  });

  test('Archive Intelligence emits one journal-backed snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archive_intelligence_engine_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final prefs = await MobilePrefsStore.open('${directory.path}/prefs.json');

    final snapshot = await const ArchiveIntelligenceEngine().synthesize(
      entries: const [],
      evolutionService: BeliefEvolutionService.fromPrefs(prefs),
    );

    expect(snapshot.archive.hasMinimumEvidence, isFalse);
    expect(snapshot.insights.allInsights, isEmpty);
    expect(snapshot.discovery.header.totalRecordings, 0);
  });
}
