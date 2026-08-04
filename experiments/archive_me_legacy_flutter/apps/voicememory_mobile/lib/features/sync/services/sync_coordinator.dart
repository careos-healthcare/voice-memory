import 'dart:async';
import 'dart:convert';

import '../../../models/journal_entry.dart';
import '../../../storage/journal_store.dart';
import '../models/sync_conflict_resolution.dart';
import 'p2p_mesh_service.dart';

/// Bridges durable journal changes with nearby peer transport.
class SyncCoordinator {
  factory SyncCoordinator({
    required JournalStore journalStore,
    required P2PMeshService meshService,
  }) {
    return SyncCoordinator._(journalStore, meshService);
  }

  SyncCoordinator._(this._journalStore, this._meshService);

  final JournalStore _journalStore;
  final P2PMeshService _meshService;
  final Map<String, String> _lastFingerprints = {};
  final Map<String, String> _remoteFingerprintsToSuppress = {};

  StreamSubscription<List<JournalEntry>>? _journalSubscription;
  StreamSubscription<MeshJsonPayload>? _remoteSubscription;
  Future<void> _incomingQueue = Future.value();
  bool _hasInitialSnapshot = false;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _journalSubscription = _journalStore.watchAll().listen(_onJournalChanged);
    _remoteSubscription = _meshService.receivedEntries.listen((payload) {
      _incomingQueue = _incomingQueue
          .then((_) => _applyRemotePayload(payload))
          .onError((_, _) {});
    });
  }

  Future<void> stop() async {
    _started = false;
    await _journalSubscription?.cancel();
    await _remoteSubscription?.cancel();
    _journalSubscription = null;
    _remoteSubscription = null;
    await _incomingQueue;
  }

  void _onJournalChanged(List<JournalEntry> entries) {
    final current = <String, String>{
      for (final entry in entries) entry.id: _fingerprint(entry),
    };
    if (!_hasInitialSnapshot) {
      _hasInitialSnapshot = true;
      _lastFingerprints
        ..clear()
        ..addAll(current);
      return;
    }

    for (final entry in entries) {
      final fingerprint = current[entry.id]!;
      if (_lastFingerprints[entry.id] == fingerprint) continue;
      if (_remoteFingerprintsToSuppress.remove(entry.id) == fingerprint) {
        continue;
      }
      unawaited(
        _meshService.broadcastEntry(entry.toJson(includeLocalContext: false)),
      );
    }
    _lastFingerprints
      ..clear()
      ..addAll(current);
  }

  Future<void> _applyRemotePayload(MeshJsonPayload payload) async {
    final remote = JournalEntry.fromJson(payload);
    if (remote.id.trim().isEmpty) {
      throw const FormatException('Peer journal entry is missing an id.');
    }
    final entries = await _journalStore.loadAll();
    final local = entries.where((entry) => entry.id == remote.id).firstOrNull;
    if (local == null) {
      _remoteFingerprintsToSuppress[remote.id] = _fingerprint(remote);
      await _journalStore.replaceAll([remote, ...entries]);
      return;
    }
    final winner = SyncConflictResolution.resolve(local: local, remote: remote);
    if (identical(winner, local)) return;
    _remoteFingerprintsToSuppress[winner.id] = _fingerprint(winner);
    await _journalStore.replaceAll([
      winner,
      ...entries.where((entry) => entry.id != winner.id),
    ]);
  }

  String _fingerprint(JournalEntry entry) {
    final json = entry.toJson(includeLocalContext: false)
      ..remove('localAudioPath')
      ..remove('localAudioVaultRef');
    return jsonEncode(json);
  }
}
