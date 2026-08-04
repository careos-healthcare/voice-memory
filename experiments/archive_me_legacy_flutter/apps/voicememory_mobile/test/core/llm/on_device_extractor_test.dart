import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/llm/on_device_extractor.dart';
import 'package:voicememory_mobile/core/llm/semantic_extraction_result.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/local_capture_context.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  group('CompactQuantizedLocalInferenceDriver', () {
    test(
      'discovers entities, sentiment, and directional relations locally',
      () {
        const driver = CompactQuantizedLocalInferenceDriver();

        final result = driver.infer(
          'I met Alice influences my meeting roadmap. I am happy and proud.',
        );

        expect(
          result.entities.any((item) => item.type == SemanticEntityType.person),
          isTrue,
        );
        expect(
          result.entities.any((item) => item.type == SemanticEntityType.event),
          isTrue,
        );
        expect(result.sentiment, greaterThan(0));
        expect(
          result.entities.every(
            (entity) => entity.sentiment >= -1 && entity.sentiment <= 1,
          ),
          isTrue,
        );
        expect(result.relations.single.type, SemanticRelationType.influences);
        expect(result.relations.single.isDirected, isTrue);
        expect(result.inferenceDriver, contains('int8'));
        expect(result.usedFallback, isFalse);
      },
    );

    test('is synchronous and has no network or platform dependency', () {
      const driver = CompactQuantizedLocalInferenceDriver();

      final result = driver.infer('I am worried about missing the deadline.');

      expect(result, isA<SemanticExtractionResult>());
      expect(result.sentiment, lessThan(0));
    });

    test('emits exact UTF-16 offsets after emoji', () {
      const text = '🙂 I met Alice.';
      final entity = const CompactQuantizedLocalInferenceDriver()
          .infer(text)
          .entities
          .singleWhere((item) => item.type == SemanticEntityType.person);

      expect(entity.startUtf16, 5);
      expect(entity.endUtf16, text.length - 1);
      expect(
        text.substring(entity.startUtf16, entity.endUtf16),
        entity.excerpt,
      );
      expect(entity.excerpt, 'met Alice');
    });
  });

  group('OnDeviceSemanticExtractor fallback', () {
    test('preserves rule extraction when primary is unavailable', () {
      const extractor = OnDeviceSemanticExtractor(
        driver: UnavailableQuantizedSemanticInferenceDriver(),
      );

      final rich = extractor.extractSemantic(
        text: 'I want to finish the book. I remember summer camp.',
      );
      final graph = extractor.extract(
        text: 'I want to finish the book. I remember summer camp.',
      );

      expect(rich.usedFallback, isTrue);
      expect(rich.entities.single.type, SemanticEntityType.goal);
      expect(graph.entities.any((item) => item.type == NodeType.goal), isTrue);
      expect(
        graph.entities.any((item) => item.type == NodeType.memory),
        isTrue,
      );
    });

    test('falls back after primary failure', () {
      const extractor = OnDeviceSemanticExtractor(driver: _ThrowingDriver());

      final result = extractor.extractSemantic(
        text: 'I believe that kindness matters.',
      );

      expect(result.usedFallback, isTrue);
      expect(result.entities.single.type, SemanticEntityType.belief);
    });

    test('merges low-confidence primary output with rule output', () {
      const extractor = OnDeviceSemanticExtractor(
        driver: _LowConfidenceDriver(),
      );

      final result = extractor.extractSemantic(
        text: 'I want to finish the book.',
      );

      expect(result.usedFallback, isTrue);
      expect(
        result.entities.map((item) => item.type),
        containsAll([SemanticEntityType.person, SemanticEntityType.goal]),
      );
    });
  });

  group('OnDeviceSemanticExtractor async inference', () {
    test('selects a ready async session and merges local extraction', () async {
      final session = _AsyncSession(result: _asyncResult(confidence: 0.9));
      final extractor = OnDeviceSemanticExtractor(asyncSession: session);

      final result = await extractor.extractSemanticAsync(
        text: 'I want to finish the book.',
      );

      expect(session.calls, 1);
      expect(result.usedFallback, isFalse);
      expect(result.inferenceDriver, 'async-fixture');
      expect(
        result.entities.map((item) => item.type),
        containsAll([SemanticEntityType.person, SemanticEntityType.goal]),
      );
    });

    test(
      'rejects async excerpts with missing, wrong, or repaired offsets',
      () async {
        const text = '🙂 I want to finish the book.';
        final result = await OnDeviceSemanticExtractor(
          asyncSession: _AsyncSession(
            result: SemanticExtractionResult(
              entities: [
                SemanticEntity(
                  type: SemanticEntityType.person,
                  label: 'Alice',
                  confidence: 0.9,
                  excerpt: 'i want',
                  startUtf16: 3,
                  endUtf16: 9,
                ),
                SemanticEntity(
                  type: SemanticEntityType.person,
                  label: 'Bob',
                  confidence: 0.9,
                  excerpt: '🙂',
                ),
              ],
              sentiment: 0,
              confidence: 0.9,
              inferenceDriver: 'invalid-offset-fixture',
            ),
          ),
        ).extractSemanticAsync(text: text);

        expect(
          result.entities.any((item) => item.type == SemanticEntityType.person),
          isFalse,
        );
        expect(result.usedFallback, isTrue);
      },
    );

    test('falls back when async session is unavailable or throws', () async {
      final unavailable = _AsyncSession(
        isReady: false,
        result: _asyncResult(confidence: 0.9),
      );
      final throwing = _AsyncSession(error: StateError('failure'));

      for (final session in [unavailable, throwing]) {
        final result = await OnDeviceSemanticExtractor(
          asyncSession: session,
        ).extractSemanticAsync(text: 'I believe that kindness matters.');
        expect(result.usedFallback, isTrue);
        expect(result.entities.single.type, SemanticEntityType.belief);
      }
      expect(unavailable.calls, 0);
      expect(throwing.calls, 1);
    });

    test('falls back on timeout, invalid output, and low confidence', () async {
      final timeout = _AsyncSession(completer: Completer());
      final timedOut = await OnDeviceSemanticExtractor(
        asyncSession: timeout,
        asyncInferenceTimeout: const Duration(milliseconds: 5),
      ).extractSemanticAsync(text: 'I want to finish the book.');
      final invalid = await OnDeviceSemanticExtractor(
        asyncSession: _AsyncSession(result: _invalidAsyncResult()),
      ).extractSemanticAsync(text: 'I want to finish the book.');
      final lowConfidence = await OnDeviceSemanticExtractor(
        asyncSession: _AsyncSession(result: _asyncResult(confidence: 0.2)),
      ).extractSemanticAsync(text: 'I want to finish the book.');

      expect(timedOut.usedFallback, isTrue);
      expect(timedOut.entities.single.type, SemanticEntityType.goal);
      expect(invalid.usedFallback, isTrue);
      expect(invalid.entities.single.type, SemanticEntityType.goal);
      expect(lowConfidence.usedFallback, isTrue);
      expect(
        lowConfidence.entities.map((item) => item.type),
        containsAll([SemanticEntityType.person, SemanticEntityType.goal]),
      );
    });

    test('extractAsync retains local capture context', () async {
      final graph =
          await OnDeviceSemanticExtractor(
            asyncSession: _AsyncSession(result: _asyncResult(confidence: 0.9)),
          ).extractAsync(
            text: 'I want to finish the book.',
            localCaptureContext: LocalCaptureContext(
              capturedAt: DateTime.utc(2026, 7, 23),
              locationLabel: 'Central Library',
              calendarEventName: 'Writing Circle',
            ),
          );

      expect(
        graph.entities.any(
          (entity) =>
              entity.type == NodeType.place &&
              entity.label == 'Central Library',
        ),
        isTrue,
      );
      expect(
        graph.entities.any(
          (entity) =>
              entity.type == NodeType.event && entity.label == 'Writing Circle',
        ),
        isTrue,
      );
    });
  });

  test('semantic DTOs clamp values and round-trip immutable JSON', () {
    final original = SemanticExtractionResult(
      entities: [
        SemanticEntity(
          type: SemanticEntityType.person,
          label: ' Alice ',
          confidence: 4,
          sentiment: -4,
          excerpt: ' met Alice ',
          startUtf16: 0,
          endUtf16: ' met Alice '.length,
        ),
      ],
      relations: [
        SemanticRelation(
          type: SemanticRelationType.triggeredBy,
          sourceType: SemanticEntityType.fear,
          sourceLabel: 'Public speaking',
          targetType: SemanticEntityType.event,
          targetLabel: 'Conference',
          weight: -3,
          excerpt: 'fear triggered by conference',
          startUtf16: 0,
          endUtf16: 'fear triggered by conference'.length,
        ),
      ],
      sentiment: 9,
      confidence: -2,
      inferenceDriver: 'fixture',
      usedFallback: true,
    );

    final decoded = SemanticExtractionResult.fromJson(original.toJson());

    expect(decoded.sentiment, 1);
    expect(decoded.confidence, 0);
    expect(decoded.entities.single.confidence, 1);
    expect(decoded.entities.single.sentiment, -1);
    expect(decoded.relations.single.weight, 0);
    expect(decoded.entities.single.label, 'Alice');
    expect(decoded.toJson(), original.toJson());
    expect(
      () => decoded.entities.add(
        SemanticEntity(
          type: SemanticEntityType.place,
          label: 'Rome',
          confidence: 1,
          excerpt: 'Rome',
          startUtf16: 0,
          endUtf16: 4,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('default graph ingestion and transcription alias retain evidence', () {
    final entry = _entry(
      'entry-1',
      DateTime.utc(2026, 7, 23),
      'I met Alice. I want to finish the book.',
    );
    final engine = PersonalKnowledgeGraphEngine();

    final direct = engine.ingest(entry);
    final aliased = engine.ingestTranscription(entry);
    final incremental = engine.ingestTranscription(entry, into: direct);

    expect(direct.toJson(), aliased.toJson());
    expect(direct.nodes.any((node) => node.type == NodeType.person), isTrue);
    expect(direct.nodes.any((node) => node.type == NodeType.goal), isTrue);
    expect(incremental.nodes.first.evidence.single.entryId, entry.id);
    expect(incremental.nodes.first.evidence.single.observedAt, entry.createdAt);
  });
}

class _ThrowingDriver implements QuantizedSemanticInferenceDriver {
  const _ThrowingDriver();

  @override
  String get identifier => 'throwing-fixture';

  @override
  bool get isAvailable => true;

  @override
  SemanticExtractionResult infer(String text) => throw StateError('failure');
}

class _LowConfidenceDriver implements QuantizedSemanticInferenceDriver {
  const _LowConfidenceDriver();

  @override
  String get identifier => 'low-confidence-fixture';

  @override
  bool get isAvailable => true;

  @override
  SemanticExtractionResult infer(String text) => SemanticExtractionResult(
    entities: [
      SemanticEntity(
        type: SemanticEntityType.person,
        label: 'Alice',
        confidence: 0.2,
        excerpt: 'I want to finish the book.',
        startUtf16: 0,
        endUtf16: 26,
      ),
    ],
    sentiment: 0,
    confidence: 0.2,
    inferenceDriver: identifier,
  );
}

class _AsyncSession implements AsyncSemanticInferenceSession {
  _AsyncSession({this.isReady = true, this.result, this.error, this.completer});

  @override
  final bool isReady;
  final SemanticExtractionResult? result;
  final Object? error;
  final Completer<SemanticExtractionResult>? completer;
  int calls = 0;

  @override
  Future<SemanticExtractionResult> infer(String text) {
    calls += 1;
    if (error != null) return Future.error(error!);
    if (completer != null) return completer!.future;
    return Future.value(result);
  }
}

SemanticExtractionResult _asyncResult({required double confidence}) =>
    SemanticExtractionResult(
      entities: [
        SemanticEntity(
          type: SemanticEntityType.person,
          label: 'Alice',
          confidence: confidence,
          excerpt: 'I want to finish the book.',
          startUtf16: 0,
          endUtf16: 26,
        ),
      ],
      sentiment: 0.25,
      confidence: confidence,
      inferenceDriver: 'async-fixture',
    );

SemanticExtractionResult _invalidAsyncResult() => SemanticExtractionResult(
  entities: [
    SemanticEntity(
      type: SemanticEntityType.person,
      label: '',
      confidence: 0.9,
      excerpt: 'invalid',
      startUtf16: 0,
      endUtf16: 7,
    ),
  ],
  sentiment: 0,
  confidence: 0.9,
  inferenceDriver: 'invalid-async-fixture',
);

JournalEntry _entry(String id, DateTime createdAt, String transcript) =>
    JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript: transcript,
      durationSeconds: 1,
      reflection: const Reflection(
        mood: '',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
