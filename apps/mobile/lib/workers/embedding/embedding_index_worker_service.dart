import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/search/local_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/onnx_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_embedding_text.dart';
import 'package:archiveme_mobile/services/thermal_throttling/thermal_throttling_service.dart';
import 'package:archiveme_mobile/storage/sqlite/embedding_deferred_queue_store.dart';
import 'package:archiveme_mobile/storage/sqlite/isolate_safe_sqlite_database_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/entry_edges_worker_store.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_embedding_vector_search.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_embedding_worker_store.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_014_embedding_deferred_queue.dart';
import 'package:archiveme_mobile/workers/isolate_worker_client.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// Operations handled by [EmbeddingIndexWorkerService].
abstract final class EmbeddingIndexWorkerOperations {
  EmbeddingIndexWorkerOperations._();

  static const indexReflection = 'indexReflection';
  static const indexTranscript = 'indexTranscript';
  static const automateGraphForEntry = 'automateGraphForEntry';
  static const shutdown = 'shutdown';
}

/// Worker payload returned after automated graph building for one entry.
final class AutomateGraphWorkerResult {
  const AutomateGraphWorkerResult({
    required this.embeddingStored,
    required this.similarEntries,
    required this.edgesStored,
  });

  final bool embeddingStored;
  final List<VectorSearchHit> similarEntries;
  final int edgesStored;

  factory AutomateGraphWorkerResult.fromJson(Map<String, dynamic> json) {
    final rawHits = json['similarEntries'] as List<dynamic>? ?? const [];
    return AutomateGraphWorkerResult(
      embeddingStored: json['embeddingStored'] as bool? ?? false,
      edgesStored: json['edgesStored'] as int? ?? 0,
      similarEntries: rawHits
          .map((hit) {
            if (hit is! Map) return null;
            final entryId = hit['entryId'] as String? ?? '';
            if (entryId.isEmpty) return null;
            return VectorSearchHit(
              entryId: entryId,
              cosineSimilarity:
                  (hit['cosineSimilarity'] as num?)?.toDouble() ?? 0,
            );
          })
          .whereType<VectorSearchHit>()
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'embeddingStored': embeddingStored,
    'edgesStored': edgesStored,
    'similarEntries': similarEntries
        .map(
          (hit) => {
            'entryId': hit.entryId,
            'cosineSimilarity': hit.cosineSimilarity,
          },
        )
        .toList(growable: false),
  };
}

/// Persistent worker isolate for ONNX embedding + SQLite vector upserts.
class EmbeddingIndexWorkerService implements PersistentIsolateWorkerClient {
  EmbeddingIndexWorkerService._();

  static final EmbeddingIndexWorkerService instance =
      EmbeddingIndexWorkerService._();

  static bool get _isFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  SendPort? workerPort;
  @override
  ReceivePort? responsePort;
  @override
  StreamSubscription<dynamic>? responseSubscription;
  @override
  Isolate? isolate;
  @override
  Future<void>? starting;
  @override
  int nextRequestId = 1;
  @override
  final pending = <int, Completer<Object?>>{};
  @override
  final streamPending = <int, StreamController<Object?>>{};

  String? _defaultKeyAlias;
  ThermalThrottlingService? _thermalThrottling;
  EmbeddingDeferredQueueStore? _deferredQueue;

  bool get isRunning => workerPort != null || _testRuntime != null;

  _EmbeddingIndexWorkerRuntime? _testRuntime;

  void configure({
    String? defaultKeyAlias,
    ThermalThrottlingService? thermalThrottling,
    EmbeddingDeferredQueueStore? deferredQueue,
  }) {
    _defaultKeyAlias = defaultKeyAlias;
    if (thermalThrottling != null) {
      _thermalThrottling = thermalThrottling;
    }
    _deferredQueue = deferredQueue;
  }

  @override
  Future<void> ensureStarted() {
    if (_isFlutterTest) {
      _testRuntime ??= _EmbeddingIndexWorkerRuntime(
        defaultKeyAlias: _defaultKeyAlias,
      );
      return Future<void>.value();
    }
    if (workerPort != null) {
      return Future<void>.value();
    }
    return starting ??= spawnWorker(
      entryPoint: embeddingIndexWorkerIsolateEntry,
      startup: IsolateWorkerStartup(
        handshakePort: ReceivePort().sendPort,
        clientResponsePort: ReceivePort().sendPort,
        initializeTestFfi: _isFlutterTest,
        rootIsolateToken: _isFlutterTest ? null : RootIsolateToken.instance,
        defaultKeyAlias: _defaultKeyAlias,
      ),
    );
  }

  @override
  Future<void> spawnWorker({
    required void Function(IsolateWorkerStartup startup) entryPoint,
    required IsolateWorkerStartup startup,
  }) {
    final handshakePort = ReceivePort();
    final responsePort = ReceivePort();
    final resolvedStartup = IsolateWorkerStartup(
      handshakePort: handshakePort.sendPort,
      clientResponsePort: responsePort.sendPort,
      initializeTestFfi: startup.initializeTestFfi,
      rootIsolateToken: startup.rootIsolateToken,
      defaultKeyAlias: _defaultKeyAlias,
    );
    return spawnWorkerImpl(
      entryPoint: entryPoint,
      startup: resolvedStartup,
    );
  }

  Future<bool> indexReflection({
    required String filePath,
    required String entryId,
    required String text,
    required String contentHash,
    String? encryptionPassword,
    String? keyAlias,
  }) async {
    if (await _shouldDeferEmbedding(
      filePath: filePath,
      keyAlias: keyAlias ?? _defaultKeyAlias,
    )) {
      await _deferReflection(
        filePath: filePath,
        entryId: entryId,
        text: text,
        contentHash: contentHash,
        keyAlias: keyAlias ?? _defaultKeyAlias,
        encryptionPassword: encryptionPassword,
      );
      return false;
    }

    return _dispatchIndexReflection(
      filePath: filePath,
      entryId: entryId,
      text: text,
      contentHash: contentHash,
      encryptionPassword: encryptionPassword,
      keyAlias: keyAlias,
    );
  }

  /// Indexes a compressed local-LLM journal summary into transcript vector storage.
  ///
  /// Raw STT ramble is never embedded — callers must pass the structured summary
  /// produced by [LocalLlmWorkerService] / [AudioStructuringService].
  Future<bool> indexTranscript({
    required String filePath,
    required String entryId,
    required String llmSummary,
    String? encryptionPassword,
    String? keyAlias,
  }) async {
    final trimmedSummary = llmSummary.trim();
    if (trimmedSummary.length < ReflectionTextProcessor.minTextChars) {
      return false;
    }

    if (await _shouldDeferEmbedding(
      filePath: filePath,
      keyAlias: keyAlias ?? _defaultKeyAlias,
    )) {
      await _deferLlmSummary(
        filePath: filePath,
        entryId: entryId,
        llmSummary: trimmedSummary,
        keyAlias: keyAlias ?? _defaultKeyAlias,
        encryptionPassword: encryptionPassword,
      );
      return false;
    }

    return _dispatchIndexTranscript(
      filePath: filePath,
      entryId: entryId,
      llmSummary: trimmedSummary,
      encryptionPassword: encryptionPassword,
      keyAlias: keyAlias,
    );
  }

  /// Processes deferred embedding tasks once battery/charging constraints allow.
  Future<int> flushDeferredQueue() async {
    final store = _deferredQueue;
    final throttling = _thermalThrottling ?? ThermalThrottlingService();
    if (store == null || await throttling.shouldDeferEmbeddingWork()) {
      return 0;
    }

    try {
      final pending = await store.listPending();
      var flushed = 0;
      for (final task in pending) {
        final indexed =
            task.operation ==
                Migration014EmbeddingDeferredQueue.operationIndexReflection
            ? await _dispatchIndexReflection(
                filePath: task.sqliteFilePath,
                entryId: task.entryId,
                text: task.text,
                contentHash: task.contentHash ?? '',
                keyAlias: task.keyAlias,
                encryptionPassword: task.encryptionPassword,
              )
            : await _dispatchIndexTranscript(
                filePath: task.sqliteFilePath,
                entryId: task.entryId,
                llmSummary: task.text,
                keyAlias: task.keyAlias,
                encryptionPassword: task.encryptionPassword,
              );
        if (indexed) {
          await store.remove(task.queueId);
          flushed++;
        }
      }
      return flushed;
    } on DatabaseException catch (e) {
      // Deferred embedding work can race a database close (account switch, app
      // shutdown, or test teardown). A closed connection just means there is
      // nothing more to flush right now — expected, not a failure.
      if (e.isDatabaseClosedError()) return 0;
      rethrow;
    }
  }

  Future<bool> _dispatchIndexReflection({
    required String filePath,
    required String entryId,
    required String text,
    required String contentHash,
    String? encryptionPassword,
    String? keyAlias,
  }) async {
    await ensureStarted();
    final payload = _databasePayload(
      filePath: filePath,
      encryptionPassword: encryptionPassword,
      keyAlias: keyAlias,
      extra: {
        'entryId': entryId,
        'text': text,
        'contentHash': contentHash,
      },
    );
    if (_isFlutterTest && _testRuntime != null) {
      final indexed = await _testRuntime!.handle(
        IsolateWorkerRequest(
          requestId: 0,
          operation: EmbeddingIndexWorkerOperations.indexReflection,
          payload: payload,
        ),
      );
      return indexed as bool? ?? false;
    }

    final indexed = await dispatchImpl<bool>(
      operation: EmbeddingIndexWorkerOperations.indexReflection,
      payload: payload,
    );
    return indexed;
  }

  Future<bool> _dispatchIndexTranscript({
    required String filePath,
    required String entryId,
    required String llmSummary,
    String? encryptionPassword,
    String? keyAlias,
  }) async {
    await ensureStarted();
    final payload = _databasePayload(
      filePath: filePath,
      encryptionPassword: encryptionPassword,
      keyAlias: keyAlias,
      extra: {
        'entryId': entryId,
        'llmSummary': llmSummary,
      },
    );
    if (_isFlutterTest && _testRuntime != null) {
      final indexed = await _testRuntime!.handle(
        IsolateWorkerRequest(
          requestId: 0,
          operation: EmbeddingIndexWorkerOperations.indexTranscript,
          payload: payload,
        ),
      );
      return indexed as bool? ?? false;
    }

    final indexed = await dispatchImpl<bool>(
      operation: EmbeddingIndexWorkerOperations.indexTranscript,
      payload: payload,
    );
    return indexed;
  }

  Future<bool> _shouldDeferEmbedding({
    required String filePath,
    required String? keyAlias,
  }) async {
    final throttling = _thermalThrottling ?? ThermalThrottlingService();
    if (!await throttling.shouldDeferEmbeddingWork()) {
      return false;
    }
    return _deferredQueue != null && filePath.isNotEmpty;
  }

  Future<void> _deferReflection({
    required String filePath,
    required String entryId,
    required String text,
    required String contentHash,
    required String? keyAlias,
    String? encryptionPassword,
  }) async {
    final store = _deferredQueue;
    if (store == null) return;
    await store.enqueueReflection(
      entryId: entryId,
      text: text,
      contentHash: contentHash,
      sqliteFilePath: filePath,
      keyAlias: keyAlias,
      encryptionPassword: encryptionPassword,
    );
  }

  Future<void> _deferLlmSummary({
    required String filePath,
    required String entryId,
    required String llmSummary,
    required String? keyAlias,
    String? encryptionPassword,
  }) async {
    final store = _deferredQueue;
    if (store == null) return;
    await store.enqueueLlmSummary(
      entryId: entryId,
      llmSummary: llmSummary,
      sqliteFilePath: filePath,
      keyAlias: keyAlias,
      encryptionPassword: encryptionPassword,
    );
  }

  Future<AutomateGraphWorkerResult?> automateGraphForEntry({
    required String filePath,
    required String entryId,
    required String text,
    required String contentHash,
    String? encryptionPassword,
    String? keyAlias,
  }) async {
    await ensureStarted();
    final payload = _databasePayload(
      filePath: filePath,
      encryptionPassword: encryptionPassword,
      keyAlias: keyAlias,
      extra: {
        'entryId': entryId,
        'text': text,
        'contentHash': contentHash,
      },
    );
    if (_isFlutterTest && _testRuntime != null) {
      final result = await _testRuntime!.handle(
        IsolateWorkerRequest(
          requestId: 0,
          operation: EmbeddingIndexWorkerOperations.automateGraphForEntry,
          payload: payload,
        ),
      );
      if (result is! Map) return null;
      return AutomateGraphWorkerResult.fromJson(
        result.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    final result = await dispatchImpl<Map<String, dynamic>>(
      operation: EmbeddingIndexWorkerOperations.automateGraphForEntry,
      payload: payload,
    );
    if (result == null) return null;
    return AutomateGraphWorkerResult.fromJson(result);
  }

  Map<String, dynamic> _databasePayload({
    required String filePath,
    String? encryptionPassword,
    String? keyAlias,
    Map<String, dynamic>? extra,
  }) {
    return {
      'filePath': filePath,
      if (encryptionPassword != null) 'encryptionPassword': encryptionPassword,
      if (keyAlias != null) 'keyAlias': keyAlias,
      ...?extra,
    };
  }

  @override
  Future<T> dispatch<T>({
    required String operation,
    required Map<String, dynamic> payload,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    await ensureStarted();
    if (_isFlutterTest && _testRuntime != null) {
      final result = await _testRuntime!.handle(
        IsolateWorkerRequest(
          requestId: 0,
          operation: operation,
          payload: payload,
        ),
      );
      return result as T;
    }
    return dispatchImpl<T>(
      operation: operation,
      payload: payload,
      timeout: timeout,
    );
  }

  @override
  Stream<Object?> dispatchStream({
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return dispatchStreamImpl(operation: operation, payload: payload);
  }

  @override
  void handleWorkerResponse(Object? message) {
    handleWorkerResponseImpl(message);
  }

  @override
  Future<void> disposeWorker({required String shutdownOperation}) {
    return disposeWorkerImpl(shutdownOperation: shutdownOperation);
  }

  Future<void> dispose() {
    _testRuntime = null;
    return disposeWorker(
      shutdownOperation: EmbeddingIndexWorkerOperations.shutdown,
    );
  }

  @override
  Future<void> closeClientState() => dispose();
}

/// Top-level entry for the embedding index worker isolate.
Future<void> embeddingIndexWorkerIsolateEntry(
  IsolateWorkerStartup startup,
) async {
  IsolateSafeSqliteDatabaseInitializer.ensureWorkerRuntime(
    initializeTestFfi: startup.initializeTestFfi,
    rootIsolateToken: startup.rootIsolateToken,
  );

  final runtime = _EmbeddingIndexWorkerRuntime(
    defaultKeyAlias: startup.defaultKeyAlias,
  );
  final serverPort = ReceivePort();
  startup.handshakePort.send(serverPort.sendPort);

  await for (final message in serverPort) {
    if (message is! Map) continue;

    final request = IsolateWorkerRequest.fromJson(
      message.map((key, value) => MapEntry(key.toString(), value)),
    );

    if (request.operation == EmbeddingIndexWorkerOperations.shutdown) {
      await runtime.dispose();
      serverPort.close();
      break;
    }

    try {
      final result = await runtime.handle(request);
      startup.clientResponsePort.send(
        IsolateWorkerResponse(
          requestId: request.requestId,
          result: result,
        ).toJson(),
      );
    } on Object catch (error, stackTrace) {
      startup.clientResponsePort.send(
        IsolateWorkerResponse(
          requestId: request.requestId,
          error: '$error',
        ).toJson(),
      );
    }
  }
}

final class _EmbeddingIndexWorkerRuntime {
  _EmbeddingIndexWorkerRuntime({this.defaultKeyAlias});

  final String? defaultKeyAlias;
  ReflectionEmbeddingInference? _inference;
  final _connections = <String, Database>{};

  Future<Object?> handle(IsolateWorkerRequest request) async {
    switch (request.operation) {
      case EmbeddingIndexWorkerOperations.indexReflection:
        return _indexReflection(request.payload);
      case EmbeddingIndexWorkerOperations.indexTranscript:
        return _indexTranscript(request.payload);
      case EmbeddingIndexWorkerOperations.automateGraphForEntry:
        return _automateGraphForEntry(request.payload);
      default:
        throw UnsupportedError(
          'Unknown embedding operation: ${request.operation}',
        );
    }
  }

  Future<bool> _indexReflection(Map<String, dynamic> payload) async {
    final entryId = payload['entryId'] as String? ?? '';
    final text = (payload['text'] as String? ?? '').trim();
    final contentHash = payload['contentHash'] as String? ?? '';
    if (entryId.isEmpty ||
        text.length < ReflectionTextProcessor.minTextChars ||
        contentHash.isEmpty) {
      return false;
    }

    final db = await _databaseFor(payload);
    final store = ReflectionEmbeddingWorkerStore(db);
    final existingHash = await store.readContentHash(entryId);
    if (existingHash == contentHash) return false;

    final embedding = await _embedText(text);
    await store.upsertEmbedding(
      entryId: entryId,
      embedding: embedding,
      contentHash: contentHash,
    );
    return true;
  }

  Future<bool> _indexTranscript(Map<String, dynamic> payload) async {
    if (payload.containsKey('text') && !payload.containsKey('llmSummary')) {
      return false;
    }

    final entryId = payload['entryId'] as String? ?? '';
    final llmSummary = (payload['llmSummary'] as String? ?? '').trim();
    if (entryId.isEmpty ||
        llmSummary.length < ReflectionTextProcessor.minTextChars) {
      return false;
    }

    final db = await _databaseFor(payload);
    final transcriptRepo = MemoryTranscriptSearchRepository.fromWorkerDatabase(
      db,
    );
    final embedding = await _embedText(llmSummary);
    await transcriptRepo.upsertEmbedding(
      entryId: entryId,
      embedding: embedding,
    );
    return true;
  }

  Future<Map<String, dynamic>> _automateGraphForEntry(
    Map<String, dynamic> payload,
  ) async {
    final entryId = payload['entryId'] as String? ?? '';
    final text = (payload['text'] as String? ?? '').trim();
    final contentHash = payload['contentHash'] as String? ?? '';
    if (entryId.isEmpty ||
        text.length < ReflectionTextProcessor.minTextChars ||
        contentHash.isEmpty) {
      return AutomateGraphWorkerResult(
        embeddingStored: false,
        similarEntries: const [],
        edgesStored: 0,
      ).toJson();
    }

    final db = await _databaseFor(payload);
    final embeddingStore = ReflectionEmbeddingWorkerStore(db);
    final edgeStore = EntryEdgesWorkerStore(db);

    var embeddingStored = false;
    final existingHash = await embeddingStore.readContentHash(entryId);
    List<double> queryEmbedding;
    if (existingHash == contentHash) {
      queryEmbedding =
          await _readStoredEmbedding(db, entryId) ?? await _embedText(text);
    } else {
      queryEmbedding = await _embedText(text);
      await embeddingStore.upsertEmbedding(
        entryId: entryId,
        embedding: queryEmbedding,
        contentHash: contentHash,
      );
      embeddingStored = true;
    }

    final similarHits = await ReflectionEmbeddingVectorSearch.searchWithScores(
      db: db,
      queryEmbedding: queryEmbedding,
      limit: AutomatedGraphEmbeddingText.topSimilarEntries,
      excludeEntryId: entryId,
    );

    await edgeStore.replaceSemanticEdges(
      sourceEntryId: entryId,
      edges: similarHits
          .map(
            (hit) => (
              targetEntryId: hit.entryId,
              weight: hit.cosineSimilarity,
            ),
          )
          .toList(growable: false),
    );

    return AutomateGraphWorkerResult(
      embeddingStored: embeddingStored,
      similarEntries: similarHits,
      edgesStored: similarHits.length,
    ).toJson();
  }

  Future<List<double>?> _readStoredEmbedding(
    Database db,
    String entryId,
  ) async {
    final rows = await db.query(
      ReflectionEmbeddingWorkerStore.embeddingsTable,
      columns: ['embedding'],
      where: 'entry_id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final blob = rows.first['embedding'] as Uint8List?;
    if (blob == null) return null;
    final floats = Float32List.view(
      blob.buffer,
      blob.offsetInBytes,
      blob.lengthInBytes ~/ Float32List.bytesPerElement,
    );
    return floats.toList(growable: false);
  }

  Future<List<double>> _embedText(String text) async {
    _inference ??=
        await OnnxReflectionEmbeddingInference.tryCreateFromAsset() ??
        LocalReflectionEmbeddingInference();
    final tensor = ReflectionTextProcessor.buildInputTensor(text);
    return _inference!.embed(tensor);
  }

  Future<Database> _databaseFor(Map<String, dynamic> payload) async {
    final filePath = payload['filePath'] as String? ?? '';
    if (filePath.isEmpty) {
      throw ArgumentError('filePath is required for embedding worker ops.');
    }

    final passwordOverride = payload['encryptionPassword'] as String?;
    final keyAlias = payload['keyAlias'] as String? ?? defaultKeyAlias;
    final cacheKey = '$filePath|${keyAlias ?? passwordOverride ?? ''}';

    final cached = _connections[cacheKey];
    if (cached != null && cached.isOpen) {
      return cached;
    }

    final db = await IsolateSafeSqliteDatabaseInitializer.openWorkerConnection(
      filePath: filePath,
      passwordOverride: passwordOverride,
      keyAlias: keyAlias,
    );

    _connections[cacheKey] = db;
    return db;
  }

  Future<void> dispose() async {
    _inference = null;
    for (final db in _connections.values) {
      if (db.isOpen) {
        await db.close();
      }
    }
    _connections.clear();
  }
}
