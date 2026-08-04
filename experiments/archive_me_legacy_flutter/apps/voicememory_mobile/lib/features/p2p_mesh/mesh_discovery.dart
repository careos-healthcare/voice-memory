import 'dart:async';

import 'mesh_models.dart';

class MeshAdvertisement {
  const MeshAdvertisement({
    required this.peerId,
    required this.displayName,
    required this.identityFingerprint,
    this.port = 0,
    this.protocolVersion = 1,
  });

  final String peerId;
  final String displayName;
  final String identityFingerprint;

  /// Use zero to let the operating system select an available port.
  final int port;
  final int protocolVersion;
}

abstract class MeshConnection {
  String get remoteAddress;
  Stream<List<int>> get bytes;
  void send(List<int> bytes);
  Future<void> close();
}

abstract class MeshDiscoveryAdapter {
  Stream<MeshPeerEvent> get peerEvents;
  Stream<MeshConnection> get incomingConnections;

  Future<int> advertise(MeshAdvertisement advertisement);
  Future<void> startDiscovery({String? excludePeerId});
  Future<MeshConnection> connect(
    MeshPeer peer, {
    Duration timeout = const Duration(seconds: 10),
  });
  Future<void> stop();
  Future<void> dispose();
}
