// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/graph/graph_node.dart';
import '../../storage/encrypted_json_file_store.dart';
import 'semantic_cluster.dart';

final class SemanticClusterStore extends ChangeNotifier {
  SemanticClusterStore({
    required EncryptedJsonFileStore storage,
    DateTime Function()? clock,
  }) : _storage = storage,
       _clock = clock ?? DateTime.now;

  final EncryptedJsonFileStore _storage;
  final DateTime Function() _clock;
  final ValueNotifier<int> _revisionListenable = ValueNotifier(0);
  final StreamController<int> _revisionController =
      StreamController<int>.broadcast();
  Future<void> _writeTail = Future<void>.value();
  bool _disposed = false;

  int get revision => _revisionListenable.value;
  ValueListenable<int> get revisionListenable => _revisionListenable;
  Stream<int> get revisions => _revisionController.stream;
  Stream<int> get revisionStream => revisions;

  Future<List<SemanticCluster>> list() => _serialized(_read);

  Future<void> upsert(SemanticCluster cluster) => _mutate((items) {
    items[cluster.id] = cluster;
  });

  Future<void> remove(String id) => _mutate((items) {
    items.remove(id);
  });

  Future<void> replace(Iterable<SemanticCluster> clusters) =>
      _serialized(() async {
        final replacement = <String, SemanticCluster>{};
        for (final cluster in clusters) {
          replacement[cluster.id] = cluster;
        }
        await _write(replacement.values);
        _changed();
      });

  Future<void> rename(String id, String title) => _mutate((items) {
    final existing = _required(items, id);
    items[id] = existing.copyWith(
      title: title,
      updatedAt: _now(),
      userEdited: true,
    );
  });

  Future<void> pin(String id, [bool pinned = true]) => _mutate((items) {
    final existing = _required(items, id);
    items[id] = existing.copyWith(
      pinned: pinned,
      updatedAt: _now(),
      userEdited: true,
    );
  });

  Future<SemanticCluster> merge(Iterable<String> clusterIds, {String? title}) {
    late SemanticCluster merged;
    return _mutate((items) {
      final ids = clusterIds.toSet().toList()..sort();
      if (ids.length < 2) {
        throw ArgumentError.value(clusterIds, 'clusterIds', 'requires two IDs');
      }
      final sources = ids.map((id) => _required(items, id)).toList();
      final nodeIds = sources.expand((item) => item.nodeIds).toSet();
      if (nodeIds.length < 2) {
        throw StateError('Merged cluster must contain at least two nodes.');
      }
      final categories = sources.map((item) => item.category).toSet();
      merged = SemanticCluster(
        id: stableGraphId('semantic-cluster', nodeIds.toList()..sort()),
        title: title?.trim().isNotEmpty == true
            ? title!.trim()
            : sources.map((item) => item.title).join(' + '),
        category: categories.length == 1
            ? categories.single
            : SemanticClusterCategory.theme,
        nodeIds: nodeIds,
        activityVelocity:
            sources
                .map((item) => item.activityVelocity)
                .reduce((a, b) => a + b) /
            sources.length,
        confidenceScore:
            sources
                .map((item) => item.confidenceScore)
                .reduce((a, b) => a + b) /
            sources.length,
        summary: sources
            .map((item) => item.summary)
            .where((value) => value.isNotEmpty)
            .join(' · '),
        pinned: sources.any((item) => item.pinned),
        updatedAt: _now(),
        userEdited: true,
      );
      for (final id in ids) {
        items.remove(id);
      }
      items[merged.id] = merged;
    }).then((_) => merged);
  }

  Future<List<SemanticCluster>> split(
    String id,
    Iterable<Iterable<String>> groups,
  ) {
    late List<SemanticCluster> result;
    return _mutate((items) {
      final source = _required(items, id);
      final sourceIds = source.nodeIds.toSet();
      final used = <String>{};
      final normalized = <List<String>>[];
      for (final group in groups) {
        final nodeIds = group.toSet().toList()..sort();
        if (nodeIds.length < 2 ||
            nodeIds.any((nodeId) => !sourceIds.contains(nodeId)) ||
            nodeIds.any(used.contains)) {
          throw ArgumentError.value(groups, 'groups', 'invalid split groups');
        }
        used.addAll(nodeIds);
        normalized.add(nodeIds);
      }
      if (normalized.length < 2 || used.length != sourceIds.length) {
        throw ArgumentError.value(
          groups,
          'groups',
          'must partition every source node into at least two groups',
        );
      }
      result = [
        for (var index = 0; index < normalized.length; index++)
          SemanticCluster(
            id: stableGraphId('semantic-cluster', normalized[index]),
            title: '${source.title} ${index + 1}',
            category: source.category,
            nodeIds: normalized[index],
            activityVelocity: source.activityVelocity,
            confidenceScore: source.confidenceScore,
            summary: source.summary,
            pinned: source.pinned,
            updatedAt: _now(),
            userEdited: true,
          ),
      ];
      items.remove(id);
      for (final cluster in result) {
        items[cluster.id] = cluster;
      }
    }).then((_) => List.unmodifiable(result));
  }

  Future<void> clear() => _serialized(() async {
    await _storage.writeJson(const {
      'schemaVersion': 1,
      'clusters': <Object>[],
    });
    _changed();
  });

  Future<void> _mutate(
    void Function(Map<String, SemanticCluster> items) operation,
  ) => _serialized(() async {
    final items = {for (final item in await _read()) item.id: item};
    operation(items);
    await _write(items.values);
    _changed();
  });

  Future<List<SemanticCluster>> _read() async {
    try {
      final raw = await _storage.readJson();
      final rows = raw is List
          ? raw
          : raw is Map
          ? raw['clusters']
          : null;
      if (rows is! List) return const [];
      final result = <SemanticCluster>[];
      final ids = <String>{};
      for (final row in rows.whereType<Map>()) {
        try {
          final cluster = SemanticCluster.fromJson(
            Map<String, dynamic>.from(row),
          );
          if (ids.add(cluster.id)) result.add(cluster);
        } on FormatException {
          // Ignore malformed rows while retaining valid encrypted state.
        } on ArgumentError {
          // Constructor invariants also fail closed per row.
        }
      }
      result.sort(_sort);
      return List.unmodifiable(result);
    } on Object {
      return const [];
    }
  }

  Future<void> _write(Iterable<SemanticCluster> clusters) {
    final ordered = clusters.toList()..sort(_sort);
    return _storage.writeJson({
      'schemaVersion': 1,
      'clusters': ordered.map((item) => item.toPortableJson()).toList(),
    });
  }

  static int _sort(SemanticCluster left, SemanticCluster right) {
    if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
    return left.id.compareTo(right.id);
  }

  static SemanticCluster _required(
    Map<String, SemanticCluster> items,
    String id,
  ) {
    final item = items[id];
    if (item == null) throw StateError('Semantic cluster not found: $id');
    return item;
  }

  DateTime _now() => _clock().toUtc();

  void _changed() {
    _revisionListenable.value++;
    _revisionController.add(revision);
    notifyListeners();
  }

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    if (_disposed) {
      return Future.error(StateError('Semantic cluster store is disposed.'));
    }
    final completer = Completer<T>();
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revisionListenable.dispose();
    unawaited(_revisionController.close());
    super.dispose();
  }
}
