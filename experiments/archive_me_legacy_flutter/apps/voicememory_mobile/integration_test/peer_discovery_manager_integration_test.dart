import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_discovery.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_discovery_service.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_models.dart';
import 'package:voicememory_mobile/features/p2p_mesh/mesh_secure_session.dart';
import 'package:voicememory_mobile/services/p2p_mesh/peer_discovery_manager.dart';
import 'package:voicememory_mobile/services/security/mesh_identity_service.dart';
import 'package:voicememory_mobile/services/security/sync_identity_service.dart';

void main() {
  testWidgets('mDNS discovery establishes a verified encrypted session', (
    tester,
  ) async {
    final initiatorIdentity = MeshIdentityService(
      store: MemorySyncIdentityStore(),
      random: Random(11),
      deviceIdProvider: () async => 'mobile-edge',
    );
    final responderIdentity = MeshIdentityService(
      store: MemorySyncIdentityStore(),
      random: Random(22),
      deviceIdProvider: () async => 'desktop-anchor',
    );
    final responderPublic = await responderIdentity.identity();
    final adapter = _DiscoveryAdapter(
      responderIdentity: responderIdentity,
      peer: MeshPeer(
        id: 'desktop-anchor',
        name: 'Desktop Anchor',
        host: '192.168.1.20',
        port: 4242,
        identityFingerprint: responderPublic.fingerprint,
      ),
    );
    final ble = _BleBackend();
    final manager = PeerDiscoveryManager(
      mdns: MeshDiscoveryService(
        adapter: adapter,
        identity: initiatorIdentity,
        random: Random(33),
      ),
      ble: ble,
    );
    addTearDown(manager.dispose);

    await manager.start();
    await tester.pump();
    final peer = manager.currentPeers.single;
    expect(peer.transports, contains(SovereignPeerTransport.mdns));

    final session = await manager.establishAuthenticatedSession(peer);
    final responder = await adapter.responderSession;

    expect(session.peerId, 'desktop-anchor');
    expect(session.verifiedFingerprint, responderPublic.fingerprint);
    expect(session.shortAuthenticationString, responder.sas);
    await Future.wait([session.pending.confirm(), responder.confirm()]);
    expect(session.pending.session.isPairingConfirmed, isTrue);

    await session.pending.session.close();
    await responder.session.close();
  });
}

final class _DiscoveryAdapter implements MeshDiscoveryAdapter {
  _DiscoveryAdapter({required this.responderIdentity, required this.peer});

  final MeshIdentityService responderIdentity;
  final MeshPeer peer;
  final StreamController<MeshPeerEvent> _events =
      StreamController<MeshPeerEvent>.broadcast();
  final StreamController<MeshConnection> _incoming =
      StreamController<MeshConnection>.broadcast();
  final Completer<MeshPendingSession> _responder =
      Completer<MeshPendingSession>();

  Future<MeshPendingSession> get responderSession => _responder.future;

  @override
  Stream<MeshPeerEvent> get peerEvents => _events.stream;

  @override
  Stream<MeshConnection> get incomingConnections => _incoming.stream;

  @override
  Future<int> advertise(MeshAdvertisement advertisement) async => 4243;

  @override
  Future<void> startDiscovery({String? excludePeerId}) async {
    _events.add(MeshPeerEvent(kind: MeshPeerEventKind.found, peer: peer));
  }

  @override
  Future<MeshConnection> connect(
    MeshPeer peer, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final pair = _MemoryConnection.pair();
    unawaited(
      MeshHandshake.respond(
        connection: pair.$2,
        identity: responderIdentity,
      ).then(_responder.complete, onError: _responder.completeError),
    );
    return pair.$1;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _events.close();
    await _incoming.close();
  }
}

final class _BleBackend implements BlePeerDiscoveryBackend {
  final StreamController<BlePeerBeacon> _beacons =
      StreamController<BlePeerBeacon>.broadcast();

  @override
  Stream<BlePeerBeacon> get beacons => _beacons.stream;

  @override
  Future<void> start({required String peerId}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _beacons.close();
}

final class _MemoryConnection implements MeshConnection {
  _MemoryConnection(this.remoteAddress);

  static (_MemoryConnection, _MemoryConnection) pair() {
    final first = _MemoryConnection('desktop-anchor');
    final second = _MemoryConnection('mobile-edge');
    first._remote = second;
    second._remote = first;
    return (first, second);
  }

  @override
  final String remoteAddress;
  final StreamController<List<int>> _bytes = StreamController<List<int>>();
  late final _MemoryConnection _remote;
  bool _closed = false;

  @override
  Stream<List<int>> get bytes => _bytes.stream;

  @override
  void send(List<int> bytes) {
    if (_closed) throw StateError('Connection is closed.');
    _remote._bytes.add(List<int>.from(bytes));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_remote._closed) await _remote._bytes.close();
    await _bytes.close();
  }
}
