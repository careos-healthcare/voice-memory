// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../features/semantic_clusters/semantic_cluster_store.dart';
import '../../models/journal_entry.dart';
import '../../storage/app_storage_paths.dart';
import '../../storage/encrypted_json_file_store.dart';
import '../../storage/journal_store.dart';
import '../semantic_clusters/semantic_cluster.dart';
import 'neural_dataset_models.dart';

typedef NeuralTemporaryDirectoryProvider = Future<Directory> Function();
typedef NeuralDatasetClock = DateTime Function();
typedef NeuralBackupExcluder = Future<void> Function(String path);

final class NeuralPseudonymizer {
  NeuralPseudonymizer(Iterable<GraphNode> nodes)
    : _labels = _buildLabels(nodes);

  final List<(RegExp, String)> _labels;

  String pseudonymize(String input) {
    var output = input;
    for (final replacement in _labels) {
      output = output.replaceAll(replacement.$1, replacement.$2);
    }
    output = output
        .replaceAll(
          RegExp(
            r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
            caseSensitive: false,
          ),
          '[EMAIL]',
        )
        .replaceAll(
          RegExp(r'https?://[^\s]+|www\.[^\s]+', caseSensitive: false),
          '[URL]',
        )
        .replaceAll(
          RegExp(
            r'\b(?:\+?\d{1,3}[\s.-]?)?(?:\(?\d{2,4}\)?[\s.-]?)\d{3}[\s.-]?\d{3,4}\b',
          ),
          '[PHONE]',
        )
        .replaceAll(RegExp(r'\b\d{4}-\d{1,2}-\d{1,2}\b'), '[DATE]')
        .replaceAll(
          RegExp(
            r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b',
            caseSensitive: false,
          ),
          '[DATE]',
        )
        .replaceAll(
          RegExp(
            r'\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b',
            caseSensitive: false,
          ),
          '[DATE]',
        );
    return output;
  }

  static List<(RegExp, String)> _buildLabels(Iterable<GraphNode> nodes) {
    final people =
        nodes
            .where(
              (node) =>
                  node.type == NodeType.person && node.label.trim().length > 1,
            )
            .map((node) => node.label.trim())
            .toSet()
            .toList()
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
    final places =
        nodes
            .where(
              (node) =>
                  node.type == NodeType.place && node.label.trim().length > 1,
            )
            .map((node) => node.label.trim())
            .toSet()
            .toList()
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
    return [
      for (var index = 0; index < people.length; index++)
        (
          RegExp(
            r'\b' + RegExp.escape(people[index]) + r'\b',
            caseSensitive: false,
          ),
          '[PERSON_${index + 1}]',
        ),
      for (var index = 0; index < places.length; index++)
        (
          RegExp(
            r'\b' + RegExp.escape(places[index]) + r'\b',
            caseSensitive: false,
          ),
          '[PLACE_${index + 1}]',
        ),
    ];
  }
}

final class NeuralDatasetBuilder {
  NeuralDatasetBuilder({
    required this.journalStore,
    required this.graphStore,
    required this.clusterStore,
    required this.encryptedStore,
    NeuralTemporaryDirectoryProvider? temporaryDirectory,
    NeuralDatasetClock? clock,
    NeuralBackupExcluder? excludeFromBackup,
  }) : _temporaryDirectory =
           temporaryDirectory ?? AppStoragePaths.temporaryDirectory,
       _clock = clock ?? DateTime.now,
       _excludeFromBackup = excludeFromBackup;

  static const int highIntensityThreshold = 4;
  static const String temporaryDirectoryName = 'neural_sculptor_training';

  final JournalStore journalStore;
  final PersonalKnowledgeGraphStore graphStore;
  final SemanticClusterStore clusterStore;
  final EncryptedJsonFileStore encryptedStore;
  final NeuralTemporaryDirectoryProvider _temporaryDirectory;
  final NeuralDatasetClock _clock;
  final NeuralBackupExcluder? _excludeFromBackup;

  Future<NeuralDatasetManifest> build({
    Set<String> selectedClusterIds = const {},
  }) async {
    final entries = await journalStore.loadEligible();
    final graph = await graphStore.load();
    final clusters = await clusterStore.list();
    final selected = clusters
        .where((cluster) => selectedClusterIds.contains(cluster.id))
        .toList(growable: false);
    final clusteredEntryIds = _entryIdsFor(selected, graph.nodes);
    final pseudonymizer = NeuralPseudonymizer(graph.nodes);
    final selectedEntries =
        entries
            .where(
              (entry) =>
                  clusteredEntryIds.contains(entry.id) ||
                  entry.reflection.emotionalIntensity >= highIntensityThreshold,
            )
            .toList()
          ..sort((left, right) {
            final date = left.createdAt.compareTo(right.createdAt);
            return date != 0 ? date : left.id.compareTo(right.id);
          });

    final records = <NeuralDatasetRecord>[];
    for (final entry in selectedEntries) {
      final kinds = <String>[
        if (clusteredEntryIds.contains(entry.id)) 'selected_cluster',
        if (entry.reflection.emotionalIntensity >= highIntensityThreshold)
          'high_intensity',
      ];
      final instruction = pseudonymizer.pseudonymize(_instructionFor(entry));
      final response = pseudonymizer.pseudonymize(entry.transcript.trim());
      if (response.isEmpty) continue;
      final provenanceId = stableGraphId('neural-source', [entry.id]);
      records.add(
        NeuralDatasetRecord(
          id: stableGraphId('neural-record', [provenanceId, response]),
          instruction: instruction,
          response: response,
          provenanceId: provenanceId,
          tokenEstimate: _estimateTokens('$instruction $response'),
          sourceKinds: kinds,
        ),
      );
    }

    final createdAt = _clock().toUtc();
    final selectedIds = selected.map((cluster) => cluster.id).toList()..sort();
    final manifest = NeuralDatasetManifest(
      id: stableGraphId('neural-dataset', [
        createdAt.toIso8601String(),
        ...records.map((record) => record.id),
      ]),
      createdAt: createdAt,
      records: List.unmodifiable(records),
      selectedClusterIds: List.unmodifiable(selectedIds),
      tokenCount: records.fold(0, (sum, record) => sum + record.tokenEstimate),
      pseudonymized: true,
    );
    await encryptedStore.writeJson(manifest.toJson());
    return manifest;
  }

  Future<NeuralDatasetManifest?> load() async {
    final raw = await encryptedStore.readJson();
    if (raw is! Map || raw.isEmpty) return null;
    return NeuralDatasetManifest.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<List<String>> inspect({
    int limit = 12,
    int maxCharacters = 240,
  }) async {
    final manifest = await load();
    if (manifest == null) return const [];
    return manifest.records
        .take(limit)
        .map((record) {
          final text = record.response.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (text.length <= maxCharacters) return text;
          return '${text.substring(0, maxCharacters).trimRight()}…';
        })
        .toList(growable: false);
  }

  Future<MaterializedNeuralDataset> materialize() async {
    final manifest = await load();
    if (manifest == null || manifest.records.isEmpty) {
      throw StateError('Build a non-empty local dataset before training.');
    }
    await cleanupStaleTemporaryFiles();
    final base = await _temporaryDirectory();
    final directory = Directory(
      '${base.path}/$temporaryDirectoryName/${manifest.id}',
    );
    await directory.create(recursive: true);
    await _excludeFromBackup?.call(directory.path);
    final file = File('${directory.path}/dataset.jsonl');
    final sink = file.openWrite(mode: FileMode.writeOnly);
    try {
      for (final record in manifest.records) {
        sink.writeln(record.toJsonLine());
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return MaterializedNeuralDataset(
      file: file,
      datasetId: manifest.id,
      cleanup: () async {
        await _secureDeleteDirectory(directory);
        final parent = directory.parent;
        if (await parent.exists() && await parent.list().isEmpty) {
          await parent.delete();
        }
      },
    );
  }

  Future<void> cleanupStaleTemporaryFiles() async {
    final base = await _temporaryDirectory();
    final directory = Directory('${base.path}/$temporaryDirectoryName');
    await _secureDeleteDirectory(directory);
  }

  Future<void> clear() async {
    await encryptedStore.writeJson(const <String, dynamic>{});
    await cleanupStaleTemporaryFiles();
  }

  static Set<String> _entryIdsFor(
    Iterable<SemanticCluster> clusters,
    Iterable<GraphNode> nodes,
  ) {
    final nodeIds = clusters.expand((cluster) => cluster.nodeIds).toSet();
    return nodes
        .where((node) => nodeIds.contains(node.id))
        .expand((node) => node.evidence)
        .map((evidence) => evidence.entryId)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static String _instructionFor(JournalEntry entry) {
    final reflection = entry.reflection;
    final themes = reflection.recurringThemes
        .where((theme) => theme.trim().isNotEmpty)
        .join(', ');
    final context = [
      if (reflection.mood.trim().isNotEmpty) 'Mood: ${reflection.mood.trim()}.',
      if (themes.isNotEmpty) 'Themes: $themes.',
      if (entry.reflectionSummary.trim().isNotEmpty)
        'Reflection: ${entry.reflectionSummary.trim()}',
    ].join(' ');
    return context.isEmpty
        ? 'Write a private journal reflection in my natural voice.'
        : 'Write a private journal reflection in my natural voice. $context';
  }

  static int _estimateTokens(String text) {
    final bytes = utf8.encode(text).length;
    return bytes == 0 ? 0 : (bytes / 4).ceil();
  }

  static Future<void> _secureDeleteDirectory(Directory directory) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      try {
        final length = await entity.length();
        if (length > 0) {
          final handle = await entity.open(mode: FileMode.write);
          try {
            const block = 64 * 1024;
            var remaining = length;
            while (remaining > 0) {
              final count = remaining > block ? block : remaining;
              await handle.writeFrom(List<int>.filled(count, 0));
              remaining -= count;
            }
            await handle.flush();
          } finally {
            await handle.close();
          }
        }
      } on FileSystemException {
        // Best effort overwrite; recursive deletion below remains mandatory.
      }
    }
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
