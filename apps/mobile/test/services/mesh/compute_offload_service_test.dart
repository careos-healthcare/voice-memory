import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/services/mesh/mesh.dart';
import 'package:archiveme_mobile/services/mesh/mesh_socket_framing.dart';
import 'package:flutter_test/flutter_test.dart';

MeshPeerCapabilities _desktopPeer({
  required String host,
  required int port,
  bool gpu = true,
  String peerId = 'desktop-1',
}) {
  return MeshPeerCapabilities(
    peerId: peerId,
    role: MeshPeerRole.desktop,
    host: host,
    port: port,
    llamaCppSupported: true,
    llamaCppVersion: 'b4500',
    resources: gpu
        ? {MeshComputeResource.gpu, MeshComputeResource.cpu}
        : {MeshComputeResource.cpu},
    maxContextTokens: 8192,
  );
}

/// In-process desktop mesh node for unit tests.
class FakeMeshDesktopServer {
  FakeMeshDesktopServer({
    this.rejectHandshake = false,
    this.inferDelay = Duration.zero,
    this.inferHang = false,
  });

  final bool rejectHandshake;
  final Duration inferDelay;
  final bool inferHang;

  late ServerSocket _server;
  final _sessionKeys = <String, List<int>>{};

  String get host => InternetAddress.loopbackIPv4.address;
  int get port => _server.port;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handleConnection);
  }

  Future<void> close() => _server.close();

  MeshPeerCapabilities get capabilities =>
      _desktopPeer(host: host, port: port);

  Future<void> _handleConnection(Socket socket) async {
    try {
      final firstLine = await readSocketLine(
        socket,
        timeout: const Duration(seconds: 2),
      );
      if (firstLine.trim().isEmpty) {
        await socket.close();
        return;
      }

      Map<String, dynamic>? payload;
      try {
        payload = jsonDecode(firstLine) as Map<String, dynamic>;
      } catch (_) {
        payload = null;
      }

      if (payload != null &&
          payload['type'] == MeshComputeMessageTypes.handshakeRequest) {
        final request = MeshHandshakeRequest.fromJson(payload);
        final peerNonce = 'peer-${request.nonce}';
        final response = MeshHandshakeResponse(
          peerId: 'desktop-1',
          nonce: peerNonce,
          accepted: !rejectHandshake,
          rejectionReason: rejectHandshake ? 'busy' : null,
          capabilities: capabilities,
        );

        if (!rejectHandshake) {
          final sessionKey = await MeshEncryptedTransport.deriveSessionKey(
            clientId: request.clientId,
            clientNonce: request.nonce,
            peerId: response.peerId,
            peerNonce: peerNonce,
          );
          _sessionKeys[request.clientId] = sessionKey;
        }

        socket.write('${jsonEncode(response.toJson())}\n');
        await socket.close();
        return;
      }

      for (final sessionKey in _sessionKeys.values) {
        final transport = MeshEncryptedTransport(sessionKeyBytes: sessionKey);
        final decrypted = await transport.decryptJson(firstLine.trim());
        if (decrypted == null) continue;

        if (inferHang) {
          await Future<void>.delayed(const Duration(seconds: 5));
          await socket.close();
          return;
        }

        if (inferDelay > Duration.zero) {
          await Future<void>.delayed(inferDelay);
        }

        final wireRequest = MeshInferenceWireRequest.fromJson(decrypted);
        final wireResponse = MeshInferenceWireResponse(
          requestId: wireRequest.requestId,
          text: '[mesh-llama] ${wireRequest.request.prompt}',
          tokensUsed: 42,
        );
        final encrypted = await transport.encryptJson(wireResponse.toJson());
        socket.write('$encrypted\n');
        await socket.close();
        return;
      }

      await socket.close();
    } catch (_) {
      await socket.close();
    }
  }
}

MeshPermissionGate _permittedGate() {
  return MeshPermissionGate(
    meshFeatureEnabled: true,
    localNetworkPermission: FakeLocalNetworkPermissionGateway(granted: true),
  );
}

void main() {
  group('MeshEncryptedTransport', () {
    test('round-trips JSON payloads', () async {
      final key = await MeshEncryptedTransport.deriveSessionKey(
        clientId: 'mobile',
        clientNonce: 'a',
        peerId: 'desktop',
        peerNonce: 'b',
      );
      final transport = MeshEncryptedTransport(sessionKeyBytes: key);
      final frame = await transport.encryptJson({'hello': 'mesh'});
      final decoded = await transport.decryptJson(frame);
      expect(decoded, {'hello': 'mesh'});
    });
  });

  group('selectBestDesktopPeer', () {
    test('prefers GPU-capable desktop peers', () {
      final cpuOnly = _desktopPeer(host: '10.0.0.2', port: 1, gpu: false);
      final gpu = _desktopPeer(host: '10.0.0.3', port: 2, gpu: true);
      final selected = selectBestDesktopPeer([cpuOnly, gpu]);
      expect(selected?.host, '10.0.0.3');
    });
  });

  group('MeshPermissionGate', () {
    test('denies when feature disabled', () async {
      final gate = MeshPermissionGate(meshFeatureEnabled: false);
      final decision = await gate.evaluate();
      expect(decision.permitted, isFalse);
      expect(decision.reason, MeshPermissionBlockReason.featureDisabled);
    });

    test('denies when local network permission revoked', () async {
      final gate = MeshPermissionGate(
        meshFeatureEnabled: true,
        localNetworkPermission: FakeLocalNetworkPermissionGateway(granted: false),
      );
      final decision = await gate.evaluate();
      expect(decision.permitted, isFalse);
      expect(decision.reason, MeshPermissionBlockReason.localNetworkPermissionDenied);
    });
  });

  group('ComputeOffloadService', () {
    FakeMeshDesktopServer? fakeDesktop;

    tearDown(() async {
      await fakeDesktop?.close();
      fakeDesktop = null;
    });

    test('falls back locally when permission revoked', () async {
      final service = ComputeOffloadService(
        permissionGate: MeshPermissionGate(
          meshFeatureEnabled: true,
          localNetworkPermission: FakeLocalNetworkPermissionGateway(granted: false),
        ),
      );

      final response = await service.infer(
        const LlamaInferenceRequest(prompt: 'summarize my week'),
      );

      expect(response.route, LlamaInferenceRoute.onDevice);
      expect(response.fallbackReason, MeshOffloadFallbackReason.localNetworkPermissionDenied);
      expect(response.text, startsWith('[local-llama:'));
    });

    test('falls back locally when no capable peer responds', () async {
      final service = ComputeOffloadService(
        permissionGate: _permittedGate(),
        discovery: FakeMeshDiscoveryService(peers: const []),
      );

      final response = await service.infer(
        const LlamaInferenceRequest(prompt: 'what changed?'),
      );

      expect(response.route, LlamaInferenceRoute.onDevice);
      expect(response.fallbackReason, MeshOffloadFallbackReason.noCapablePeer);
    });

    test('falls back locally on handshake timeout', () async {
      final service = ComputeOffloadService(
        permissionGate: _permittedGate(),
        discovery: FakeMeshDiscoveryService(
          peers: [
            MeshPeerCapabilities(
              peerId: 'ghost',
              role: MeshPeerRole.desktop,
              host: '127.0.0.1',
              port: 1,
              llamaCppSupported: true,
              resources: {MeshComputeResource.gpu},
            ),
          ],
        ),
        transport: MeshPeerTransport(
          connect: (_, _) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            throw TimeoutException('connect');
          },
        ),
        handshakeTimeout: const Duration(milliseconds: 50),
      );

      final response = await service.infer(
        const LlamaInferenceRequest(prompt: 'timeout handshake'),
      );

      expect(response.route, LlamaInferenceRoute.onDevice);
      expect(response.fallbackReason, MeshOffloadFallbackReason.handshakeTimeout);
    });

    test('routes inference to mesh peer over encrypted socket', () async {
      fakeDesktop = FakeMeshDesktopServer();
      await fakeDesktop!.start();

      final peer = fakeDesktop!.capabilities;
      final service = ComputeOffloadService(
        permissionGate: _permittedGate(),
        discovery: FakeMeshDiscoveryService(peers: [peer]),
        clientId: 'archiveme-mobile',
      );

      final response = await service.infer(
        const LlamaInferenceRequest(prompt: 'mesh offload works'),
      );

      expect(response.route, LlamaInferenceRoute.meshPeer);
      expect(response.peerId, 'desktop-1');
      expect(response.text, '[mesh-llama] mesh offload works');
      expect(response.fallbackReason, isNull);
    });

    test('falls back locally when inference times out', () async {
      fakeDesktop = FakeMeshDesktopServer(inferHang: true);
      await fakeDesktop!.start();

      final peer = fakeDesktop!.capabilities;
      final service = ComputeOffloadService(
        permissionGate: _permittedGate(),
        discovery: FakeMeshDiscoveryService(peers: [peer]),
        inferenceTimeout: const Duration(milliseconds: 100),
        handshakeTimeout: const Duration(seconds: 2),
      );

      final response = await service.infer(
        const LlamaInferenceRequest(prompt: 'slow peer'),
      );

      expect(response.route, LlamaInferenceRoute.onDevice);
      expect(response.fallbackReason, MeshOffloadFallbackReason.inferenceTimeout);
    });
  });

  group('MeshLlamaRouter', () {
    test('delegates to compute offload service', () async {
      final router = MeshLlamaRouter(
        offloadService: ComputeOffloadService(
          permissionGate: MeshPermissionGate(meshFeatureEnabled: false),
        ),
      );

      final response = await router.complete(
        const LlamaInferenceRequest(prompt: 'router path'),
      );

      expect(response.route, LlamaInferenceRoute.onDevice);
      expect(response.fallbackReason, MeshOffloadFallbackReason.featureDisabled);
    });
  });

  group('LocalLlamaInference', () {
    test('does not break on-device inference contract', () async {
      const local = LocalLlamaInference();
      final response = await local.complete(
        const LlamaInferenceRequest(prompt: 'on device only'),
      );
      expect(response.route, LlamaInferenceRoute.onDevice);
      expect(response.text, contains('on device only'));
      expect(response.fallbackReason, isNull);
    });
  });
}
