import 'dart:async';

import 'package:archiveme_mobile/features/sync/mesh_offload_sync_service.dart';
import 'package:flutter/foundation.dart';

/// How far an archive save has moved through the local mesh queue.
enum MeshOffloadSavePhase { optimistic, resolving, settled }

/// One archive the UI already shows, before mesh settle finishes.
class MeshOffloadOptimisticSave {
  const MeshOffloadOptimisticSave({
    required this.id,
    required this.preview,
    required this.phase,
    this.settledLabel,
  });

  final String id;
  final String preview;
  final MeshOffloadSavePhase phase;
  final String? settledLabel;

  MeshOffloadOptimisticSave copyWith({
    MeshOffloadSavePhase? phase,
    String? preview,
    String? settledLabel,
  }) {
    return MeshOffloadOptimisticSave(
      id: id,
      preview: preview ?? this.preview,
      phase: phase ?? this.phase,
      settledLabel: settledLabel ?? this.settledLabel,
    );
  }
}

/// Local words stay when a peer copy differs. The row does not wait on that.
class MeshOffloadConflictSettle {
  const MeshOffloadConflictSettle({
    required this.preview,
    required this.merged,
  });

  factory MeshOffloadConflictSettle.resolve({
    required String localPreview,
    String? remotePreview,
  }) {
    final local = localPreview.trim();
    final remote = remotePreview?.trim();
    if (remote == null || remote.isEmpty || remote == local) {
      return MeshOffloadConflictSettle(preview: local, merged: false);
    }
    return MeshOffloadConflictSettle(preview: local, merged: true);
  }

  final String preview;
  final bool merged;
}

/// Publishes a saved archive immediately, then settles the mesh in the background.
class MeshOffloadOptimisticCoordinator extends ChangeNotifier {
  MeshOffloadOptimisticCoordinator();

  static final instance = MeshOffloadOptimisticCoordinator();

  static const defaultSkeletonHold = Duration(milliseconds: 360);
  static const savedOnDeviceLabel = 'Saved on this device';
  static const meshSettledLabel = 'Mesh settled';

  final List<MeshOffloadOptimisticSave> _saves = [];

  List<MeshOffloadOptimisticSave> get saves => List.unmodifiable(_saves);

  MeshOffloadOptimisticSave? lookup(String id) {
    for (final save in _saves) {
      if (save.id == id) return save;
    }
    return null;
  }

  void resetForTest() {
    _saves.clear();
    notifyListeners();
  }

  /// Shows [preview] before any mesh or merge work. The returned future
  /// finishes when the skeleton hold and the background settle both end.
  Future<void> beginArchiveSave({
    required String id,
    required String preview,
    Duration skeletonHold = defaultSkeletonHold,
    MeshOffloadSyncService? mesh,
    Map<String, dynamic>? meshPayload,
    String? remotePreview,
    Future<void> Function()? resolveConflicts,
  }) async {
    final text = preview.trim().isEmpty ? 'Moment saved' : preview.trim();
    _put(
      MeshOffloadOptimisticSave(
        id: id,
        preview: text,
        phase: MeshOffloadSavePhase.optimistic,
      ),
    );
    notifyListeners();

    await Future<void>.delayed(Duration.zero);

    _put(
      MeshOffloadOptimisticSave(
        id: id,
        preview: text,
        phase: MeshOffloadSavePhase.resolving,
      ),
    );
    notifyListeners();

    final hold = Future<void>.delayed(skeletonHold);
    var label = savedOnDeviceLabel;
    if (mesh != null) {
      await mesh.enqueue(
        id: id,
        payload: meshPayload ?? {'id': id, 'preview': text},
      );
      final flush = await mesh.flush();
      if (flush.delivered > 0) label = meshSettledLabel;
    }
    final settle = MeshOffloadConflictSettle.resolve(
      localPreview: text,
      remotePreview: remotePreview,
    );
    if (resolveConflicts != null) {
      await resolveConflicts();
    }
    await hold;
    _put(
      MeshOffloadOptimisticSave(
        id: id,
        preview: settle.preview,
        phase: MeshOffloadSavePhase.settled,
        settledLabel: label,
      ),
    );
    notifyListeners();
  }

  void _put(MeshOffloadOptimisticSave save) {
    final index = _saves.indexWhere((existing) => existing.id == save.id);
    if (index < 0) {
      _saves.insert(0, save);
    } else {
      _saves[index] = save;
    }
  }
}
