import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:thermal/thermal.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/autonomous_muse/ui/triage_card_stack.dart';
import 'package:voicememory_mobile/features/data_ingestion/graph_ingestion_pipeline.dart';
import 'package:voicememory_mobile/features/data_ingestion/legacy_ingestion_store.dart';
import 'package:voicememory_mobile/features/data_ingestion/markdown_vault_parser.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';
import 'package:voicememory_mobile/services/p2p_mesh/anchor_compute_channel.dart';
import 'package:voicememory_mobile/services/p2p_mesh/mesh_state_reconciler.dart';
import 'package:voicememory_mobile/services/p2p_mesh/offload_policy_engine.dart';
import 'package:voicememory_mobile/services/p2p_mesh/task_router.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'E2EPipelineBenchmark sustains concurrent vault, CRDT, routing, and canvas load',
    () async {
      final benchmark = E2EPipelineBenchmark();
      final report = await benchmark.run();

      expect(report.ingestedNotes, 100);
      expect(report.crdtDeltasApplied, 200);
      expect(report.offloadedTasks, greaterThan(0));
      expect(report.localTasks, greaterThan(0));
      expect(report.deferredTasks, greaterThan(0));
      expect(
        report.maximumSqliteWriteLatency,
        lessThan(const Duration(milliseconds: 50)),
      );
      expect(report.memoryOverheadBytes, lessThan(128 * 1024 * 1024));
      expect(report.simulatedFramesPerSecond, greaterThanOrEqualTo(59));
      expect(
        report.maximumEventLoopFrameLatency,
        lessThan(const Duration(milliseconds: 50)),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

final class E2EPipelineBenchmarkReport {
  const E2EPipelineBenchmarkReport({
    required this.ingestedNotes,
    required this.crdtDeltasApplied,
    required this.localTasks,
    required this.offloadedTasks,
    required this.deferredTasks,
    required this.maximumSqliteWriteLatency,
    required this.memoryOverheadBytes,
    required this.simulatedFramesPerSecond,
    required this.maximumEventLoopFrameLatency,
  });

  final int ingestedNotes;
  final int crdtDeltasApplied;
  final int localTasks;
  final int offloadedTasks;
  final int deferredTasks;
  final Duration maximumSqliteWriteLatency;
  final int memoryOverheadBytes;
  final double simulatedFramesPerSecond;
  final Duration maximumEventLoopFrameLatency;
}

final class E2EPipelineBenchmark {
  static const _frameCount = 120;

  Future<E2EPipelineBenchmarkReport> run() async {
    final root = await Directory.systemTemp.createTemp('e2e-pipeline-bench-');
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final codec = EncryptedSqliteTextCodec(() => Uint8List.fromList(key));
    final sqliteLatencies = <Duration>[];
    final sourceDatabase = sqlite3.openInMemory();
    final targetDatabase = sqlite3.openInMemory();
    final backlogDatabase = sqlite3.openInMemory();
    final sourceCrdtStore = SqliteMeshCrdtStore(
      database: sourceDatabase,
      codec: codec,
      ownsDatabase: true,
    );
    final targetCrdtStore = SqliteMeshCrdtStore(
      database: targetDatabase,
      codec: codec,
      ownsDatabase: true,
    );
    final backlog = EncryptedComputeBacklog(
      database: backlogDatabase,
      codec: codec,
      ownsDatabase: true,
    );
    final policy = OffloadPolicyEngine.forTesting();
    LegacyIngestionStore? ingestionStore;
    PersonalKnowledgeGraphStore? graphStore;
    GraphIngestionPipeline? pipeline;
    final rssBefore = ProcessInfo.currentRss;

    try {
      await _writeVault(root);
      final vectors = await SqliteVecVectorStore.open(
        databasePath: '${root.path}/vectors.sqlite3',
        dimensions: 4,
      );
      ingestionStore = await LegacyIngestionStore.open(
        databasePath: '${root.path}/legacy.sqlite3',
        codec: codec,
        vectorStore: vectors,
      );
      graphStore = PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('${root.path}/graph.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(seedKey: key),
        ),
      );
      pipeline = GraphIngestionPipeline(
        parser: const MarkdownVaultParser(),
        store: ingestionStore,
        graphStore: graphStore,
        embeddingGenerator: const _BenchmarkEmbeddingGenerator(),
        noteBatchSize: 5,
      );
      var lastCumulativeWrite = Duration.zero;
      final progressSubscription = pipeline.progress.listen((progress) {
        if (progress.phase != GraphIngestionPhase.inserting) return;
        final batchWrite = progress.sqliteWriteTime - lastCumulativeWrite;
        lastCumulativeWrite = progress.sqliteWriteTime;
        if (batchWrite > Duration.zero) sqliteLatencies.add(batchWrite);
      });

      final source = MeshStateReconciler(
        deviceId: 'benchmark-anchor',
        store: sourceCrdtStore,
      );
      final target = MeshStateReconciler(
        deviceId: 'benchmark-edge',
        store: targetCrdtStore,
      );
      policy
        ..updateBattery(level: 65, state: BatteryState.discharging)
        ..updateConnectivity(const [ConnectivityResult.wifi])
        ..updateAnchorPing(const Duration(milliseconds: 35), connected: true)
        ..updateThermalStatus(ThermalStatus.none);
      final taskRouter = TaskRouter(
        policy: policy,
        backlog: backlog,
        delegate:
            ({
              required AnchorComputeJobKind kind,
              required Map<String, dynamic> payload,
              Duration timeout = const Duration(seconds: 45),
            }) async {
              await Future<void>.delayed(Duration.zero);
              return {'summary': 'anchor:${payload['text']}'};
            },
      );

      var crdtApplied = 0;
      var localTasks = 0;
      var offloadedTasks = 0;
      var deferredTasks = 0;
      final ingestionFuture = pipeline.ingestDirectory(root);
      final crdtFuture = () async {
        final deltas = <MeshCrdtDelta>[];
        for (var index = 0; index < 100; index++) {
          final watch = Stopwatch()..start();
          deltas
            ..add(
              source.write(
                kind: MeshCrdtEntityKind.graphNode,
                entityId: 'node-$index',
                payload: {'id': 'node-$index', 'label': 'Memory $index'},
              ),
            )
            ..add(
              source.write(
                kind: MeshCrdtEntityKind.vectorMetadata,
                entityId: 'vector-$index',
                payload: {'entryId': 'node-$index', 'dimensions': 4},
              ),
            );
          watch.stop();
          sqliteLatencies.add(watch.elapsed);
          if (index % 5 == 0) await Future<void>.delayed(Duration.zero);
        }
        for (var offset = 0; offset < deltas.length; offset += 10) {
          final watch = Stopwatch()..start();
          final result = target.merge(deltas.sublist(offset, offset + 10));
          watch.stop();
          sqliteLatencies.add(watch.elapsed);
          crdtApplied += result.applied;
          await Future<void>.delayed(Duration.zero);
        }
      }();
      final routingFuture = () async {
        for (var index = 0; index < 60; index++) {
          if (index == 20) {
            policy.updateThermalStatus(ThermalStatus.severe);
          } else if (index == 30) {
            policy.updateThermalStatus(ThermalStatus.light);
          }
          final result = await taskRouter.submit<String>(
            kind: RoutedComputeKind.llama,
            payload: {'text': 'Summarize memory $index'},
            runLocal: () async {
              await Future<void>.delayed(Duration.zero);
              return 'local:$index';
            },
            decodeRemote: (value) => value['summary'] as String,
          );
          switch (result.disposition) {
            case TaskRouteDisposition.local:
              localTasks++;
            case TaskRouteDisposition.offloaded:
              offloadedTasks++;
            case TaskRouteDisposition.deferred:
              deferredTasks++;
          }
        }
      }();

      GraphIngestionResult? ingestion;
      Object? workError;
      StackTrace? workStackTrace;
      var workCompleted = false;
      unawaited(
        Future.wait<void>([
              ingestionFuture.then<void>((value) {
                ingestion = value;
              }),
              crdtFuture,
              routingFuture,
            ])
            .then<void>((_) {
              workCompleted = true;
            })
            .catchError((Object error, StackTrace stackTrace) {
              workError = error;
              workStackTrace = stackTrace;
              workCompleted = true;
            }),
      );
      var maximumFrameLatency = Duration.zero;
      var totalCanvasRenderTime = Duration.zero;
      var renderedFrames = 0;
      final workDeadline = Stopwatch()..start();
      while (renderedFrames < _frameCount || !workCompleted) {
        if (workDeadline.elapsed >= const Duration(seconds: 30)) {
          fail('Concurrent benchmark work exceeded the 30-second deadline.');
        }
        final eventLoopWatch = Stopwatch()..start();
        await Future<void>.delayed(const Duration(milliseconds: 1));
        final paintWatch = Stopwatch()..start();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        BridgeMiniGraphPainter(
          confidence: .75 + ((renderedFrames % 20) / 100),
        ).paint(canvas, const Size(700, 78));
        final picture = recorder.endRecording();
        picture.dispose();
        paintWatch.stop();
        totalCanvasRenderTime += paintWatch.elapsed;
        eventLoopWatch.stop();
        if (eventLoopWatch.elapsed > maximumFrameLatency) {
          maximumFrameLatency = eventLoopWatch.elapsed;
        }
        renderedFrames++;
      }
      if (workError != null) {
        Error.throwWithStackTrace(workError!, workStackTrace!);
      }
      await progressSubscription.cancel();

      final memoryOverhead = math.max(0, ProcessInfo.currentRss - rssBefore);
      final renderSeconds = math.max(
        totalCanvasRenderTime.inMicroseconds / Duration.microsecondsPerSecond,
        .000001,
      );
      return E2EPipelineBenchmarkReport(
        ingestedNotes: ingestion!.insertedNotes,
        crdtDeltasApplied: crdtApplied,
        localTasks: localTasks,
        offloadedTasks: offloadedTasks,
        deferredTasks: deferredTasks,
        maximumSqliteWriteLatency: sqliteLatencies.reduce(
          (left, right) => left > right ? left : right,
        ),
        memoryOverheadBytes: memoryOverhead,
        simulatedFramesPerSecond: renderedFrames / renderSeconds,
        maximumEventLoopFrameLatency: maximumFrameLatency,
      );
    } finally {
      await pipeline?.dispose();
      await graphStore?.dispose();
      ingestionStore?.close();
      sourceCrdtStore.close();
      targetCrdtStore.close();
      backlog.close();
      await policy.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    }
  }

  Future<void> _writeVault(Directory root) async {
    for (var index = 0; index < 100; index++) {
      final next = index < 99 ? '\nSee [[Memory ${index + 1}]].' : '';
      await File('${root.path}/Memory $index.md').writeAsString('''
---
title: Memory $index
tags: [benchmark, local-first]
created: 2026-07-29
---
This is encrypted benchmark memory $index with enough text to embed.$next
''');
    }
  }
}

final class _BenchmarkEmbeddingGenerator implements MarkdownEmbeddingGenerator {
  const _BenchmarkEmbeddingGenerator();

  @override
  int get dimensions => 4;

  @override
  Future<List<Float32List>> embedBatch(List<String> texts) async {
    await Future<void>.delayed(Duration.zero);
    return [
      for (var index = 0; index < texts.length; index++)
        Float32List.fromList([1, index / 10, .5, .25]),
    ];
  }
}
