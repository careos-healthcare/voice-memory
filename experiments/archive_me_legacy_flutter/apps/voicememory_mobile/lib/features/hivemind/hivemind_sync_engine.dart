import 'dart:async';

import '../p2p_mesh/sync/mesh_sync_engine.dart';
import '../p2p_mesh/sync/peer_sync_channel.dart';
import 'hivemind_mesh_router.dart';

enum HivemindSyncState { idle, reconciling, upToDate, paused, error }

final class HivemindSyncStatus {
  const HivemindSyncStatus({
    required this.peerId,
    required this.state,
    this.error,
  });

  final String peerId;
  final HivemindSyncState state;
  final Object? error;
}

final class HivemindSyncEngine {
  HivemindSyncEngine({
    required this.router,
    required this.meshSync,
    this.debounce = const Duration(milliseconds: 350),
  });

  final HivemindPeerRouter router;
  final MeshSyncEngine meshSync;
  final Duration debounce;
  final Map<String, AuthenticatedPeerSyncChannel> _channels = {};
  final Map<String, Timer> _timers = {};
  final Map<String, Future<void>> _tails = {};
  final StreamController<HivemindSyncStatus> _statuses =
      StreamController<HivemindSyncStatus>.broadcast();
  StreamSubscription<HivemindPeerChannel>? _connections;
  bool _paused = false;

  Stream<HivemindSyncStatus> get statuses => _statuses.stream;

  void start() {
    _connections ??= router.connectedChannels.listen((connection) {
      _channels[connection.peerId] = connection.syncChannel;
      if (router.governance.automaticSyncEnabled) {
        schedule(connection.peerId);
      }
    });
  }

  void schedule([String? peerId]) {
    if (_paused || !router.governance.automaticSyncEnabled) return;
    final targets = peerId == null ? _channels.keys : [peerId];
    for (final id in targets) {
      _timers.remove(id)?.cancel();
      _timers[id] = Timer(debounce, () => unawaited(_reconcile(id)));
    }
  }

  Future<void> reconcileNow([String? peerId]) async {
    if (_paused) return;
    final targets = peerId == null ? _channels.keys.toList() : [peerId];
    await Future.wait(targets.map(_reconcile));
  }

  Future<void> _reconcile(String peerId) {
    final channel = _channels[peerId];
    if (channel == null || _paused) return Future.value();
    final previous = _tails[peerId] ?? Future.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      if (_paused || _channels[peerId] == null) return;
      _statuses.add(
        HivemindSyncStatus(
          peerId: peerId,
          state: HivemindSyncState.reconciling,
        ),
      );
      try {
        await meshSync.synchronize(channel, initiator: true);
        _statuses.add(
          HivemindSyncStatus(peerId: peerId, state: HivemindSyncState.upToDate),
        );
      } on Object catch (error) {
        _statuses.add(
          HivemindSyncStatus(
            peerId: peerId,
            state: HivemindSyncState.error,
            error: error,
          ),
        );
      }
    });
    _tails[peerId] = next;
    return next;
  }

  Future<void> quiesce() async {
    _paused = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    await Future.wait(_tails.values);
  }

  void resume() {
    _paused = false;
    schedule();
  }

  Future<void> dispose() async {
    await quiesce();
    await _connections?.cancel();
    await _statuses.close();
  }
}
