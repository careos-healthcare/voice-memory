import 'package:archiveme_mobile/core/di/archive_feed_providers.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/sync/application/conflict_resolution_store.dart';
import 'package:archiveme_mobile/features/sync/application/p2p_mesh_sync_engine.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The three sync states shown in the header badge.
enum SyncPresenceKind { synced, localOnly, conflictDetected }

/// Reachability plus any entries waiting on a manual merge.
@immutable
class SyncPresence {
  const SyncPresence({
    this.kind = SyncPresenceKind.localOnly,
    this.cloudReachable = false,
    this.meshHandshake = false,
    this.conflictEntryIds = const {},
  });

  final SyncPresenceKind kind;
  final bool cloudReachable;
  final bool meshHandshake;
  final Set<String> conflictEntryIds;

  bool get hasConflict => conflictEntryIds.isNotEmpty;

  /// Visible badge copy. Synced names the live channel.
  String get label {
    if (kind == SyncPresenceKind.conflictDetected || hasConflict) {
      return 'Conflict Detected';
    }
    if (kind == SyncPresenceKind.localOnly) return 'Local Only';
    if (meshHandshake && cloudReachable) return 'Synced (Mesh/Cloud)';
    if (meshHandshake) return 'Synced (Mesh)';
    if (cloudReachable) return 'Synced (Cloud)';
    return 'Synced (Mesh/Cloud)';
  }

  SyncPresence copyWith({
    SyncPresenceKind? kind,
    bool? cloudReachable,
    bool? meshHandshake,
    Set<String>? conflictEntryIds,
  }) {
    return SyncPresence(
      kind: kind ?? this.kind,
      cloudReachable: cloudReachable ?? this.cloudReachable,
      meshHandshake: meshHandshake ?? this.meshHandshake,
      conflictEntryIds: conflictEntryIds ?? this.conflictEntryIds,
    );
  }
}

/// Watches cloud reachability and P2P handshake, and clears conflicts
/// after a resolution is stored and announced to peers.
class SyncStateProvider extends Notifier<SyncPresence> {
  final Map<String, String> _remoteTranscripts = {};

  @override
  SyncPresence build() => const SyncPresence();

  String? remoteTranscript(String entryId) => _remoteTranscripts[entryId];

  void reportNetwork({
    required bool cloudReachable,
    required bool meshHandshake,
  }) {
    final conflicts = state.conflictEntryIds;
    state = SyncPresence(
      kind: conflicts.isNotEmpty
          ? SyncPresenceKind.conflictDetected
          : (cloudReachable || meshHandshake)
          ? SyncPresenceKind.synced
          : SyncPresenceKind.localOnly,
      cloudReachable: cloudReachable,
      meshHandshake: meshHandshake,
      conflictEntryIds: conflicts,
    );
  }

  void stageConflict({
    required String entryId,
    required String remoteTranscript,
  }) {
    _remoteTranscripts[entryId] = remoteTranscript;
    state = state.copyWith(
      kind: SyncPresenceKind.conflictDetected,
      conflictEntryIds: {...state.conflictEntryIds, entryId},
    );
  }

  Future<void> resolve(ConflictDecision decision) async {
    await ref.read(conflictResolutionStoreProvider).save(decision);
    ref.read(p2pMeshSyncEngineProvider).notifyResolved(decision);
    _remoteTranscripts.remove(decision.entryId);
    final remaining = {...state.conflictEntryIds}..remove(decision.entryId);
    final online = state.cloudReachable || state.meshHandshake;
    state = state.copyWith(
      kind: remaining.isNotEmpty
          ? SyncPresenceKind.conflictDetected
          : online
          ? SyncPresenceKind.synced
          : SyncPresenceKind.localOnly,
      conflictEntryIds: remaining,
    );
  }
}

final syncStateProvider = NotifierProvider<SyncStateProvider, SyncPresence>(
  SyncStateProvider.new,
);

/// Persists a resolved transcript through the journal store when one is bound.
class JournalConflictResolutionStore implements ConflictResolutionStore {
  JournalConflictResolutionStore(this._holder, {ConflictResolutionStore? memory})
    : _memory = memory ?? MemoryConflictResolutionStore();

  final JournalStoreHolder _holder;
  final ConflictResolutionStore _memory;

  @override
  Future<ConflictDecision?> read(String entryId) => _memory.read(entryId);

  @override
  Future<void> save(ConflictDecision decision) async {
    await _memory.save(decision);
    final journal = _holder.value;
    if (journal == null) return;
    try {
      final existing = await journal.getById(decision.entryId);
      if (existing == null) return;
      await journal.saveEdit(
        existing.copyWith(
          transcript: decision.resolvedText,
          syncStatus: SyncStatus.synced,
        ),
        first25Source: 'conflict_resolution',
      );
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Could not persist conflict resolution',
        name: 'JournalConflictResolutionStore',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final conflictResolutionStoreProvider = Provider<ConflictResolutionStore>((
  ref,
) {
  return JournalConflictResolutionStore(ref.watch(journalStoreHolderProvider));
});
