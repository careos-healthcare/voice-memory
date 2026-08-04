import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nsd/nsd.dart' as nsd;

import 'mesh_discovery.dart';
import 'mesh_models.dart';

class NsdTcpMeshAdapter implements MeshDiscoveryAdapter {
  NsdTcpMeshAdapter({InternetAddress? bindAddress})
    : _bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  static const serviceType = '_archiveme-mesh._tcp';

  final InternetAddress _bindAddress;
  final StreamController<MeshPeerEvent> _peerEvents =
      StreamController.broadcast();
  final StreamController<MeshConnection> _incomingConnections =
      StreamController.broadcast();
  final Map<String, MeshPeer> _knownPeers = {};
  final Set<_TcpMeshConnection> _connections = {};

  ServerSocket? _server;
  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  nsd.ServiceListener? _serviceListener;
  String? _excludedPeerId;
  bool _disposed = false;

  @override
  Stream<MeshPeerEvent> get peerEvents => _peerEvents.stream;

  @override
  Stream<MeshConnection> get incomingConnections => _incomingConnections.stream;

  @override
  Future<int> advertise(MeshAdvertisement advertisement) async {
    _ensureActive();
    if (_registration != null || _server != null) {
      throw StateError('Mesh advertising is already active.');
    }
    if (advertisement.peerId.isEmpty ||
        advertisement.port < 0 ||
        advertisement.port > 65535) {
      throw ArgumentError('Invalid mesh advertisement.');
    }
    final server = await ServerSocket.bind(
      _bindAddress,
      advertisement.port,
      shared: false,
    );
    _server = server;
    server.listen(
      _accept,
      onError: _incomingConnections.addError,
      onDone: () => _server = null,
    );
    try {
      _registration = await nsd.register(
        nsd.Service(
          // Discovery exposes only a rotating opaque identifier. Human labels
          // and identity fingerprints are exchanged after ECDH authentication.
          name: _safeServiceName(advertisement.peerId),
          type: serviceType,
          port: server.port,
          txt: {
            'v': _txt('${advertisement.protocolVersion}'),
            'id': _txt(advertisement.peerId),
          },
        ),
      );
      return server.port;
    } catch (_) {
      _server = null;
      await server.close();
      rethrow;
    }
  }

  @override
  Future<void> startDiscovery({String? excludePeerId}) async {
    _ensureActive();
    if (_discovery != null) return;
    _excludedPeerId = excludePeerId;
    final discovery = await nsd.startDiscovery(
      serviceType,
      autoResolve: true,
      ipLookupType: nsd.IpLookupType.any,
    );
    _discovery = discovery;
    _serviceListener = _onService;
    discovery.addServiceListener(_onService);
    for (final service in discovery.services) {
      await _onService(service, nsd.ServiceStatus.found);
    }
  }

  @override
  Future<MeshConnection> connect(
    MeshPeer peer, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _ensureActive();
    final socket = await Socket.connect(peer.host, peer.port, timeout: timeout);
    return _track(socket);
  }

  @override
  Future<void> stop() async {
    final discovery = _discovery;
    final listener = _serviceListener;
    _discovery = null;
    _serviceListener = null;
    if (discovery != null) {
      if (listener != null) discovery.removeServiceListener(listener);
      await nsd.stopDiscovery(discovery);
    }
    final registration = _registration;
    _registration = null;
    if (registration != null) await nsd.unregister(registration);
    final server = _server;
    _server = null;
    await server?.close();
    final closing = _connections
        .map((connection) => connection.close())
        .toList();
    await Future.wait(closing);
    _knownPeers.clear();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    await _peerEvents.close();
    await _incomingConnections.close();
  }

  Future<void> _onService(nsd.Service service, nsd.ServiceStatus status) async {
    if (_disposed) return;
    final key = '${service.type}|${service.name}';
    if (status == nsd.ServiceStatus.lost) {
      final peer = _knownPeers.remove(key);
      if (peer != null) {
        _peerEvents.add(
          MeshPeerEvent(kind: MeshPeerEventKind.lost, peer: peer),
        );
      }
      return;
    }
    final peer = _peerFromService(service);
    if (peer == null || peer.id == _excludedPeerId) return;
    _knownPeers[key] = peer;
    _peerEvents.add(MeshPeerEvent(kind: MeshPeerEventKind.found, peer: peer));
  }

  MeshPeer? _peerFromService(nsd.Service service) {
    final txt = service.txt;
    final port = service.port;
    final id = _readTxt(txt, 'id');
    final version = int.tryParse(_readTxt(txt, 'v') ?? '');
    final host =
        service.addresses
            ?.where((address) => !address.isLoopback)
            .firstOrNull
            ?.address ??
        service.addresses?.firstOrNull?.address ??
        service.host;
    if (id == null ||
        id.isEmpty ||
        version != 1 ||
        host == null ||
        host.isEmpty ||
        port == null ||
        port < 1 ||
        port > 65535) {
      return null;
    }
    return MeshPeer(
      id: id,
      name: 'Nearby ArchiveMe device',
      host: host,
      port: port,
      identityFingerprint: '',
      protocolVersion: version!,
    );
  }

  void _accept(Socket socket) {
    if (_disposed) {
      socket.destroy();
      return;
    }
    _incomingConnections.add(_track(socket));
  }

  _TcpMeshConnection _track(Socket socket) {
    late final _TcpMeshConnection connection;
    connection = _TcpMeshConnection(
      socket,
      onClosed: () => _connections.remove(connection),
    );
    _connections.add(connection);
    return connection;
  }

  void _ensureActive() {
    if (_disposed) throw StateError('Mesh adapter has been disposed.');
  }

  Uint8List _txt(String value) => Uint8List.fromList(utf8.encode(value));

  String? _readTxt(Map<String, Uint8List?>? txt, String key) {
    final value = txt?[key];
    if (value == null) return null;
    try {
      return utf8.decode(value);
    } on FormatException {
      return null;
    }
  }

  String _safeServiceName(String value) {
    final encoded = utf8.encode(value);
    if (encoded.length <= 63) return value;
    return utf8.decode(encoded.sublist(0, 63), allowMalformed: true);
  }
}

class _TcpMeshConnection implements MeshConnection {
  _TcpMeshConnection(this._socket, {required this._onClosed});

  final Socket _socket;
  final void Function() _onClosed;
  bool _closed = false;

  @override
  String get remoteAddress =>
      '${_socket.remoteAddress.address}:${_socket.remotePort}';

  @override
  Stream<List<int>> get bytes => _socket;

  @override
  void send(List<int> bytes) {
    if (_closed) throw StateError('Mesh connection is closed.');
    _socket.add(bytes);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _onClosed();
    await _socket.close();
  }
}
