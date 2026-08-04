import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/features/ai_engines/on_device_extraction_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/ai/ai_cost_telemetry.dart';
import 'package:voicememory_mobile/services/ai/hybrid_ai_router.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late LocalSemanticStore semanticStore;
  late AiCostTelemetry telemetry;
  late HybridAiRouter router;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hybrid_ai_router_');
    semanticStore = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    telemetry = AiCostTelemetry();
    router = HybridAiRouter(
      onDevice: OnDeviceExtractionEngine(),
      semanticStore: semanticStore,
      telemetry: telemetry,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'tier one extracts and indexes locally without cloud invocation',
    () async {
      var cloudCalls = 0;
      final result = await router.execute(
        HybridAiRequest(
          operation: HybridAiOperation.entryIngestion,
          entry: _entry(
            'I promise to call Alex. I need to finish work because I feel anxious.',
          ),
          userInitiated: true,
        ),
        cloud: () async {
          cloudCalls++;
          return const HybridCloudResult(payload: 'unexpected');
        },
      );

      expect(result.tier, HybridAiTier.onDevice);
      expect(cloudCalls, 0);
      expect(result.localExtraction, isNotNull);
      final types = result.localExtraction!.graph.nodes
          .map((node) => node.type)
          .toSet();
      expect(
        types,
        containsAll([
          NodeType.promise,
          NodeType.actionItem,
          NodeType.emotion,
          NodeType.topic,
        ]),
      );
      expect(await semanticStore.count(), 1);
      final encrypted = await File('${root.path}/semantic.enc').readAsString();
      expect(encrypted, isNot(contains('Alex')));
      expect(encrypted, isNot(contains('finish work')));
      final metrics = await telemetry.snapshot();
      expect(metrics.localRequests, 1);
      expect(metrics.cloudRequests, 0);
      expect(metrics.estimatedTokensSaved, greaterThan(0));
    },
  );

  test('user initiated deep reasoning escalates to cloud', () async {
    var cloudCalls = 0;
    final result = await router.execute(
      const HybridAiRequest(
        operation: HybridAiOperation.crossTemporalReasoning,
        query: 'Compare my priorities across the last year',
        userInitiated: true,
      ),
      cloud: () async {
        cloudCalls++;
        return const HybridCloudResult(
          payload: 'deep result',
          inputTokens: 120,
          outputTokens: 80,
        );
      },
    );

    expect(result.tier, HybridAiTier.cloudEscalated);
    expect(result.cloudPayload, 'deep result');
    expect(cloudCalls, 1);
    final metrics = await telemetry.snapshot();
    expect(metrics.cloudRequests, 1);
    expect(metrics.estimatedCloudTokens, 200);
  });

  test('deep analysis does not escalate without explicit trigger', () async {
    var cloudCalls = 0;
    final result = await router.execute(
      const HybridAiRequest(
        operation: HybridAiOperation.monthlyLifeStorySynthesis,
        query: 'monthly synthesis',
      ),
      cloud: () async {
        cloudCalls++;
        return const HybridCloudResult();
      },
    );

    expect(result.tier, HybridAiTier.onDevice);
    expect(cloudCalls, 0);
    expect(result.localHits, isEmpty);
  });

  test(
    'offline deep request bypasses cloud and reports saved tokens',
    () async {
      await router.execute(
        HybridAiRequest(
          operation: HybridAiOperation.entryIngestion,
          entry: _entry('Work felt calm today.'),
        ),
      );
      var cloudCalls = 0;
      final result = await router.execute(
        const HybridAiRequest(
          operation: HybridAiOperation.complexSemanticSearch,
          query: 'When did work feel calm?',
          userInitiated: true,
          isOnline: false,
        ),
        cloud: () async {
          cloudCalls++;
          return const HybridCloudResult();
        },
      );

      expect(result.tier, HybridAiTier.offlineFallback);
      expect(cloudCalls, 0);
      expect(result.localHits, isNotEmpty);
      final metrics = await telemetry.snapshot();
      expect(metrics.localRequests, 2);
      expect(metrics.cloudRequests, 0);
      expect(metrics.localRequestRatio, 1);
      expect(metrics.estimatedTokensSaved, greaterThan(0));
    },
  );

  test('scheduled batches escalate only when marked scheduled', () {
    expect(
      router.shouldEscalate(
        const HybridAiRequest(
          operation: HybridAiOperation.scheduledBackgroundBatch,
        ),
      ),
      isFalse,
    );
    expect(
      router.shouldEscalate(
        const HybridAiRequest(
          operation: HybridAiOperation.scheduledBackgroundBatch,
          scheduled: true,
        ),
      ),
      isTrue,
    );
  });
}

JournalEntry _entry(String transcript) => JournalEntry(
  id: 'entry-${transcript.hashCode}',
  createdAt: DateTime.utc(2026, 7, 26),
  transcript: transcript,
  durationSeconds: 8,
  reflection: const Reflection(
    mood: '',
    emotionalIntensity: 0,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);
