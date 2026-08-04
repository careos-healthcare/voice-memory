import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../core/search/local_vector_search_engine.dart';
import 'legacy_ingestion_store.dart';
import 'markdown_vault_models.dart';
import 'markdown_vault_parser.dart';

enum GraphIngestionPhase {
  parsing,
  chunking,
  embedding,
  inserting,
  graphCommit,
  completed,
  cancelled,
}

final class GraphIngestionProgress {
  const GraphIngestionProgress({
    required this.phase,
    required this.totalNotes,
    required this.processedNotes,
    required this.totalChunks,
    required this.embeddedChunks,
    required this.insertedNotes,
    required this.skippedNotes,
    required this.insertedEdges,
    required this.elapsed,
    required this.sqliteWriteTime,
    this.currentPath = '',
  });

  final GraphIngestionPhase phase;
  final int totalNotes;
  final int processedNotes;
  final int totalChunks;
  final int embeddedChunks;
  final int insertedNotes;
  final int skippedNotes;
  final int insertedEdges;
  final Duration elapsed;
  final Duration sqliteWriteTime;
  final String currentPath;

  double get fraction {
    if (phase == GraphIngestionPhase.completed) return 1;
    if (totalNotes == 0) return 0;
    return switch (phase) {
      GraphIngestionPhase.parsing => processedNotes / totalNotes * .2,
      GraphIngestionPhase.chunking => .2,
      GraphIngestionPhase.embedding =>
        .2 + (totalChunks == 0 ? 0 : embeddedChunks / totalChunks * .55),
      GraphIngestionPhase.inserting => .75 + processedNotes / totalNotes * .2,
      GraphIngestionPhase.graphCommit => .97,
      GraphIngestionPhase.completed => 1,
      GraphIngestionPhase.cancelled => 0,
    };
  }

  double get notesPerSecond => elapsed.inMilliseconds <= 0
      ? 0
      : processedNotes * 1000 / elapsed.inMilliseconds;

  Duration? get eta {
    if (embeddedChunks <= 0 || embeddedChunks >= totalChunks) return null;
    final perChunk = elapsed.inMicroseconds / embeddedChunks;
    return Duration(
      microseconds: ((totalChunks - embeddedChunks) * perChunk).round(),
    );
  }
}

final class GraphIngestionResult {
  const GraphIngestionResult({
    required this.parsedNotes,
    required this.insertedNotes,
    required this.skippedNotes,
    required this.insertedChunks,
    required this.insertedEdges,
    required this.elapsed,
  });

  final int parsedNotes;
  final int insertedNotes;
  final int skippedNotes;
  final int insertedChunks;
  final int insertedEdges;
  final Duration elapsed;
}

final class GraphIngestionCancellation {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw const GraphIngestionCancelled();
  }
}

final class GraphIngestionCancelled implements Exception {
  const GraphIngestionCancelled();
}

abstract interface class MarkdownEmbeddingGenerator {
  int get dimensions;
  Future<List<Float32List>> embedBatch(List<String> texts);
}

final class LocalMarkdownEmbeddingGenerator
    implements MarkdownEmbeddingGenerator {
  const LocalMarkdownEmbeddingGenerator(this.driver);

  final LocalEmbeddingDriver driver;

  @override
  int get dimensions => driver.dimensions;

  @override
  Future<List<Float32List>> embedBatch(List<String> texts) async {
    await Future<void>.delayed(Duration.zero);
    return texts.map(driver.embed).toList(growable: false);
  }
}

abstract interface class GraphIngestionController {
  Stream<GraphIngestionProgress> get progress;
  Future<GraphIngestionResult> ingestDirectory(Directory directory);
  void cancel();
}

abstract interface class LegacyPostImportSweepQueue {
  Future<void> enqueue(Iterable<String> noteIds);
}

final class GraphIngestionPipeline implements GraphIngestionController {
  GraphIngestionPipeline({
    required this.parser,
    required this.store,
    required this.graphStore,
    required this.embeddingGenerator,
    this.postImportSweepQueue,
    this.noteBatchSize = 20,
    this.maximumChunkTokens = 400,
    this.overlapTokens = 40,
  }) : assert(noteBatchSize > 0 && noteBatchSize <= 100),
       assert(maximumChunkTokens > overlapTokens);

  final MarkdownVaultParser parser;
  final LegacyIngestionStore store;
  final PersonalKnowledgeGraphStore graphStore;
  final MarkdownEmbeddingGenerator embeddingGenerator;
  final LegacyPostImportSweepQueue? postImportSweepQueue;
  final int noteBatchSize;
  final int maximumChunkTokens;
  final int overlapTokens;
  final StreamController<GraphIngestionProgress> _progress =
      StreamController<GraphIngestionProgress>.broadcast();
  GraphIngestionCancellation? _activeCancellation;

  @override
  Stream<GraphIngestionProgress> get progress => _progress.stream;

  @override
  void cancel() => _activeCancellation?.cancel();

  @override
  Future<GraphIngestionResult> ingestDirectory(Directory directory) async {
    if (_activeCancellation != null) {
      throw StateError('A markdown vault import is already running.');
    }
    final cancellation = GraphIngestionCancellation();
    _activeCancellation = cancellation;
    final watch = Stopwatch()..start();
    try {
      var discovered = 0;
      final notes = await parser.parseDirectory(
        directory,
        onProgress: (value) {
          discovered = value.discoveredFiles;
          _emit(
            GraphIngestionProgress(
              phase: GraphIngestionPhase.parsing,
              totalNotes: value.discoveredFiles,
              processedNotes: value.parsedFiles,
              totalChunks: 0,
              embeddedChunks: 0,
              insertedNotes: 0,
              skippedNotes: 0,
              insertedEdges: 0,
              elapsed: watch.elapsed,
              sqliteWriteTime: Duration.zero,
              currentPath: value.currentPath,
            ),
          );
        },
      );
      cancellation.throwIfCancelled();
      final chunksByNote = {
        for (final note in notes) note.id: _chunk(note.body),
      };
      final totalChunks = chunksByNote.values.fold<int>(
        0,
        (sum, chunks) => sum + chunks.length,
      );
      _emit(
        GraphIngestionProgress(
          phase: GraphIngestionPhase.chunking,
          totalNotes: discovered,
          processedNotes: notes.length,
          totalChunks: totalChunks,
          embeddedChunks: 0,
          insertedNotes: 0,
          skippedNotes: 0,
          insertedEdges: 0,
          elapsed: watch.elapsed,
          sqliteWriteTime: Duration.zero,
        ),
      );

      var embeddedChunks = 0;
      var insertedChunks = 0;
      var insertedNotes = 0;
      var skippedNotes = 0;
      var sqliteWriteTime = Duration.zero;
      final committed = <ParsedMarkdownNote>[];
      for (var offset = 0; offset < notes.length; offset += noteBatchSize) {
        cancellation.throwIfCancelled();
        final end = (offset + noteBatchSize).clamp(0, notes.length);
        final deduped = store.deduplicate(notes.sublist(offset, end));
        final noteBatch = deduped.notes;
        skippedNotes += deduped.skipped;
        final texts = [
          for (final note in noteBatch)
            for (final chunk in chunksByNote[note.id]!) chunk.text,
        ];
        final embeddings = await embeddingGenerator.embedBatch(texts);
        if (embeddings.length != texts.length ||
            embeddings.any(
              (embedding) =>
                  embedding.length != embeddingGenerator.dimensions ||
                  embedding.any((value) => !value.isFinite),
            )) {
          throw StateError('Local embedding backend returned invalid vectors.');
        }
        embeddedChunks += embeddings.length;
        _emit(
          GraphIngestionProgress(
            phase: GraphIngestionPhase.embedding,
            totalNotes: notes.length,
            processedNotes: end,
            totalChunks: totalChunks,
            embeddedChunks: embeddedChunks,
            insertedNotes: insertedNotes,
            skippedNotes: skippedNotes,
            insertedEdges: 0,
            elapsed: watch.elapsed,
            sqliteWriteTime: sqliteWriteTime,
          ),
        );
        var embeddingIndex = 0;
        final prepared = <PreparedMarkdownNote>[];
        for (final note in noteBatch) {
          final embedded = <EmbeddedMarkdownChunk>[];
          for (final chunk in chunksByNote[note.id]!) {
            embedded.add(
              EmbeddedMarkdownChunk(
                noteId: note.id,
                chunk: chunk,
                embedding: embeddings[embeddingIndex++],
              ),
            );
          }
          prepared.add(PreparedMarkdownNote(note: note, chunks: embedded));
        }
        cancellation.throwIfCancelled();
        final written = store.writeBatch(prepared);
        insertedNotes += written.insertedNotes.length;
        insertedChunks += written.insertedChunks;
        skippedNotes += written.skippedNotes;
        sqliteWriteTime += written.sqliteWriteTime;
        committed.addAll(written.insertedNotes);
        _emit(
          GraphIngestionProgress(
            phase: GraphIngestionPhase.inserting,
            totalNotes: notes.length,
            processedNotes: end,
            totalChunks: totalChunks,
            embeddedChunks: embeddedChunks,
            insertedNotes: insertedNotes,
            skippedNotes: skippedNotes,
            insertedEdges: 0,
            elapsed: watch.elapsed,
            sqliteWriteTime: sqliteWriteTime,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      cancellation.throwIfCancelled();
      _emit(
        GraphIngestionProgress(
          phase: GraphIngestionPhase.graphCommit,
          totalNotes: notes.length,
          processedNotes: notes.length,
          totalChunks: totalChunks,
          embeddedChunks: embeddedChunks,
          insertedNotes: insertedNotes,
          skippedNotes: skippedNotes,
          insertedEdges: 0,
          elapsed: watch.elapsed,
          sqliteWriteTime: sqliteWriteTime,
        ),
      );
      final edgeCount = await _mergeGraph(committed, allNotes: notes);
      try {
        await postImportSweepQueue?.enqueue(committed.map((note) => note.id));
      } on Object {
        // The durable import has committed. A scheduler failure must not make
        // the user repeat the import; undigested rows remain discoverable.
      }
      final result = GraphIngestionResult(
        parsedNotes: notes.length,
        insertedNotes: insertedNotes,
        skippedNotes: skippedNotes,
        insertedChunks: insertedChunks,
        insertedEdges: edgeCount,
        elapsed: watch.elapsed,
      );
      _emit(
        GraphIngestionProgress(
          phase: GraphIngestionPhase.completed,
          totalNotes: notes.length,
          processedNotes: notes.length,
          totalChunks: totalChunks,
          embeddedChunks: embeddedChunks,
          insertedNotes: insertedNotes,
          skippedNotes: skippedNotes,
          insertedEdges: edgeCount,
          elapsed: watch.elapsed,
          sqliteWriteTime: sqliteWriteTime,
        ),
      );
      return result;
    } on GraphIngestionCancelled {
      _emit(
        GraphIngestionProgress(
          phase: GraphIngestionPhase.cancelled,
          totalNotes: 0,
          processedNotes: 0,
          totalChunks: 0,
          embeddedChunks: 0,
          insertedNotes: 0,
          skippedNotes: 0,
          insertedEdges: 0,
          elapsed: watch.elapsed,
          sqliteWriteTime: Duration.zero,
        ),
      );
      rethrow;
    } finally {
      _activeCancellation = null;
    }
  }

  List<MarkdownChunk> _chunk(String text) {
    final tokens = RegExp(r'\S+').allMatches(text).toList();
    if (tokens.isEmpty) return const [];
    final chunks = <MarkdownChunk>[];
    var first = 0;
    while (first < tokens.length) {
      final last = (first + maximumChunkTokens).clamp(0, tokens.length);
      final start = tokens[first].start;
      final end = tokens[last - 1].end;
      chunks.add(
        MarkdownChunk(
          index: chunks.length,
          text: text.substring(start, end),
          start: start,
          end: end,
        ),
      );
      if (last == tokens.length) break;
      first = last - overlapTokens;
    }
    return List.unmodifiable(chunks);
  }

  Future<int> _mergeGraph(
    List<ParsedMarkdownNote> inserted, {
    required List<ParsedMarkdownNote> allNotes,
  }) async {
    if (inserted.isEmpty) return 0;
    final idByTitle = <String, String>{
      for (final note in allNotes) _normalize(note.title): note.id,
      for (final note in allNotes)
        for (final alias in note.aliases) _normalize(alias): note.id,
    };
    var addedEdges = 0;
    await graphStore.update((graph) {
      final nodes = {for (final node in graph.nodes) node.id: node};
      final edges = {for (final edge in graph.edges) edge.id: edge};
      for (final note in inserted) {
        nodes[note.id] = GraphNode(
          id: note.id,
          type: NodeType.text,
          label: note.title,
          confidence: 1,
          origin: NodeOrigin.document,
          createdAt:
              note.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          tags: {...note.tags, 'legacy-markdown'},
        );
      }
      for (final note in inserted) {
        for (final link in note.links) {
          final targetId =
              idByTitle[_normalize(link.target)] ?? _idForTitle(link.target);
          nodes.putIfAbsent(
            targetId,
            () => GraphNode(
              id: targetId,
              type: NodeType.text,
              label: link.target,
              confidence: .65,
              origin: NodeOrigin.document,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              tags: const {'legacy-placeholder'},
            ),
          );
          if (targetId == note.id) continue;
          final edgeId = stableGraphId('legacy-wiki-edge', [note.id, targetId]);
          if (edges.containsKey(edgeId)) continue;
          edges[edgeId] = GraphEdge(
            id: edgeId,
            sourceNodeId: note.id,
            targetNodeId: targetId,
            type: EdgeType.associatedWith,
            isDirected: true,
            weight: .95,
            origin: NodeOrigin.document,
            createdAt:
                note.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          );
          addedEdges++;
        }
      }
      return PersonalKnowledgeGraph(
        schemaVersion: graph.schemaVersion,
        nodes: nodes.values,
        edges: edges.values,
        trajectories: graph.trajectories,
        materialization: graph.materialization,
        clock: graph.clock,
      );
    });
    return addedEdges;
  }

  void _emit(GraphIngestionProgress value) {
    if (!_progress.isClosed) _progress.add(value);
  }

  Future<void> dispose() async {
    cancel();
    await _progress.close();
  }

  static String _idForTitle(String title) =>
      'legacy_note_${_titleHash(title).substring(0, 24)}';

  static String _titleHash(String title) =>
      sha256.convert(utf8.encode(_normalize(title))).toString();

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
