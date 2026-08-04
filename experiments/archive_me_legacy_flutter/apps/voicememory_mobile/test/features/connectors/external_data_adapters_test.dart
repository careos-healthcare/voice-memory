import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/connectors/contextual_fusion_engine.dart';
import 'package:voicememory_mobile/features/connectors/external_data_adapters.dart';

void main() {
  test('HealthKit adapter creates locked external temporal nodes', () {
    final graph = const HealthKitAdapter().adapt(
      HealthDailySample(
        day: DateTime.utc(2026, 7, 27),
        sleepHours: 4,
        steps: 8240,
        restingHeartRate: 58,
      ),
    );

    expect(graph.nodes, hasLength(3));
    expect(
      graph.nodes,
      everyElement(
        isA<GraphNode>()
            .having((node) => node.origin, 'origin', NodeOrigin.external)
            .having((node) => node.confidence, 'confidence', 1)
            .having(
              (node) => node.externalSource,
              'source',
              ExternalSource.appleHealth,
            ),
      ),
    );
    expect(graph.edges, hasLength(2));
    expect(graph.nodes.first.toJson()['externalSource'], 'apple_health');
    expect(
      GraphNode.fromJson(graph.nodes.first.toJson()).externalSource,
      ExternalSource.appleHealth,
    );
    expect(graph.nodes.first.evidence.single.entryId, startsWith('external:'));
  });

  test('Spotify adapter aggregates daily valence and energy', () {
    final graph = const SpotifyAdapter().adapt([
      SpotifyTrackSample(
        trackId: 'one',
        playedAt: DateTime.utc(2026, 7, 27, 8),
        trackName: 'First',
        artistName: 'Artist',
        valence: .8,
        energy: .6,
      ),
      SpotifyTrackSample(
        trackId: 'two',
        playedAt: DateTime.utc(2026, 7, 27, 9),
        trackName: 'Second',
        artistName: 'Artist',
        valence: .6,
        energy: .8,
      ),
    ]);

    expect(
      graph.nodes.map((node) => node.label),
      contains('Music valence: 70%'),
    );
    expect(
      graph.nodes.map((node) => node.label),
      contains('Music energy: 70%'),
    );
    expect(
      graph.nodes,
      everyElement(
        isA<GraphNode>().having(
          (node) => node.externalSource,
          'source',
          ExternalSource.spotify,
        ),
      ),
    );
  });

  test('contextual fusion reports cross-domain focus correlation', () {
    final external = [
      ...const HealthKitAdapter()
          .adapt(
            HealthDailySample(day: DateTime.utc(2026, 7, 27), sleepHours: 8),
          )
          .nodes,
      ...const SpotifyAdapter().adapt([
        SpotifyTrackSample(
          trackId: 'one',
          playedAt: DateTime.utc(2026, 7, 27, 9),
          trackName: 'First',
          artistName: 'Artist',
          energy: .8,
        ),
      ]).nodes,
    ];
    const journalExcerpt = 'I felt focused and kept my focus.';
    final journalNode = GraphNode(
      id: 'journal',
      type: NodeType.project,
      label: 'Deep work',
      confidence: .8,
      evidence: [
        GraphNodeEvidence(
          entryId: 'entry-1',
          observedAt: DateTime.utc(2026, 7, 27, 12),
          confidence: .9,
          excerpt: journalExcerpt,
          startUtf16: 0,
          endUtf16: journalExcerpt.length,
        ),
      ],
    );
    expect(external.map((node) => node.label), contains('Sleep: 8.0h'));
    expect(external.map((node) => node.label), contains('Music energy: 80%'));
    expect(
      RegExp(
        r'\bfocus(?:ed|ing)?\b',
        caseSensitive: false,
      ).allMatches(journalNode.evidence.single.excerpt),
      hasLength(2),
    );

    final correlations = const ContextualFusionEngine().analyze(
      PersonalKnowledgeGraph(nodes: [...external, journalNode]),
    );

    expect(correlations, hasLength(1));
    expect(correlations.single.statement, contains('focus 2 times'));
  });
}
