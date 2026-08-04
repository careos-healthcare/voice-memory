import 'dart:async';

import '../sync/encrypted_sync_engine.dart';
import 'mesh_discovery.dart';
import 'mesh_discovery_service.dart';
import 'mesh_models.dart';
import 'mesh_pairing_coordinator.dart';
import 'mesh_secure_session.dart';
import 'sync/mesh_sync_engine.dart';
import 'sync/peer_channel_multiplexer.dart';
import 'sync/peer_sync_channel.dart';
import 'ui/mesh_ui_models.dart';

class MeshController {
  MeshController({
    required this.discovery,
    required this.pairing,
    required this.sync,
    required this.encryptedSync,
  });

  final MeshDiscoveryService discovery;
  final MeshPairingCoordinator pairing;
  final MeshSyncEngine sync;
  final EncryptedSyncEngine encryptedSync;
  final _views = StreamController<List<MeshPeerViewState>>.broadcast();
  final _sessionChannels = StreamController<MeshSessionChannels>.broadcast();
  final Map<String, MeshPeerViewState> _state = {};
  final Map<String, _PendingPeer> _pending = {};
  final Map<String, MeshSecureSession> _sessions = {};
  final Map<String, PeerChannelMultiplexer> _multiplexers = {};
  final Map<String, AuthenticatedPeerSyncChannel> _syncChannels = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _started = false;
  MeshPairingInvitation? _activeInvitation;

  Stream<List<MeshPeerViewState>> get views => _views.stream;
  Stream<MeshSessionChannels> get sessionChannels => _sessionChannels.stream;
  List<MeshPeerViewState> get currentViews => List.unmodifiable(_state.values);

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscriptions.add(discovery.peers.listen(_onDiscovered));
    _subscriptions.add(
      discovery.incomingConnections.listen((connection) {
        unawaited(_acceptIncoming(connection));
      }),
    );
    _subscriptions.add(sync.progress.listen(_onProgress));
    try {
      await discovery.start();
    } on Object {
      _started = false;
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      rethrow;
    }
  }

  Future<void> beginPairing(
    MeshPeer peer, {
    MeshPairingInvitation? invitation,
  }) async {
    final connection = await discovery.connect(peer);
    try {
      final pending = await MeshHandshake.initiate(
        connection: connection,
        identity: discovery.identity,
        invitation: invitation,
      );
      _pending[peer.id] = _PendingPeer(pending: pending, incoming: false);
      _state[peer.id] = MeshPeerViewState(
        peer: peer,
        pairingState: MeshPairingState.awaitingConfirmation,
        sas: pending.sas,
      );
      _emit();
    } on Object {
      await connection.close();
      rethrow;
    }
  }

  Future<void> beginPairingInvitation(String encodedInvitation) async {
    final invitation = MeshPairingInvitation.decode(encodedInvitation);
    final peer = discovery.nearbyPeers
        .where((candidate) => candidate.id == invitation.serviceId)
        .firstOrNull;
    if (peer == null) {
      throw StateError('The device in this QR code is not nearby.');
    }
    await beginPairing(peer, invitation: invitation);
  }

  Future<MeshPairingInvitation> createPairingInvitation() async {
    final serviceId = discovery.currentServiceId;
    if (serviceId == null) {
      throw StateError('Start nearby discovery before creating a QR code.');
    }
    final invitation = await pairing.createInvitation(serviceId: serviceId);
    _activeInvitation = invitation;
    return invitation;
  }

  Future<void> _acceptIncoming(MeshConnection connection) async {
    try {
      final pending = await MeshHandshake.respond(
        connection: connection,
        identity: discovery.identity,
        invitationNonce:
            _activeInvitation?.expiresAt.isAfter(DateTime.now()) == true
            ? _activeInvitation!.oneTimeNonce
            : null,
      );
      _activeInvitation = null;
      final peer = MeshPeer(
        id: pending.remoteDeviceId,
        name: 'Nearby ArchiveMe device',
        host: connection.remoteAddress,
        port: 1,
        identityFingerprint: pending.remoteFingerprint,
      );
      _pending[peer.id] = _PendingPeer(pending: pending, incoming: true);
      _state[peer.id] = MeshPeerViewState(
        peer: peer,
        pairingState: MeshPairingState.awaitingConfirmation,
        sas: pending.sas,
      );
      _emit();
    } on Object {
      await connection.close();
    }
  }

  Future<void> confirmPairing(MeshPeer peer, bool confirmed) async {
    final holder = _pending.remove(peer.id);
    if (holder == null) {
      throw StateError('No pending pairing exists for this peer.');
    }
    if (!confirmed) {
      await holder.pending.session.close();
      _state.remove(peer.id);
      _emit();
      return;
    }
    final trusted = await pairing.confirmAndTrust(
      holder.pending,
      displayName: peer.name,
    );
    if (holder.incoming) {
      await pairing.receiveSyncIdentity(holder.pending.session);
      await encryptedSync.reinitializeVectorClockFromOutbox();
    } else {
      await pairing.sendSyncIdentity(holder.pending.session);
    }
    final trustedPeer = MeshPeer(
      id: trusted.deviceId,
      name: trusted.displayName,
      host: peer.host,
      port: peer.port,
      identityFingerprint: trusted.fingerprint,
    );
    _state.remove(peer.id);
    _state[trusted.deviceId] = MeshPeerViewState(
      peer: trustedPeer,
      isTrusted: true,
      pairingState: MeshPairingState.paired,
    );
    _sessions[trusted.deviceId] = holder.pending.session;
    final multiplexer = PeerChannelMultiplexer(holder.pending.session);
    _multiplexers[trusted.deviceId] = multiplexer;
    final syncChannel = multiplexer.channel(
      'sync',
      accepts: (packet) => _syncPacketTypes.contains(packet['type']),
    );
    final hivemindChannel = multiplexer.channel(
      'hivemind',
      accepts: (packet) => '${packet['type']}'.startsWith('hivemind_'),
    );
    _syncChannels[trusted.deviceId] = syncChannel;
    _listenForIncomingSync(syncChannel);
    _sessionChannels.add(
      MeshSessionChannels(
        peerId: trusted.deviceId,
        sync: syncChannel,
        hivemind: hivemindChannel,
      ),
    );
    _emit();
  }

  void _listenForIncomingSync(AuthenticatedPeerSyncChannel channel) {
    final subscription = channel.packets.listen((packet) {
      if (packet['type'] != 'sync_start') return;
      unawaited(
        sync
            .synchronize(channel, initiator: false, initialRequest: packet)
            .catchError((Object _) {}),
      );
    });
    _subscriptions.add(subscription);
  }

  Future<void> synchronize(MeshPeer peer) async {
    final channel = _syncChannels[peer.id];
    if (channel == null) {
      throw StateError('Pair with this device before synchronizing.');
    }
    await sync.synchronize(channel, initiator: true);
  }

  Future<void> revoke(MeshPeer peer) async {
    await pairing.revoke(peer.id);
    await _multiplexers.remove(peer.id)?.close();
    _syncChannels.remove(peer.id);
    await _sessions.remove(peer.id)?.close();
    _state.remove(peer.id);
    _emit();
  }

  void _onDiscovered(List<MeshPeer> peers) {
    final discoveredIds = peers.map((peer) => peer.id).toSet();
    _state.removeWhere(
      (id, state) =>
          state.pairingState == MeshPairingState.unpaired &&
          !discoveredIds.contains(id),
    );
    for (final peer in peers) {
      _state.putIfAbsent(peer.id, () => MeshPeerViewState(peer: peer));
    }
    _emit();
  }

  void _onProgress(MeshSyncProgress progress) {
    final current = _state[progress.peerId];
    if (current == null) return;
    final state = switch (progress.state) {
      MeshEngineState.reconciling => MeshSyncState.syncing,
      MeshEngineState.upToDate => MeshSyncState.complete,
      MeshEngineState.error ||
      MeshEngineState.disconnected => MeshSyncState.failed,
      MeshEngineState.idle => MeshSyncState.idle,
    };
    final total = progress.sentChunks + progress.receivedChunks;
    _state[progress.peerId] = MeshPeerViewState(
      peer: current.peer,
      isTrusted: current.isTrusted,
      pairingState: current.pairingState,
      sas: current.sas,
      syncState: state,
      syncProgress: state == MeshSyncState.complete
          ? 1
          : total == 0
          ? 0
          : (progress.receivedChunks / total).clamp(0, 1),
      syncError: progress.error?.toString(),
    );
    _emit();
  }

  void _emit() {
    final values = _state.values.toList()
      ..sort((left, right) => left.peer.name.compareTo(right.peer.name));
    _views.add(List.unmodifiable(values));
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final session in _sessions.values) {
      await session.close();
    }
    for (final multiplexer in _multiplexers.values) {
      await multiplexer.close();
    }
    for (final holder in _pending.values) {
      await holder.pending.session.close();
    }
    await _views.close();
    await _sessionChannels.close();
  }
}

const _syncPacketTypes = {
  'sync_start',
  'sync_summary',
  'crdt_chunk',
  'crdt_ack',
};

final class MeshSessionChannels {
  const MeshSessionChannels({
    required this.peerId,
    required this.sync,
    required this.hivemind,
  });

  final String peerId;
  final AuthenticatedPeerSyncChannel sync;
  final AuthenticatedPeerSyncChannel hivemind;
}

class _PendingPeer {
  const _PendingPeer({required this.pending, required this.incoming});

  final MeshPendingSession pending;
  final bool incoming;
}
