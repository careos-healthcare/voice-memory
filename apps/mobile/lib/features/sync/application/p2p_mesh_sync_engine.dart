import 'package:archiveme_mobile/features/sync/application/conflict_resolution_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Announces a finished merge so other mesh peers drop the conflict warning.
class P2pMeshSyncEngine {
  final Map<String, ConflictDecision> _dismissed = {};

  Map<String, ConflictDecision> get dismissed => Map.unmodifiable(_dismissed);

  bool isConflictDismissed(String entryId) => _dismissed.containsKey(entryId);

  void notifyResolved(ConflictDecision decision) {
    _dismissed[decision.entryId] = decision;
  }
}

final p2pMeshSyncEngineProvider = Provider<P2pMeshSyncEngine>(
  (ref) => P2pMeshSyncEngine(),
);
