import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/vector_store.dart';
import 'package:archiveme_mobile/core/llm/llm_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'TurboQuant statement is attempted and a missing extension is ignored',
    () async {
      expect(
        VectorStore.turboQuantStatement,
        "SELECT vector_quantize('embeddings', 'embedding', 'qtype=TURBO,qbits=4')",
      );
      final db = await databaseFactory.openDatabase(
        '${Directory.systemTemp.path}/vector_store_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final report = await VectorStore.initialize(db);
      expect(report.anyApplied, isFalse);
      expect(report.applied['embeddings'], isFalse);
      expect(VectorStore.simdInMemoryScan, isTrue);
      await db.close();
    },
  );

  test('SIMD scan keeps the nearest vector inside the memory budget', () {
    final hits = VectorStore.scan(
      query: Float32List.fromList(const [1, 0, 0, 0]),
      rows: [
        VectorStoreRow(
          id: 'far',
          values: Float32List.fromList(const [0, 1, 0, 0]),
        ),
        VectorStoreRow(
          id: 'near',
          values: Float32List.fromList(const [1, 0, 0, 0]),
        ),
      ],
    );
    expect(hits.first.id, 'near');
    expect(hits.first.score, closeTo(1, 0.001));
  });

  test('extraction stays local and summaries use a valid key', () async {
    final router = LlmRouter(
      local: (prompt) async => 'local:$prompt',
      cloud: (_, prompt) async => 'cloud:$prompt',
      settings: const CloudByokSettings(
        enabled: true,
        provider: CloudByokProvider.openAi,
        apiKey: 'sk-test-key',
      ),
    );

    final extracted = await router.run(
      workload: LlmWorkload.extraction,
      prompt: 'Met Ada at Harbor',
    );
    expect(extracted.target, LlmExecutionTarget.localOffline);
    expect(extracted.text, 'local:Met Ada at Harbor');

    final summary = await router.run(
      workload: LlmWorkload.longitudinalGraphSummary,
      prompt: 'Ada and Harbor over the year',
    );
    expect(summary.target, LlmExecutionTarget.cloudByok);
    expect(summary.text, contains('Ada and Harbor'));
  });

  test('a missing key and a failed cloud call stay on the device', () async {
    final disabled = LlmRouter(
      local: (prompt) async => 'local',
      settings: const CloudByokSettings(
        enabled: true,
        provider: CloudByokProvider.claude,
        apiKey: '   ',
      ),
    );
    expect(
      disabled.targetFor(LlmWorkload.longitudinalGraphSummary),
      LlmExecutionTarget.localOffline,
    );

    final failing = LlmRouter(
      local: (prompt) async => 'local summary',
      cloud: (_, _) async => throw StateError('offline'),
      settings: const CloudByokSettings(
        enabled: true,
        provider: CloudByokProvider.custom,
        apiKey: 'custom-key',
      ),
    );
    expect(
      failing.targetFor(LlmWorkload.longitudinalGraphSummary),
      LlmExecutionTarget.localOffline,
    );

    final fallback = LlmRouter(
      local: (prompt) async => 'local summary',
      cloud: (_, _) async => throw StateError('offline'),
      settings: CloudByokSettings(
        enabled: true,
        provider: CloudByokProvider.custom,
        apiKey: 'custom-key',
        endpoint: Uri.https('example.test', '/v1'),
      ),
    );
    final result = await fallback.run(
      workload: LlmWorkload.longitudinalGraphSummary,
      prompt: 'graph',
    );
    expect(result.fellBack, isTrue);
    expect(result.target, LlmExecutionTarget.localOffline);
    expect(result.text, 'local summary');
  });
}
