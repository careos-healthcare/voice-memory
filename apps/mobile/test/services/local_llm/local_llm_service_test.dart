import 'package:archiveme_mobile/services/local_llm/local_llm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalLlmKnowledgeGraphExtractor', () {
    test('buildPrompt includes entry id and transcript', () {
      final prompt = LocalLlmKnowledgeGraphExtractor.buildPrompt(
        entryId: 'entry-1',
        transcript: 'I agreed again even though I was tired.',
        existingThemes: const ['work'],
      );

      expect(prompt, contains('entry-1'));
      expect(prompt, contains('I agreed again'));
      expect(prompt, contains('Existing themes: work'));
    });

    test('parseGraphJson accepts fenced JSON payloads', () {
      const raw = '''
Here is the graph:
```json
{
  "entryId": "entry-1",
  "tensionOrContradiction": "Keeps saying yes.",
  "nextSmallAction": "Pause before replying.",
  "recurringThemes": ["boundaries"],
  "nodes": [
    {"id": "entry:entry-1", "kind": "journal_entry", "label": "entry-1"},
    {"id": "theme:boundaries:entry-1", "kind": "theme", "label": "boundaries"}
  ],
  "edges": [
    {"from": "entry:entry-1", "to": "theme:boundaries:entry-1", "relation": "mentions_theme", "weight": 0.8}
  ]
}
```
''';

      final update = LocalLlmKnowledgeGraphExtractor.parseGraphJson(
        entryId: 'entry-1',
        rawCompletion: raw,
      );

      expect(update.entryId, 'entry-1');
      expect(update.recurringThemes, ['boundaries']);
      expect(update.nodes, hasLength(2));
      expect(update.edges, hasLength(1));
    });

    test('toKnowledgeGraph preserves explicit nodes and edges', () {
      final update = LocalLlmKnowledgeGraphExtractor.parseGraphJson(
        entryId: 'entry-2',
        rawCompletion: '''
{
  "entryId": "entry-2",
  "nodes": [
    {"id": "entry:entry-2", "kind": "journal_entry", "label": "entry-2"},
    {"id": "action:entry-2", "kind": "next_action", "label": "Take a walk"}
  ],
  "edges": [
    {"from": "entry:entry-2", "to": "action:entry-2", "relation": "suggests_action"}
  ]
}
''',
      );

      final graph = update.toKnowledgeGraph();
      expect(graph.entryId, 'entry-2');
      expect(graph.nodes.map((node) => node.kind), contains('next_action'));
      expect(graph.edges.single.relation, 'suggests_action');
    });
  });

  group('LocalLlmService', () {
    late LocalLlmService service;

    setUp(() async {
      service = LocalLlmService(backend: StubLocalLlmBackend(chunkSize: 8));
      await service.loadModel(
        LocalLlmConfig.mobile(
          modelPath: '/tmp/stub-model-q4_k_m.gguf',
          requirePreferredQuantization: false,
        ),
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    test('streams token chunks from stub backend', () async {
      final tokens = await service
          .streamCompletion(
            const LocalLlmCompletionRequest(prompt: 'Summarize this entry.'),
          )
          .take(3)
          .toList();

      expect(tokens.join(), isNotEmpty);
      expect(tokens.first, isNotEmpty);
    });

    test('extractKnowledgeGraphUpdate returns structured graph', () async {
      final graph = await service.extractKnowledgeGraphUpdate(
        entryId: 'stub-entry',
        transcript: 'I keep agreeing when I mean to decline.',
      );

      expect(graph.entryId, 'stub-entry');
      expect(graph.nodes, isNotEmpty);
      expect(
        graph.nodes.any((node) => node.kind == 'theme'),
        isTrue,
      );
    });
  });
}
