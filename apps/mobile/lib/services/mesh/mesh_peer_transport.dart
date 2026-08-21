import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archiveme_mobile/services/mesh/mesh_compute_protocol.dart';
import 'package:archiveme_mobile/services/mesh/mesh_encrypted_transport.dart';
import 'package:archiveme_mobile/services/mesh/mesh_socket_framing.dart';
import 'package:archiveme_mobile/services/mesh/mesh_types.dart';
import 'package:uuid/uuid.dart';

typedef MeshSocketConnector = Future<Socket> Function(String host, int port);

/// Opens encrypted mesh sessions and routes inference frames to desktop peers.
class MeshPeerTransport {
  MeshPeerTransport({
    MeshSocketConnector? connect,
    Random? random,
    String Function()? requestIdFactory,
  })  : _connect = connect ?? ((host, port) => Socket.connect(host, port)),
        _random = random ?? Random.secure(),
        _requestIdFactory = requestIdFactory ?? const Uuid().v4;

  final MeshSocketConnector _connect;
  final Random _random;
  final String Function() _requestIdFactory;

  String _randomNonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Performs capability handshake and returns a session key + peer metadata.
  Future<MeshPeerSession?> handshake({
    required MeshPeerCapabilities peer,
    required String clientId,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!peer.isDesktopLlamaPeer) return null;

    Socket? socket;
    try {
      socket = await _connect(peer.host, peer.port).timeout(timeout);

      final clientNonce = _randomNonce();
      final request = MeshHandshakeRequest(
        clientId: clientId,
        nonce: clientNonce,
        capabilities: MeshPeerCapabilities(
          peerId: clientId,
          role: MeshPeerRole.mobile,
          host: '127.0.0.1',
          port: 0,
          llamaCppSupported: true,
        ),
      );

      socket.write('${jsonEncode(request.toJson())}\n');
      final responseLine = await readSocketLine(socket, timeout: timeout);

      final responseJson =
          jsonDecode(responseLine) as Map<String, dynamic>;
      final response = MeshHandshakeResponse.fromJson(responseJson);
      if (!response.accepted || !response.capabilities.isDesktopLlamaPeer) {
        return null;
      }

      final sessionKeyBytes = await MeshEncryptedTransport.deriveSessionKey(
        clientId: clientId,
        clientNonce: clientNonce,
        peerId: response.peerId,
        peerNonce: response.nonce,
      );

      return MeshPeerSession(
        capabilities: response.capabilities,
        sessionKeyBytes: sessionKeyBytes,
        handshakeNonce: response.nonce,
      );
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_, stackTrace) {
      return null;
    } finally {
      await socket?.close();
    }
  }

  /// Sends an encrypted inference request over a fresh socket connection.
  Future<MeshInferenceWireResponse?> infer({
    required MeshPeerSession session,
    required LlamaInferenceRequest request,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final peer = session.capabilities;
    Socket? socket;
    try {
      socket = await _connect(peer.host, peer.port).timeout(timeout);
      final transport = MeshEncryptedTransport(
        sessionKeyBytes: session.sessionKeyBytes,
      );

      final requestId = _requestIdFactory();
      final wireRequest = MeshInferenceWireRequest(
        requestId: requestId,
        request: request,
      );
      final encrypted = await transport.encryptJson(wireRequest.toJson());
      socket.write('$encrypted\n');

      final responseLine = await readSocketLine(socket, timeout: timeout);

      final decrypted = await transport.decryptJson(responseLine.trim());
      if (decrypted == null) return null;
      return MeshInferenceWireResponse.fromJson(decrypted);
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_, stackTrace) {
      return null;
    } finally {
      await socket?.close();
    }
  }
}