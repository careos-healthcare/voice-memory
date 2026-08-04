import 'dart:async';
import 'dart:convert';

import '../../models/journal_entry.dart';
import '../../storage/encrypted_json_file_store.dart';
import 'graph_node.dart';
import 'personal_knowledge_graph.dart';

typedef GraphSnapshotObserver =
    Future<void> Function(PersonalKnowledgeGraph graph);

class PersonalKnowledgeGraphStore {
  PersonalKnowledgeGraphStore({
    required this.storage,
    PersonalKnowledgeGraphEngine? engine,
    this.extractorVersion = currentExtractorVersion,
    this.governanceVersion = currentGovernanceVersion,
    this.governanceHash = currentGovernanceHash,
    this.onSnapshot,
  }) : _engine = engine ?? PersonalKnowledgeGraphEngine();

  static const currentExtractorVersion = 'hybrid-local-extractor-v4';
  static const currentGovernanceVersion = 'strict-citations-v2';
  static const currentGovernanceHash = 'utf16-exact-no-inference-v2';

  final EncryptedJsonFileStore storage;
  final PersonalKnowledgeGraphEngine _engine;
  final String extractorVersion;
  final String governanceVersion;
  final String governanceHash;
  final GraphSnapshotObserver? onSnapshot;
  Future<void> _writeTail = Future<void>.value();
  bool _disposed = false;

  Future<PersonalKnowledgeGraph> load() => _serialized(_load);

  Future<PersonalKnowledgeGraph> _load() async {
    try {
      final raw = await storage.readJson();
      if (raw is! Map || raw.isEmpty) return PersonalKnowledgeGraph();
      return PersonalKnowledgeGraph.fromJson(Map<String, dynamic>.from(raw));
    } on FormatException {
      return PersonalKnowledgeGraph();
    } on ArgumentError {
      return PersonalKnowledgeGraph();
    }
  }

  Future<void> save(PersonalKnowledgeGraph graph) =>
      _serialized(() => _write(graph));

  /// Atomically loads, mutates, and saves a graph on the store write queue.
  ///
  /// The normal save path is retained so snapshot observers (including E2EE
  /// sync) see the resulting graph.
  Future<PersonalKnowledgeGraph> update(
    PersonalKnowledgeGraph Function(PersonalKnowledgeGraph graph) operation,
  ) => _serialized(() async {
    final next = operation(await _load());
    await _write(next);
    return next;
  });

  Future<void> clear() =>
      _serialized(() => storage.writeJson(const <String, dynamic>{}));

  Future<PersonalKnowledgeGraph> rebuild(Iterable<JournalEntry> entries) =>
      _serialized(() => _rebuild(entries.toList()));

  Future<PersonalKnowledgeGraph> reconcile(Iterable<JournalEntry> entries) =>
      _serialized(() async {
        final ordered = entries.toList()
          ..sort((a, b) {
            final time = a.createdAt.compareTo(b.createdAt);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
        final current = await _load();
        final revisions = {
          for (final entry in ordered) entry.id: _revisionFor(entry),
        };
        final metadata = current.materialization;
        final requiresRebuild =
            current.schemaVersion != 2 ||
            metadata.extractorVersion != extractorVersion ||
            metadata.governanceVersion != governanceVersion ||
            metadata.governanceHash != governanceHash;
        if (requiresRebuild) return _rebuild(ordered);

        final removedOrChanged = <String>{
          for (final item in metadata.processedEntryRevisions.entries)
            if (revisions[item.key] != item.value) item.key,
        };
        final changed = ordered
            .where(
              (entry) =>
                  metadata.processedEntryRevisions[entry.id] !=
                  revisions[entry.id],
            )
            .toList();
        if (removedOrChanged.isEmpty && changed.isEmpty) return current;

        var next = _engine.removeEntryEvidence(current, removedOrChanged);
        if (changed.isNotEmpty) {
          next = await _engine.ingestAllAsync(changed, into: next);
        }
        next = _engine.materializeTrajectories(
          next,
          metadata: _metadata(revisions),
        );
        await _write(next);
        return next;
      });

  Future<PersonalKnowledgeGraph> _rebuild(List<JournalEntry> entries) async {
    final revisions = {
      for (final entry in entries) entry.id: _revisionFor(entry),
    };
    final rebuilt = await _engine.rebuildAsync(entries);
    final graph = _engine.materializeTrajectories(
      rebuilt,
      metadata: _metadata(revisions),
    );
    await _write(graph);
    return graph;
  }

  Future<void> _write(PersonalKnowledgeGraph graph) async {
    await storage.writeJson(graph.toJson());
    await onSnapshot?.call(graph);
  }

  GraphMaterializationMetadata _metadata(Map<String, String> revisions) =>
      GraphMaterializationMetadata(
        processedEntryRevisions: Map.unmodifiable(revisions),
        extractorVersion: extractorVersion,
        governanceVersion: governanceVersion,
        governanceHash: governanceHash,
        materializedAt: DateTime.now().toUtc(),
      );

  static String _revisionFor(JournalEntry entry) =>
      stableGraphId('entry-revision', [jsonEncode(entry.toJson())]);

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    if (_disposed) {
      return Future<T>.error(StateError('Graph store is disposed.'));
    }
    final completer = Completer<T>();
    _writeTail = _writeTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _writeTail.catchError((_) {});
  }
}
