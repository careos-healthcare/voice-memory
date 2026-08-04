import '../sync/e2ee_sync_models.dart';
import '../sync/encrypted_sync_engine.dart';
import 'semantic_cluster.dart';
import 'semantic_cluster_store.dart';

typedef AuxiliaryCrdtOperationHandler =
    Future<void> Function(CrdtOperation operation);

/// Wires semantic-cluster persistence into encrypted CRDT sync without
/// requiring the application service container to own merge policy.
final class SemanticClusterSyncCoordinator {
  SemanticClusterSyncCoordinator({required SemanticClusterStore store})
    : // Public named parameters cannot initialize private fields directly.
      // ignore: prefer_initializing_formals
      _store = store;

  final SemanticClusterStore _store;
  final Map<String, CrdtOperation> _appliedHeads = {};

  /// Records the complete portable snapshot, including deletes created by
  /// local merge and split overrides.
  Future<void> recordCurrent(EncryptedSyncEngine syncEngine) async {
    final operations = await syncEngine.recordSemanticClusters(
      await _store.list(),
    );
    for (final operation in operations) {
      _rememberWinner(operation);
    }
  }

  bool handles(CrdtOperation operation) =>
      operation.entityKind == CrdtEntityKind.semanticCluster;

  /// Applies a cluster operation only when it is the deterministic CRDT winner.
  ///
  /// [EncryptedSyncEngine] already dispatches only winning remote heads. The
  /// additional comparison here makes direct/coordinator reuse order
  /// independent and prevents an older remote value from replacing a local
  /// user-edited winner registered by [recordCurrent].
  Future<bool> applyRemote(CrdtOperation operation) async {
    if (!handles(operation)) {
      throw ArgumentError.value(
        operation.entityKind,
        'operation',
        'must target a semantic cluster',
      );
    }
    final current = _appliedHeads[operation.entityId];
    if (current != null && CrdtOperation.compare(operation, current) <= 0) {
      return false;
    }

    if (operation.mutation == CrdtMutation.delete) {
      await _store.remove(operation.entityId);
    } else {
      final cluster = SemanticCluster.fromJson(operation.payload);
      if (cluster.id != operation.entityId) {
        throw const FormatException(
          'Semantic cluster payload does not match its entity ID.',
        );
      }
      await _store.upsert(cluster);
    }
    _rememberWinner(operation);
    return true;
  }

  /// A callback suitable for `EncryptedSyncEngine.applyAuxiliaryOperation`.
  ///
  /// Existing transcript/media handling can be retained as [fallback].
  AuxiliaryCrdtOperationHandler handler({
    AuxiliaryCrdtOperationHandler? fallback,
  }) => (operation) async {
    if (handles(operation)) {
      await applyRemote(operation);
      return;
    }
    await fallback?.call(operation);
  };

  void _rememberWinner(CrdtOperation operation) {
    final current = _appliedHeads[operation.entityId];
    if (current == null || CrdtOperation.compare(operation, current) > 0) {
      _appliedHeads[operation.entityId] = operation;
    }
  }
}
