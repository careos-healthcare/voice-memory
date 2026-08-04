// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import 'semantic_cluster_engine.dart';
import 'semantic_cluster.dart';
import 'semantic_cluster_store.dart';

typedef SemanticClusterLabeler =
    Future<SemanticCluster> Function(
      SemanticCluster cluster,
      PersonalKnowledgeGraph graph,
    );

/// Coalesces graph changes and guarantees only one local cluster rebuild runs.
final class SemanticClusterRebuildCoordinator {
  SemanticClusterRebuildCoordinator({
    required PersonalKnowledgeGraphStore graphStore,
    required SemanticClusterStore clusterStore,
    required SemanticClusterEngine engine,
    Stream<void>? graphChanges,
    this.labelCluster,
    this.onClustersChanged,
    this.debounce = const Duration(milliseconds: 350),
  }) : _graphStore = graphStore,
       _clusterStore = clusterStore,
       _engine = engine {
    _graphChangesSubscription = graphChanges?.listen((_) => schedule());
  }

  final PersonalKnowledgeGraphStore _graphStore;
  final SemanticClusterStore _clusterStore;
  final SemanticClusterEngine _engine;
  final SemanticClusterLabeler? labelCluster;
  final Future<void> Function()? onClustersChanged;
  final Duration debounce;
  final Set<String> _labelAttemptedIds = {};

  Timer? _timer;
  StreamSubscription<void>? _graphChangesSubscription;
  Future<void>? _active;
  bool _pending = false;
  bool _disposed = false;

  void schedule() {
    if (_disposed) return;
    _pending = true;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_start());
    });
  }

  Future<void> rebuildNow() {
    if (_disposed) return Future.value();
    _pending = true;
    _timer?.cancel();
    _timer = null;
    return _start();
  }

  Future<void> cancelPending() async {
    _pending = false;
    _timer?.cancel();
    _timer = null;
    await _active;
  }

  Future<void> _start() {
    final active = _active;
    if (active != null) return active;
    final run = _drain();
    _active = run;
    return run.whenComplete(() {
      _active = null;
      if (_pending && !_disposed) unawaited(_start());
    });
  }

  Future<void> _drain() async {
    while (_pending && !_disposed) {
      _pending = false;
      try {
        final graph = await _graphStore.load();
        final stored = await _clusterStore.list();
        final storedIds = stored.map((cluster) => cluster.id).toSet();
        var clusters = await _engine.build(graph, storedClusters: stored);
        final labeler = labelCluster;
        if (labeler != null) {
          final labeled = <SemanticCluster>[];
          for (final cluster in clusters) {
            if (!cluster.userEdited &&
                !storedIds.contains(cluster.id) &&
                _labelAttemptedIds.add(cluster.id)) {
              labeled.add(await labeler(cluster, graph));
            } else {
              labeled.add(cluster);
            }
          }
          clusters = List.unmodifiable(labeled);
        }
        if (!_disposed) {
          await _clusterStore.replace(clusters);
          await onClustersChanged?.call();
        }
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Semantic cluster rebuild unavailable: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _graphChangesSubscription?.cancel();
    _graphChangesSubscription = null;
    await cancelPending();
  }
}
