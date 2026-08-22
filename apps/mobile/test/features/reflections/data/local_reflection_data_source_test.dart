import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_output_parser.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_transcript_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReflectionTranscriptProcessor', () {
    test('buildInputTensor produces fixed-length tensor', () {
      final tensor = ReflectionTranscriptProcessor.buildInputTensor(
        'I want rest but I keep accepting more work tomorrow.',
      );
      expect(tensor.length, ReflectionTranscriptProcessor.tensorElementCount);
      expect(tensor.any((value) => value > 0), isTrue);
    });

    test('detectTensionSpan finds contrast markers', () {
      final span = ReflectionTranscriptProcessor.detectTensionSpan(
        'I want rest but I keep accepting more work.',
      );
      expect(span, isNotNull);
      expect(span!.end, greaterThan(span.start));
    });
  });

  group('ReflectionOutputParser', () {
    test('maps logits into ReflectionDto with tension and action fields', () {
      final logits = List<double>.filled(512, 0);
      logits[16] = 2.5; // intensity
      logits[0] = 3; // mood calm
      logits[17] = 0.9; // work theme

      final transcript =
          'I want rest but I keep saying yes to more work. '
          'Tomorrow I will block thirty minutes offline.';

      final reflection = ReflectionOutputParser.toReflectionDto(
        transcript: transcript,
        logits: logits,
      );

      expect(reflection.mood, 'calm');
      expect(reflection.emotionalIntensity, inInclusiveRange(1, 10));
      expect(reflection.recurringThemes, contains('work'));
      expect(reflection.tensionOrContradiction, isNotNull);
      expect(reflection.nextSmallAction, isNotNull);
    });

    test('buildKnowledgeGraph wires tension and action nodes', () {
      final reflection = ReflectionOutputParser.toReflectionDto(
        transcript:
            'I say I am fine but I feel lonely. I need to text my friend tomorrow.',
        logits: List<double>.filled(512, 0),
      );

      final graph = ReflectionOutputParser.buildKnowledgeGraph(
        entryId: 'entry-1',
        reflection: reflection,
      );

      expect(graph.tensionOrContradiction, isNotNull);
      expect(graph.nextSmallAction, isNotNull);
      expect(
        graph.edges.map((edge) => edge.relation),
        containsAll(['has_tension', 'suggests_action']),
      );
      expect(graph.nodes.any((node) => node.kind == 'tension'), isTrue);
      expect(graph.nodes.any((node) => node.kind == 'next_action'), isTrue);
    });
  });

  group('LocalReflectionDataSource', () {
    test('heuristic inference returns graph edges for offline knowledge', () async {
      final source = await LocalReflectionDataSource.create();
      final result = await source.inferFromTranscript(
        entryId: 'offline-entry',
        transcript:
            'Work has been heavy but I keep taking on more. '
            'Tomorrow I will leave on time and rest.',
      );

      expect(result.usedOnnx, isFalse);
      expect(result.reflection.mood, isNotEmpty);
      expect(result.knowledgeGraph.entryId, 'offline-entry');
      expect(result.knowledgeGraph.tensionOrContradiction, isNotNull);
      expect(result.knowledgeGraph.nextSmallAction, isNotNull);
      expect(result.knowledgeGraph.edges, isNotEmpty);
    });

    test('rejects very short transcripts', () async {
      final source = await LocalReflectionDataSource.create();
      expect(
        () => source.inferFromTranscript(
          entryId: 'e',
          transcript: 'hi',
        ),
        throwsArgumentError,
      );
    });
  });
}
