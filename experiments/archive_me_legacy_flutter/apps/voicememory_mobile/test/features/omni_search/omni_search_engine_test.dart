import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/omni_search/omni_search_engine.dart';
import 'package:voicememory_mobile/features/omni_search/search_intent.dart';

void main() {
  const intent = SearchIntent(semanticQuery: 'work burnout');
  final date = DateTime.utc(2026, 7, 20);

  test('merges, ranks, and deduplicates lexical and vector results', () async {
    final shared = OmniSearchCandidate(
      kind: OmniSearchResultKind.audioMemory,
      id: 'entry-1',
      title: 'Deadline reflection',
      snippet: 'I felt overwhelmed by the deadline.',
      createdAt: date,
      matchedTerms: const ['deadline'],
    );
    final graph = OmniSearchCandidate(
      kind: OmniSearchResultKind.graphNode,
      id: 'node-1',
      title: 'Work',
      snippet: 'Recurring project pressure',
      createdAt: date,
      matchedTerms: const ['work'],
    );
    final theory = OmniSearchCandidate(
      kind: OmniSearchResultKind.activeTheory,
      id: 'theory-1',
      title: 'Deadlines may correlate with overwhelm',
      snippet: '62% confidence',
      createdAt: date,
      matchedTerms: const ['work'],
    );
    final engine = OmniSearchEngine(
      lexicalSource: _Source('Exact', [shared, graph]),
      semanticSource: _Source('Semantic', [shared, graph]),
      theorySource: _Source('Theory', [theory]),
      clock: () => DateTime.utc(2026, 7, 27),
    );

    final results = await engine.search(intent);

    expect(results.audioMemories, hasLength(1));
    expect(results.graphNodes, hasLength(1));
    expect(results.activeTheories, hasLength(1));
    expect(
      results.audioMemories.single.matchReasons,
      containsAll(['Exact', 'Semantic']),
    );
    expect(
      results.audioMemories.single.score,
      greaterThan(results.activeTheories.single.score),
    );
  });

  test('keeps graph and audio results separate when IDs coincide', () async {
    final graph = OmniSearchCandidate(
      kind: OmniSearchResultKind.graphNode,
      id: 'same',
      title: 'Work',
      snippet: 'Node',
      createdAt: date,
      matchedTerms: const ['work'],
    );
    final memory = OmniSearchCandidate(
      kind: OmniSearchResultKind.audioMemory,
      id: 'same',
      title: 'Work memory',
      snippet: 'Transcript',
      createdAt: date,
      matchedTerms: const ['work'],
    );
    final engine = OmniSearchEngine(
      lexicalSource: _Source('Exact', [graph, memory]),
      semanticSource: _Source('Semantic', const []),
      theorySource: _Source('Theory', const []),
    );

    final results = await engine.search(intent);

    expect(results.graphNodes, hasLength(1));
    expect(results.audioMemories, hasLength(1));
  });
}

class _Source implements OmniSearchSource {
  const _Source(this.sourceName, this.rows);

  @override
  final String sourceName;
  final List<OmniSearchCandidate> rows;

  @override
  Future<List<OmniSearchCandidate>> search(
    SearchIntent intent, {
    int limit = 50,
  }) async => rows.take(limit).toList();
}
