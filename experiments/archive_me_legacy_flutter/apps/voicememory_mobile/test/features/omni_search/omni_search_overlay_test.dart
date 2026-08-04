import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/features/omni_search/omni_search_engine.dart';
import 'package:voicememory_mobile/features/omni_search/omni_search_overlay.dart';
import 'package:voicememory_mobile/features/omni_search/search_graph_focus.dart';
import 'package:voicememory_mobile/features/omni_search/search_intent.dart';
import 'package:voicememory_mobile/features/omni_search/search_query_translator.dart';

void main() {
  testWidgets('groups results and sends graph focus callback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final focus = SearchGraphFocus();
    addTearDown(focus.dispose);
    final node = GraphNode(
      id: 'work-node',
      type: NodeType.project,
      label: 'Project Atlas',
      confidence: .8,
      createdAt: DateTime.utc(2026, 7, 1),
    );
    final candidate = OmniSearchCandidate(
      kind: OmniSearchResultKind.graphNode,
      id: node.id,
      title: node.label,
      snippet: 'Project deadline pressure',
      createdAt: node.createdAt,
      matchedTerms: const ['project'],
      node: node,
    );
    final engine = OmniSearchEngine(
      lexicalSource: _Source('Exact or fuzzy text', [candidate]),
      semanticSource: const _Source('Semantic similarity', []),
      theorySource: const _Source('Active confidence theory', []),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OmniSearchLauncher(
            engineLoader: () async => engine,
            translator: const _Translator(),
            onGraphNodeSelected: (result) => focus.focus(result.id),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('omni_search_launcher')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('omni_search_overlay')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('omni_search_field')),
      'project deadline',
    );
    await tester.tap(find.byKey(const Key('omni_search_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Graph Nodes'), findsOneWidget);
    expect(find.text('Project Atlas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('omni_result_graphNode_work-node')));
    await tester.pumpAndSettle();

    expect(focus.value.nodeId, 'work-node');
    expect(find.byKey(const Key('omni_search_overlay')), findsNothing);
  });

  testWidgets('renders audio memories and active theories in sections', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final date = DateTime.utc(2026, 7, 1);
    final engine = OmniSearchEngine(
      lexicalSource: _Source('Exact', [
        OmniSearchCandidate(
          kind: OmniSearchResultKind.audioMemory,
          id: 'entry-1',
          title: 'A hard week',
          snippet: 'I felt overwhelmed by project work.',
          createdAt: date,
          matchedTerms: const ['overwhelmed'],
        ),
      ]),
      semanticSource: const _Source('Semantic', []),
      theorySource: _Source('Theory', [
        OmniSearchCandidate(
          kind: OmniSearchResultKind.activeTheory,
          id: 'theory-1',
          title: 'Workload may affect mood',
          snippet: '64% confidence',
          createdAt: date,
          matchedTerms: const ['mood'],
        ),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OmniSearchOverlay(
            engine: engine,
            translator: const _Translator(),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('omni_search_field')),
      'overwhelmed work mood',
    );
    await tester.tap(find.byKey(const Key('omni_search_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Audio Memories'), findsOneWidget);
    expect(find.text('Active Theories'), findsOneWidget);
    expect(find.text('A hard week'), findsOneWidget);
    expect(find.text('Workload may affect mood'), findsOneWidget);
  });
}

class _Translator implements SearchQueryTranslator {
  const _Translator();

  @override
  Future<SearchIntent> translate(String rawQuery) async =>
      SearchIntent(semanticQuery: rawQuery);
}

class _Source implements OmniSearchSource {
  const _Source(this.sourceName, this.results);

  @override
  final String sourceName;
  final List<OmniSearchCandidate> results;

  @override
  Future<List<OmniSearchCandidate>> search(
    SearchIntent intent, {
    int limit = 50,
  }) async => results;
}
