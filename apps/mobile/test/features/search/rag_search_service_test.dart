import 'package:archiveme_mobile/features/search/rag_search_service.dart';
import 'package:archiveme_mobile/features/search/vector_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('natural language query cites the entry and its similarity', () async {
    final burnt = TranscriptChunk(
      entryId: 'burnt',
      chunkIndex: 0,
      text: 'I felt burnt out after the long week at work.',
      startSeconds: 0,
      embedding: hashTranscriptEmbedding('burnt out'),
    );
    final store = _VecStore([burnt]);
    final service = RagSearchService(
      embedder: (text) async => hashTranscriptEmbedding(text),
      store: store,
      createdAtFor: (id) => id == 'burnt' ? DateTime.utc(2026, 3, 3) : null,
    );

    final answer = await service.search(
      'When was the last time I felt burnt out?',
    );

    expect(answer.citations, isNotEmpty);
    expect(answer.citations.first.entryId, 'burnt');
    expect(answer.citations.first.similarity, closeTo(0.91, 0.001));
    expect(answer.citations.first.href, '/entry/burnt');
    expect(answer.summary, contains('0.91'));
    expect(answer.summary, contains('[Open entry](/entry/burnt)'));
    expect(answer.summary, contains('3 Mar 2026'));
    expect(answer.summary, contains('burnt out'));
  });

  test('an empty question does not embed or search', () async {
    var embeddings = 0;
    final service = RagSearchService(
      embedder: (text) async {
        embeddings += 1;
        return hashTranscriptEmbedding(text);
      },
      store: _VecStore(const []),
    );

    final answer = await service.search('   ');

    expect(answer.summary, isEmpty);
    expect(answer.citations, isEmpty);
    expect(embeddings, 0);
  });
}

class _VecStore extends MemoryTranscriptChunkStore {
  _VecStore(this.rows);

  final List<TranscriptChunk> rows;

  @override
  Future<List<TranscriptChunk>> all() async => rows;

  @override
  Future<List<VecMatch>?> nearestMatches(
    List<double> query, {
    int limit = 5,
  }) async {
    if (rows.isEmpty) return const [];
    return const [VecMatch(key: 'burnt#0', cosine: 0.91)];
  }
}
