import 'package:archiveme_mobile/features/search/vector_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('natural language ask cites the closest entry within 300ms', () async {
    final store = MemoryTranscriptChunkStore();
    final service = VectorSearchService(
      store: store,
      embedder: (text) async => hashTranscriptEmbedding(text),
    );
    await service.indexTranscript(
      entryId: 'solar',
      transcript: 'The solar panel installation finally finished on the roof.',
      durationSeconds: 40,
    );
    for (var index = 0; index < 300; index++) {
      await store.upsert(
        TranscriptChunk(
          entryId: 'noise-$index',
          chunkIndex: 0,
          text: 'unrelated note number $index about groceries',
          startSeconds: 0,
          embedding: hashTranscriptEmbedding('groceries $index'),
        ),
      );
    }

    final result = await service.ask(
      'What did I say about the solar panel installation?',
    );

    expect(result.lookupLatency, lessThan(const Duration(milliseconds: 300)));
    expect(result.citations, isNotEmpty);
    expect(result.citations.first.entryId, 'solar');
    expect(result.reply, contains('solar panel installation'));
    final streamed = await streamConversationalReply(result.reply).toList();
    expect(streamed.length, greaterThan(1));
    expect(streamed.last, result.reply);
  });

  test('ask does not search an empty query', () async {
    var embeddings = 0;
    final service = VectorSearchService(
      store: MemoryTranscriptChunkStore(),
      embedder: (text) async {
        embeddings += 1;
        return hashTranscriptEmbedding(text);
      },
    );

    final result = await service.ask('   ');

    expect(result.reply, isEmpty);
    expect(result.citations, isEmpty);
    expect(result.lookupLatency, Duration.zero);
    expect(embeddings, 0);
  });
}
