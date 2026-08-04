// ignore_for_file: prefer_initializing_formals

import '../semantic_clusters/semantic_cluster_sync_coordinator.dart';
import '../sync/e2ee_sync_models.dart';
import '../sync/encrypted_sync_engine.dart';
import 'action_plan_models.dart';
import 'action_plan_store.dart';

/// Bridges encrypted action-plan persistence to CRDT sync.
final class ActionPlanSyncCoordinator {
  ActionPlanSyncCoordinator({required ActionPlanStore store}) : _store = store;

  final ActionPlanStore _store;
  final Map<String, CrdtOperation> _appliedHeads = {};

  Future<void> recordCurrent(EncryptedSyncEngine syncEngine) async {
    final operations = await syncEngine.recordActionPlans(await _store.list());
    for (final operation in operations) {
      _rememberWinner(operation);
    }
  }

  bool handles(CrdtOperation operation) =>
      operation.entityKind == CrdtEntityKind.actionPlan;

  Future<bool> applyRemote(CrdtOperation operation) async {
    if (!handles(operation)) {
      throw ArgumentError.value(
        operation.entityKind,
        'operation',
        'must target an action plan',
      );
    }
    final current = _appliedHeads[operation.entityId];
    if (current != null && CrdtOperation.compare(operation, current) <= 0) {
      return false;
    }
    if (operation.mutation == CrdtMutation.delete) {
      await _store.remove(operation.entityId);
    } else {
      final plan = ActionPlan.fromJson(operation.payload);
      if (plan.id != operation.entityId) {
        throw const FormatException(
          'Action plan payload does not match its entity ID.',
        );
      }
      await _store.upsert(plan);
    }
    _rememberWinner(operation);
    return true;
  }

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
