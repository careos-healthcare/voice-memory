import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/thematic_triage.dart';

void main() {
  test('clusters suggestions into stable topic decks', () {
    const manager = ThematicClusterManager(
      embeddingDriver: _TopicEmbeddingDriver(),
      minimumClusterSimilarity: .8,
    );

    final decks = manager.cluster([
      _suggestion('zk-1', 'Zero-Knowledge Proofs'),
      _suggestion('bread-1', 'Sourdough Micro-flora'),
      _suggestion('zk-2', 'Zero-Knowledge Proofs'),
      _suggestion('bread-2', 'Sourdough Micro-flora'),
    ]);

    expect(decks, hasLength(2));
    expect(decks.map((deck) => deck.suggestions.length), everyElement(2));
    expect(
      decks.map((deck) => deck.topic),
      containsAll(['Zero-Knowledge Proofs', 'Sourdough Micro-flora']),
    );
  });
}

LegacyBridgeSuggestion _suggestion(String id, String topic) =>
    LegacyBridgeSuggestion(
      id: id,
      sourceNodeId: 'source-$id',
      targetNodeId: 'target-$id',
      sourceLabel: topic,
      targetLabel: '$topic notes',
      entities: [topic],
      confidenceScore: .9,
      rationale: 'Both notes discuss $topic.',
      sourceExcerpt: topic,
      targetExcerpt: topic,
      rationaleConfidence: .9,
      createdAt: DateTime.utc(2026, 7, 29),
    );

final class _TopicEmbeddingDriver implements LocalEmbeddingDriver {
  const _TopicEmbeddingDriver();

  @override
  int get dimensions => 2;

  @override
  Float32List embed(String text) => text.toLowerCase().contains('sourdough')
      ? Float32List.fromList([0, 1])
      : Float32List.fromList([1, 0]);
}
