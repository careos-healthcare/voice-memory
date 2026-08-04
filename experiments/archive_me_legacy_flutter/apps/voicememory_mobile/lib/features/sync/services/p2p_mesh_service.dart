import 'dart:async';
import 'dart:convert';

import '../../p2p_mesh/mesh_discovery.dart';
import '../../p2p_mesh/mesh_models.dart';
import '../../p2p_mesh/nsd_tcp_mesh_adapter.dart';

typedef MeshJsonPayload = Map<String, dynamic>;

/// NSD/TCP transport facade for ArchiveMe journal synchronization.
///
/// This layer handles discovery and framed JSON transport. Sensitive production
/// payloads should still be routed through the authenticated mesh session.
class P2PMeshService {
  factory P2PMeshService({
    MeshDiscoveryAdapter? adapter,
    required String deviceId,
  }) {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Must not be empty.');
    }
    return P2PMeshService._(adapter ?? NsdTcpMeshAdapter(), normalizedDeviceId);
  }

  P2PMeshService._(this._adapter, this._deviceId);

  static const int maxPayloadBytes = 512 * 1024;

  final MeshDiscoveryAdapter _adapter;
  final String _deviceId;
  final Map<String, MeshPeer> _peers = {};
  final Map<String, _ManagedConnection> _connections = {};
  final StreamController<List<MeshPeer>> _peerSnapshots =
      StreamController<List<MeshPeer>>.broadcast();
  final StreamController<MeshJsonPayload> _receivedEntries =
      StreamController<MeshJsonPayload>.broadcast();

  StreamSubscription<MeshPeerEvent>? _peerSubscription;
  StreamSubscription<MeshConnection>? _incomingSubscription;
  bool _started = false;
  bool _disposed = false;

  Stream<List<MeshPeer>> get peers => _peerSnapshots.stream;
  Stream<MeshJsonPayload> get receivedEntries => _receivedEntries.stream;
  List<MeshPeer> get nearbyPeers => List.unmodifiable(_peers.values);
  int get connectedPeerCount => _connections.length;

  Future<void> startDiscovery() async {
    _ensureActive();
    if (_started) return;
    _started = true;
    _peerSubscription = _adapter.peerEvents.listen(
      _handlePeerEvent,
      onError: _peerSnapshots.addError,
    );
    _incomingSubscription = _adapter.incomingConnections.listen(
      (connection) => _registerConnection(
        connection,
        temporaryPeerId: 'incoming:${connection.remoteAddress}',
      ),
      onError: _receivedEntries.addError,
    );
    try {
      await _adapter.advertise(
        MeshAdvertisement(
          peerId: _deviceId,
          displayName: 'ArchiveMe',
          identityFingerprint: '',
        ),
      );
      await _adapter.startDiscovery(excludePeerId: _deviceId);
    } catch (_) {
      await stopDiscovery();
      rethrow;
    }
  }

  Future<void> connectToPeer(MeshPeer peer) async {
    _ensureActive();
    if (!_started) {
      throw StateError('Start discovery before connecting to a peer.');
    }
    if (peer.id == _deviceId || _connections.containsKey(peer.id)) return;
    final connection = await _adapter.connect(peer);
    _registerConnection(connection, temporaryPeerId: peer.id);
  }

  Future<void> broadcastEntry(MeshJsonPayload serializedEntry) async {
    _ensureActive();
    final packet = <String, dynamic>{
      'version': 1,
      'type': 'journal_entry',
      'sourceDeviceId': _deviceId,
      'entry': serializedEntry,
    };
    final encoded = _encodePacket(packet);
    final failed = <String>[];
    for (final connection in _connections.entries.toList(growable: false)) {
      try {
        connection.value.connection.send(encoded);
      } catch (_) {
        failed.add(connection.key);
      }
    }
    for (final peerId in failed) {
      await _connections.remove(peerId)?.close();
    }
  }

  Future<void> stopDiscovery() async {
    _started = false;
    await _peerSubscription?.cancel();
    await _incomingSubscription?.cancel();
    _peerSubscription = null;
    _incomingSubscription = null;
    final connections = _connections.values.toSet().toList(growable: false);
    _connections.clear();
    await Future.wait(connections.map((connection) => connection.close()));
    _peers.clear();
    if (!_peerSnapshots.isClosed) _peerSnapshots.add(const []);
    await _adapter.stop();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await stopDiscovery();
    _disposed = true;
    await _adapter.dispose();
    await _peerSnapshots.close();
    await _receivedEntries.close();
  }

  void _handlePeerEvent(MeshPeerEvent event) {
    if (event.peer.id == _deviceId) return;
    if (event.kind == MeshPeerEventKind.found) {
      _peers[event.peer.id] = event.peer;
    } else {
      _peers.remove(event.peer.id);
    }
    final snapshot = _peers.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    _peerSnapshots.add(List.unmodifiable(snapshot));
  }

  void _registerConnection(
    MeshConnection connection, {
    required String temporaryPeerId,
  }) {
    if (_disposed) {
      unawaited(connection.close());
      return;
    }
    late final _ManagedConnection managed;
    managed = _ManagedConnection(
      connection: connection,
      onPacket: (packet) => _handlePacket(managed, packet),
      onClosed: () => _removeConnection(managed),
      onError: _receivedEntries.addError,
    );
    managed.peerId = temporaryPeerId;
    final previous = _connections[temporaryPeerId];
    _connections[temporaryPeerId] = managed;
    if (previous != null && !identical(previous, managed)) {
      unawaited(previous.close());
    }
    connection.send(
      _encodePacket({
        'version': 1,
        'type': 'hello',
        'sourceDeviceId': _deviceId,
      }),
    );
    managed.listen();
  }

  void _handlePacket(_ManagedConnection managed, MeshJsonPayload packet) {
    if (packet['version'] != 1) return;
    final sourceDeviceId = packet['sourceDeviceId']?.toString().trim() ?? '';
    if (sourceDeviceId.isEmpty || sourceDeviceId == _deviceId) return;
    if (packet['type'] == 'hello') {
      final previousId = managed.peerId;
      if (_connections[previousId] == managed) {
        _connections.remove(previousId);
      }
      managed.peerId = sourceDeviceId;
      final duplicate = _connections[sourceDeviceId];
      _connections[sourceDeviceId] = managed;
      if (duplicate != null && !identical(duplicate, managed)) {
        unawaited(duplicate.close());
      }
      return;
    }
    if (packet['type'] != 'journal_entry') return;
    final entry = packet['entry'];
    if (entry is! Map) return;
    _receivedEntries.add(Map<String, dynamic>.from(entry));
  }

  List<int> _encodePacket(MeshJsonPayload packet) {
    final bytes = utf8.encode('${jsonEncode(packet)}\n');
    if (bytes.length > maxPayloadBytes) {
      throw ArgumentError.value(
        bytes.length,
        'serializedEntry',
        'Mesh payload exceeds $maxPayloadBytes bytes.',
      );
    }
    return bytes;
  }

  void _removeConnection(_ManagedConnection managed) {
    if (_connections[managed.peerId] == managed) {
      _connections.remove(managed.peerId);
    }
  }

  void _ensureActive() {
    if (_disposed) throw StateError('P2P mesh service has been disposed.');
  }
}

class _ManagedConnection {
  _ManagedConnection({
    required this.connection,
    required this.onPacket,
    required this.onClosed,
    required this.onError,
  });

  final MeshConnection connection;
  final void Function(MeshJsonPayload packet) onPacket;
  final void Function() onClosed;
  final void Function(Object error, StackTrace stackTrace) onError;
  late String peerId;
  StreamSubscription<String>? _subscription;

  void listen() {
    _subscription = connection.bytes
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (utf8.encode(line).length > P2PMeshService.maxPayloadBytes) {
              unawaited(close());
              return;
            }
            try {
              final decoded = jsonDecode(line);
              if (decoded is Map) {
                onPacket(Map<String, dynamic>.from(decoded));
              }
            } on FormatException {
              // Ignore malformed peer frames without terminating healthy links.
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            onError(error, stackTrace);
            onClosed();
          },
          onDone: onClosed,
          cancelOnError: false,
        );
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    onClosed();
    await connection.close();
  }
}
