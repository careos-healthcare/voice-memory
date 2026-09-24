import 'dart:typed_data';

import 'package:archiveme_mobile/core/ai/local_llm_service.dart';
import 'package:archiveme_mobile/core/database/benchmark_seeder_isolate.dart';
import 'package:archiveme_mobile/core/vectors/int8_quantizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline RAG summary stays on device and finishes under 2.5s', () async {
    final corpus = _corpus(1000);
    final remoteCalls = <String>[];
    final service = LocalInferenceService(
      onDevice: BoundLocalEngine(
        runtime: LocalRuntime.gguf,
        complete: (prompt) async => 'Walked to the river in warm light.',
      ),
      remote: (prompt) async {
        remoteCalls.add(prompt);
        return 'Remote summary.';
      },
      retrieve: (query) async {
        final vector = Float32List(benchmarkEmbeddingDimensions);
        fillBenchmarkVector(vector, query.hashCode.abs());
        return [
          for (final hit in corpus.search(vector, limit: 5))
            RetrievedPassage(
              entryId: 'entry-${hit.index}',
              text: 'Moment ${hit.index} near the river.',
              similarity: hit.similarity,
            ),
        ];
      },
    );

    final summary = await service.summarize(
      entryText: 'Walked to the river this morning. The light was warm.',
      query: 'river',
      higherPrecisionAvailable: true,
    );

    expect(summary.route, InferenceRoute.onDevice);
    expect(summary.runtimeName, 'gguf');
    expect(summary.elapsed, lessThan(const Duration(milliseconds: 2500)));
    expect(summary.passages, hasLength(5));
    expect(summary.text, contains('river'));
    expect(remoteCalls, isEmpty);
  });

  test(
    'remote model is used when the network and precision are available',
    () async {
      String? seenPrompt;
      final service = LocalInferenceService(
        onDevice: BoundLocalEngine(
          runtime: LocalRuntime.onnx,
          complete: (prompt) async => 'local',
        ),
        remote: (prompt) async {
          seenPrompt = prompt;
          return 'Remote summary.';
        },
        retrieve: (_) async => const [
          RetrievedPassage(
            entryId: 'entry-1',
            text: 'Coffee with Sam.',
            similarity: 0.9,
          ),
        ],
      );
      final summary = await service.summarize(
        entryText: 'Met Sam before work.',
        query: 'sam',
        networkAvailable: true,
        higherPrecisionAvailable: true,
      );

      expect(summary.route, InferenceRoute.remote);
      expect(summary.runtimeName, 'remote');
      expect(summary.text, 'Remote summary.');
      expect(summary.passages, hasLength(1));
      expect(seenPrompt, contains('Met Sam before work.'));
      expect(seenPrompt, contains('Coffee with Sam.'));
    },
  );

  test('extractive engine covers offline summaries without weights', () async {
    final service = LocalInferenceService(
      remote: (_) async => 'Remote summary.',
    );

    final summary = await service.summarize(
      entryText: 'Called mom after lunch. She laughed at the old story.',
      networkAvailable: true,
    );

    expect(summary.route, InferenceRoute.onDevice);
    expect(summary.runtimeName, 'extractive');
    expect(summary.elapsed, lessThan(const Duration(milliseconds: 2500)));
    expect(summary.text, contains('Called mom after lunch.'));
    expect(summary.text, contains('She laughed at the old story.'));
  });
}

Int8Corpus _corpus(int count) {
  final embeddings = <Int8Embedding>[];
  final values = Float32List(benchmarkEmbeddingDimensions);
  for (var index = 0; index < count; index++) {
    fillBenchmarkVector(values, index + 1);
    embeddings.add(quantizeSymmetric(values));
  }
  return Int8Corpus(embeddings);
}
