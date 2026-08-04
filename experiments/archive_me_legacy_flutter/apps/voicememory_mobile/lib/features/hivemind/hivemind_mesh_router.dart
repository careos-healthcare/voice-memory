import 'dart:async';
import 'dart:math';

import '../p2p_mesh/mesh_controller.dart';
import '../p2p_mesh/mesh_discovery_service.dart';
import '../p2p_mesh/mesh_trust_store.dart';
import '../p2p_mesh/sync/peer_sync_channel.dart';
import '../../services/p2p_mesh/peer_discovery_manager.dart';
import 'hivemind_models.dart';
import 'hivemind_store.dart';

abstract interface class HivemindTransportBackend {
  Future<HivemindTransportCapability> capability();
}

final class NsdTcpHivemindTransportBackend implements HivemindTransportBackend {
  const NsdTcpHivemindTransportBackend();

  @override
  Future<HivemindTransportCapability> capability() async =>
      const HivemindTransportCapability(
        kind: HivemindTransportKind.nsdTcp,
        available: true,
        contractVersion: 1,
        backend: 'encrypted-nsd-tcp',
        reason: '',
      );
}

final class UnavailableHivemindTransportBackend
    implements HivemindTransportBackend {
  const UnavailableHivemindTransportBackend(this.kind, this.reason);

  final HivemindTransportKind kind;
  final String reason;

  @override
  Future<HivemindTransportCapability> capability() async =>
      HivemindTransportCapability.unavailable(kind, reason);
}

final class AvailableHivemindTransportBackend
    implements HivemindTransportBackend {
  const AvailableHivemindTransportBackend(this.kind, this.backend);

  final HivemindTransportKind kind;
  final String backend;

  @override
  Future<HivemindTransportCapability> capability() async =>
      HivemindTransportCapability(
        kind: kind,
        available: true,
        contractVersion: 1,
        backend: backend,
        reason: '',
      );
}

final class HivemindPeerChannel {
  const HivemindPeerChannel({
    required this.peerId,
    required this.channel,
    required this.syncChannel,
  });

  final String peerId;
  final AuthenticatedPeerSyncChannel channel;
  final AuthenticatedPeerSyncChannel syncChannel;
}

abstract interface class HivemindPeerRouter {
  Stream<HivemindPeerChannel> get connectedChannels;
  List<HivemindPeerState> get currentPeers;
  HivemindGovernance get governance;
}

final class HivemindMeshRouter implements HivemindPeerRouter {
  HivemindMeshRouter({
    required this.controller,
    required this.discovery,
    required this.trustStore,
    required this.store,
    this.sovereignDiscovery,
    List<HivemindTransportBackend>? transports,
    DateTime Function()? clock,
    Random? random,
    this.embeddingFingerprint,
    this.llmFingerprint,
    this.localGpuState = HivemindGpuState.unavailable,
  }) : transports =
           transports ??
           const [
             NsdTcpHivemindTransportBackend(),
             AvailableHivemindTransportBackend(
               HivemindTransportKind.webRtc,
               'local-webrtc-dtls-data-channel',
             ),
             AvailableHivemindTransportBackend(
               HivemindTransportKind.ble,
               'ble-advertisement-and-scan',
             ),
             UnavailableHivemindTransportBackend(
               HivemindTransportKind.noiseXX,
               'Formal Noise XX is not bound to the packaged native ABI. '
               'The active mesh uses signed ephemeral X25519 with '
               'AES-256-GCM.',
             ),
           ],
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final MeshController controller;
  final MeshDiscoveryService discovery;
  final MeshTrustStore trustStore;
  final HivemindStore store;
  final PeerDiscoveryManager? sovereignDiscovery;
  final List<HivemindTransportBackend> transports;
  final String? embeddingFingerprint;
  final String? llmFingerprint;
  final HivemindGpuState localGpuState;
  final DateTime Function() _clock;
  final Random _random;
  final Map<String, HivemindPeerState> _peers = {};
  final Map<String, AuthenticatedPeerSyncChannel> _channels = {};
  final Map<String, StreamSubscription<Map<String, dynamic>>> _packetSubs = {};
  final Map<String, DateTime> _pendingPings = {};
  final StreamController<List<HivemindPeerState>> _peerStates =
      StreamController<List<HivemindPeerState>>.broadcast();
  final StreamController<HivemindPeerChannel> _connectedChannels =
      StreamController<HivemindPeerChannel>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _heartbeat;
  HivemindGovernance _governance = const HivemindGovernance();
  bool _started = false;

  Stream<List<HivemindPeerState>> get peers => _peerStates.stream;
  @override
  Stream<HivemindPeerChannel> get connectedChannels =>
      _connectedChannels.stream;
  @override
  List<HivemindPeerState> get currentPeers => List.unmodifiable(_peers.values);
  @override
  HivemindGovernance get governance => _governance;

  Future<List<HivemindTransportCapability>> capabilities() =>
      Future.wait(transports.map((backend) => backend.capability()));

  void updatePeerTelemetry(
    String peerId, {
    required double throughputBytesPerSecond,
    required Duration latency,
  }) {
    final peer = _peers[peerId];
    if (peer == null) return;
    _peers[peerId] = peer.copyWith(
      throughputBytesPerSecond: throughputBytesPerSecond,
      latency: latency == Duration.zero ? peer.latency : latency,
      transport: HivemindTransportKind.webRtc,
      lastSeenAt: _clock().toUtc(),
    );
    _emit();
  }

  Future<void> initialize() async {
    _governance = await store.governance();
    _subscriptions.add(controller.sessionChannels.listen(_attach));
    _subscriptions.add(
      controller.views.listen((views) {
        final connected = views.map((view) => view.peer.id).toSet();
        for (final peerId in _peers.keys.toList()) {
          if (!connected.contains(peerId)) _disconnect(peerId);
        }
      }),
    );
    if (_governance.discoveryEnabled) await start();
  }

  Future<void> updateGovernance(HivemindGovernance governance) async {
    _governance = governance;
    await store.writeGovernance(governance);
    if (governance.discoveryEnabled) {
      await start();
    } else {
      await stop();
    }
    await _broadcastCapability();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await controller.start();
      await sovereignDiscovery?.start();
      _heartbeat = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_pingAll()),
      );
    } on Object {
      _started = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    _started = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    await sovereignDiscovery?.stop();
    await discovery.stop();
    for (final peerId in _channels.keys.toList()) {
      await _disconnect(peerId);
    }
  }

  Future<void> _attach(MeshSessionChannels channels) async {
    final trusted = await trustStore.find(channels.peerId);
    if (trusted == null || _channels.containsKey(channels.peerId)) return;
    _channels[channels.peerId] = channels.hivemind;
    _peers[channels.peerId] = HivemindPeerState(
      peerId: channels.peerId,
      displayName: trusted.displayName,
      connected: true,
      trusted: true,
      lastSeenAt: _clock().toUtc(),
    );
    _packetSubs[channels.peerId] = channels.hivemind.packets.listen(
      (packet) => _handlePacket(channels.peerId, packet),
      onError: (_, _) => unawaited(_disconnect(channels.peerId)),
      onDone: () => unawaited(_disconnect(channels.peerId)),
    );
    _connectedChannels.add(
      HivemindPeerChannel(
        peerId: channels.peerId,
        channel: channels.hivemind,
        syncChannel: channels.sync,
      ),
    );
    _emit();
    await _sendCapability(channels.hivemind);
  }

  Future<void> _broadcastCapability() =>
      Future.wait(_channels.values.map(_sendCapability));

  Future<void> _sendCapability(AuthenticatedPeerSyncChannel channel) =>
      channel.send({
        'version': 1,
        'type': 'hivemind_capability',
        'sourceDeviceId': 'local',
        'acceptRemoteCompute': _governance.acceptRemoteCompute,
        'gpuState': localGpuState.name,
        'embeddingFingerprint': embeddingFingerprint,
        'llmFingerprint': llmFingerprint,
        'nonce': _nonce(),
      });

  Future<void> _pingAll() async {
    final now = _clock().toUtc();
    for (final entry in _channels.entries) {
      final nonce = _nonce();
      _pendingPings['${entry.key}:$nonce'] = now;
      await entry.value.send({
        'version': 1,
        'type': 'hivemind_ping',
        'nonce': nonce,
        'sentAt': now.toIso8601String(),
      });
    }
  }

  Future<void> _handlePacket(String peerId, Map<String, dynamic> packet) async {
    if (packet['version'] != 1 || packet['nonce'] is! String) return;
    final channel = _channels[peerId];
    if (channel == null) return;
    switch (packet['type']) {
      case 'hivemind_ping':
        await channel.send({
          'version': 1,
          'type': 'hivemind_pong',
          'nonce': packet['nonce'],
        });
        return;
      case 'hivemind_pong':
        final sent = _pendingPings.remove('$peerId:${packet['nonce']}');
        if (sent != null) {
          _peers[peerId] = _peers[peerId]!.copyWith(
            latency: _clock().toUtc().difference(sent),
            lastSeenAt: _clock().toUtc(),
          );
          _emit();
        }
        return;
      case 'hivemind_capability':
        _peers[peerId] = _peers[peerId]!.copyWith(
          offloadAccepted: packet['acceptRemoteCompute'] == true,
          gpuState: HivemindGpuState.values.firstWhere(
            (state) => state.name == packet['gpuState'],
            orElse: () => HivemindGpuState.unavailable,
          ),
          embeddingFingerprint: packet['embeddingFingerprint'] as String?,
          llmFingerprint: packet['llmFingerprint'] as String?,
          lastSeenAt: _clock().toUtc(),
        );
        _emit();
        return;
    }
  }

  Future<void> _disconnect(String peerId) async {
    await _packetSubs.remove(peerId)?.cancel();
    _channels.remove(peerId);
    final current = _peers[peerId];
    if (current != null) {
      _peers[peerId] = current.copyWith(
        connected: false,
        lastSeenAt: _clock().toUtc(),
      );
    }
    _pendingPings.removeWhere((key, _) => key.startsWith('$peerId:'));
    _emit();
  }

  String _nonce() => List<int>.generate(
    16,
    (_) => _random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  void _emit() {
    final values = _peers.values.toList()
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
    _peerStates.add(List.unmodifiable(values));
  }

  Future<void> dispose() async {
    await stop();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _peerStates.close();
    await _connectedChannels.close();
  }
}
