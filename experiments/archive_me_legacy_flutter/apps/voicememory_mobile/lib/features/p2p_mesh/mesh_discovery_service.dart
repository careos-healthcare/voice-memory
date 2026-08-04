import 'dart:async';
import 'dart:math';

import '../../services/security/mesh_identity_service.dart';
import 'mesh_discovery.dart';
import 'mesh_models.dart';

enum MeshDiscoveryState { stopped, searching, active, error }

/// Privacy-preserving lifecycle wrapper around the platform discovery adapter.
///
/// Discovery is opt-in: construction never opens a listener or triggers the
/// local-network permission prompt.
class MeshDiscoveryService {
  MeshDiscoveryService({
    required this.adapter,
    required this.identity,
    Random? random,
  }) : _random = random ?? Random.secure();

  final MeshDiscoveryAdapter adapter;
  final MeshIdentityService identity;
  final Random _random;
  final _states = StreamController<MeshDiscoveryState>.broadcast();
  final _peers = StreamController<List<MeshPeer>>.broadcast();
  final Map<String, MeshPeer> _nearby = {};
  StreamSubscription<MeshPeerEvent>? _peerSubscription;
  MeshDiscoveryState _state = MeshDiscoveryState.stopped;
  String? _serviceId;

  MeshDiscoveryState get state => _state;
  Stream<MeshDiscoveryState> get states => _states.stream;
  Stream<List<MeshPeer>> get peers => _peers.stream;
  Stream<MeshConnection> get incomingConnections => adapter.incomingConnections;
  List<MeshPeer> get nearbyPeers => List.unmodifiable(_nearby.values);
  String? get currentServiceId => _serviceId;

  Future<void> start() async {
    if (_state == MeshDiscoveryState.searching ||
        _state == MeshDiscoveryState.active) {
      return;
    }
    _emit(MeshDiscoveryState.searching);
    try {
      final localIdentity = await identity.identity();
      final serviceId = _opaqueServiceId();
      _serviceId = serviceId;
      _peerSubscription ??= adapter.peerEvents.listen(
        _onPeerEvent,
        onError: (Object _, StackTrace _) => _emit(MeshDiscoveryState.error),
      );
      await adapter.advertise(
        MeshAdvertisement(
          peerId: serviceId,
          displayName: 'ArchiveMe',
          // The adapter deliberately does not advertise this field.
          identityFingerprint: localIdentity.fingerprint,
        ),
      );
      await adapter.startDiscovery(excludePeerId: serviceId);
      _emit(MeshDiscoveryState.active);
    } on Object {
      await adapter.stop();
      _emit(MeshDiscoveryState.error);
      rethrow;
    }
  }

  Future<MeshConnection> connect(MeshPeer peer) => adapter.connect(peer);

  Future<void> stop() async {
    await adapter.stop();
    _nearby.clear();
    _serviceId = null;
    _peers.add(const []);
    _emit(MeshDiscoveryState.stopped);
  }

  void _onPeerEvent(MeshPeerEvent event) {
    if (event.kind == MeshPeerEventKind.found) {
      _nearby[event.peer.id] = event.peer;
    } else {
      _nearby.remove(event.peer.id);
    }
    final snapshot = _nearby.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    _peers.add(List.unmodifiable(snapshot));
  }

  String _opaqueServiceId() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  void _emit(MeshDiscoveryState state) {
    _state = state;
    _states.add(state);
  }

  Future<void> dispose() async {
    await _peerSubscription?.cancel();
    await adapter.dispose();
    await _states.close();
    await _peers.close();
  }
}
