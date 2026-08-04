import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../services/local_storage/browser_bridge_vault.dart';
import 'browser_bridge_models.dart';
import 'clipper_ingestion_engine.dart';

final class VaultBridgeAuthenticationException implements Exception {
  const VaultBridgeAuthenticationException(this.message);
  final String message;
  @override
  String toString() => 'VaultBridgeAuthenticationException: $message';
}

/// Loopback-only WebSocket companion with authenticated, AES-GCM clip frames.
///
/// A [tlsContext] upgrades transport to WSS. Without it, payload confidentiality
/// and integrity still use per-extension AES-256-GCM keys after QR pairing.
final class VaultBridgeServer extends ChangeNotifier {
  VaultBridgeServer({
    required this.vault,
    required this.ingestion,
    this.tlsContext,
    this.tlsCertificateFingerprint,
    this.preferredPort = 39271,
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final BrowserBridgeVault vault;
  final ClipperIngestionEngine ingestion;
  final SecurityContext? tlsContext;
  final String? tlsCertificateFingerprint;
  final int preferredPort;
  final DateTime Function() _clock;
  final Random _random;
  final Ed25519 _signatures = Ed25519();
  final AesGcm _cipher = AesGcm.with256bits();
  final Set<String> _usedAuthenticationNonces = {};
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _requests;
  BrowserPairingInvitation? _invitation;
  bool _disposed = false;

  int? get port => _server?.port;
  bool get isRunning => _server != null;
  BrowserPairingInvitation? get activeInvitation =>
      _invitation?.isValidAt(_clock()) == true ? _invitation : null;

  Future<void> start() async {
    if (_disposed) throw StateError('Vault bridge server is disposed.');
    if (_server != null) return;
    final context = tlsContext;
    final server = context == null
        ? await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            preferredPort,
            shared: false,
          )
        : await HttpServer.bindSecure(
            InternetAddress.loopbackIPv4,
            preferredPort,
            context,
            shared: false,
          );
    server.autoCompress = false;
    _server = server;
    _requests = server.listen(_handleRequest);
    notifyListeners();
  }

  Future<void> stop() async {
    if (_disposed || _server == null) return;
    _invitation = null;
    final requests = _requests;
    _requests = null;
    final server = _server;
    _server = null;
    await requests?.cancel();
    await server?.close(force: true);
    notifyListeners();
  }

  Future<BrowserPairingInvitation> createPairingInvitation() async {
    await start();
    final invitation = BrowserPairingInvitation(
      endpoint: Uri(
        scheme: tlsContext == null ? 'ws' : 'wss',
        host: '127.0.0.1',
        port: _server!.port,
        path: '/bridge',
      ),
      token: base64UrlEncode(_randomBytes(32)),
      pin: (_random.nextInt(900000) + 100000).toString(),
      expiresAt: _clock().toUtc().add(const Duration(seconds: 60)),
      tlsCertificateFingerprint: tlsCertificateFingerprint,
    );
    _invitation = invitation;
    notifyListeners();
    return invitation;
  }

  static Future<VaultBridgeServer> secureOrApplicationLayer({
    required BrowserBridgeVault vault,
    required ClipperIngestionEngine ingestion,
  }) async {
    try {
      final identity = await EphemeralLocalhostTlsIdentity.generate();
      return VaultBridgeServer(
        vault: vault,
        ingestion: ingestion,
        tlsContext: identity.context,
        tlsCertificateFingerprint: identity.fingerprint,
        preferredPort: 39271,
      );
    } on Object {
      // Sandboxed mobile runtimes cannot spawn a certificate generator.
      // Loopback binding plus signed handshakes and AES-GCM frames remain
      // mandatory, so plaintext user payloads never cross the socket.
      return VaultBridgeServer(vault: vault, ingestion: ingestion);
    }
  }

  Future<List<TrustedBrowserExtension>> extensions() => vault.extensions();

  Future<void> revoke(String id) async {
    await vault.revoke(id);
    notifyListeners();
  }

  Future<Map<String, Object>> pair(Map<String, dynamic> frame) async {
    final invitation = activeInvitation;
    if (invitation == null ||
        !_constantTime(frame['token'], invitation.token) ||
        !_constantTime(frame['pin'], invitation.pin)) {
      throw const VaultBridgeAuthenticationException(
        'Pairing credentials are invalid or expired.',
      );
    }
    final publicKey = _decodeBounded(frame['publicKey'], expected: 32);
    final name = (frame['name'] as String? ?? 'Browser extension').trim();
    if (name.isEmpty || name.length > 120) {
      throw const VaultBridgeAuthenticationException(
        'Extension identity is invalid.',
      );
    }
    final extensionId = hashes.sha256.convert(publicKey).toString();
    final sessionKey = _randomBytes(32);
    final now = _clock().toUtc();
    await vault.trust(
      TrustedBrowserExtension(
        id: extensionId,
        name: name,
        publicKey: publicKey,
        sessionKey: sessionKey,
        pairedAt: now,
        lastSeenAt: now,
      ),
    );
    _invitation = null;
    notifyListeners();
    return {
      'type': 'paired',
      'extensionId': extensionId,
      'sessionKey': base64Encode(sessionKey),
      'serverTime': now.toIso8601String(),
    };
  }

  Future<TrustedBrowserExtension> authenticate(
    Map<String, dynamic> frame,
  ) async {
    final id = frame['extensionId'] as String? ?? '';
    final timestamp = DateTime.tryParse(frame['timestamp'] as String? ?? '');
    final nonce = frame['nonce'] as String? ?? '';
    final signature = _decodeBounded(frame['signature'], expected: 64);
    final extension = await vault.extension(id);
    final now = _clock().toUtc();
    if (extension == null ||
        timestamp == null ||
        now.difference(timestamp.toUtc()).abs() > const Duration(seconds: 60) ||
        nonce.length < 16 ||
        nonce.length > 256 ||
        !_usedAuthenticationNonces.add('$id:$nonce')) {
      throw const VaultBridgeAuthenticationException(
        'Extension authentication was rejected.',
      );
    }
    final message = utf8.encode(
      '$id|${timestamp.toUtc().toIso8601String()}|$nonce',
    );
    final valid = await _signatures.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(
          extension.publicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valid) {
      _usedAuthenticationNonces.remove('$id:$nonce');
      throw const VaultBridgeAuthenticationException(
        'Extension signature is invalid.',
      );
    }
    final updated = extension.copyWith(lastSeenAt: now);
    await vault.trust(updated);
    return updated;
  }

  Future<WebClipPayload> decryptPayload(
    TrustedBrowserExtension extension,
    Map<String, dynamic> frame,
  ) async {
    try {
      final clear = await _cipher.decrypt(
        SecretBox(
          base64Decode(frame['ciphertext'] as String),
          nonce: _decodeBounded(frame['nonce'], expected: 12),
          mac: Mac(_decodeBounded(frame['mac'], expected: 16)),
        ),
        secretKey: SecretKey(extension.sessionKey),
        aad: utf8.encode('browser-clip-v1|${extension.id}'),
      );
      try {
        return WebClipPayload.fromJson(
          Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map),
        );
      } finally {
        clear.fillRange(0, clear.length, 0);
      }
    } on Object {
      throw const VaultBridgeAuthenticationException(
        'Encrypted clip payload could not be authenticated.',
      );
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!request.connectionInfo!.remoteAddress.isLoopback ||
        request.uri.path != '/bridge' ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    WebSocket? socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
      final iterator = StreamIterator<Object?>(socket);
      if (!await iterator.moveNext().timeout(const Duration(seconds: 5))) {
        throw const VaultBridgeAuthenticationException(
          'The extension sent no handshake.',
        );
      }
      final frame = _frame(iterator.current);
      if (frame['type'] == 'pair') {
        socket.add(jsonEncode(await pair(frame)));
        await socket.close(WebSocketStatus.normalClosure);
        return;
      }
      if (frame['type'] != 'hello') {
        throw const VaultBridgeAuthenticationException(
          'A signed hello frame is required.',
        );
      }
      final extension = await authenticate(frame);
      socket.add(jsonEncode({'type': 'ready'}));
      while (await iterator.moveNext()) {
        final clipFrame = _frame(iterator.current);
        if (clipFrame['type'] != 'clip') continue;
        final payload = await decryptPayload(extension, clipFrame);
        final result = await ingestion.ingest(
          extensionId: extension.id,
          payload: payload,
        );
        socket.add(
          jsonEncode({
            'type': 'stored',
            'clipId': result.clipId,
            'chunkCount': result.chunkCount,
            'clusterIds': result.clusterIds,
          }),
        );
      }
    } on Object catch (error) {
      socket?.add(jsonEncode({'type': 'error', 'message': '$error'}));
      await socket?.close(WebSocketStatus.policyViolation);
    }
  }

  static Map<String, dynamic> _frame(Object? raw) {
    if (raw is! String || raw.length > 16 * 1024 * 1024) {
      throw const FormatException('Invalid bridge frame.');
    }
    final value = jsonDecode(raw);
    if (value is! Map) throw const FormatException('Invalid bridge frame.');
    return Map<String, dynamic>.from(value);
  }

  static Uint8List _decodeBounded(Object? value, {required int expected}) {
    if (value is! String) {
      throw const VaultBridgeAuthenticationException(
        'Authentication bytes are missing.',
      );
    }
    final decoded = base64Decode(value);
    if (decoded.length != expected) {
      throw const VaultBridgeAuthenticationException(
        'Authentication bytes have an invalid length.',
      );
    }
    return Uint8List.fromList(decoded);
  }

  static bool _constantTime(Object? left, String right) {
    if (left is! String) return false;
    final a = utf8.encode(left);
    final b = utf8.encode(right);
    var difference = a.length ^ b.length;
    for (var index = 0; index < max(a.length, b.length); index++) {
      difference |=
          (index < a.length ? a[index] : 0) ^ (index < b.length ? b[index] : 0);
    }
    return difference == 0;
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList(
    List.generate(length, (_) => _random.nextInt(256), growable: false),
  );

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _invitation = null;
    final requests = _requests;
    _requests = null;
    final server = _server;
    _server = null;
    await requests?.cancel();
    await server?.close(force: true);
    super.dispose();
  }
}

final class EphemeralLocalhostTlsIdentity {
  const EphemeralLocalhostTlsIdentity({
    required this.context,
    required this.fingerprint,
  });

  final SecurityContext context;
  final String fingerprint;

  static Future<EphemeralLocalhostTlsIdentity> generate() async {
    final directory = await Directory.systemTemp.createTemp(
      'archiveme_bridge_tls_',
    );
    final certificate = File('${directory.path}/localhost.crt');
    final privateKey = File('${directory.path}/localhost.key');
    try {
      final result = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-sha256',
        '-nodes',
        '-keyout',
        privateKey.path,
        '-out',
        certificate.path,
        '-days',
        '1',
        '-subj',
        '/CN=localhost',
        '-addext',
        'subjectAltName=DNS:localhost,IP:127.0.0.1',
      ]);
      if (result.exitCode != 0 ||
          !certificate.existsSync() ||
          !privateKey.existsSync()) {
        throw StateError('Could not generate an ephemeral localhost identity.');
      }
      final pem = certificate.readAsStringSync();
      final der = base64Decode(
        pem
            .replaceAll('-----BEGIN CERTIFICATE-----', '')
            .replaceAll('-----END CERTIFICATE-----', '')
            .replaceAll(RegExp(r'\s+'), ''),
      );
      final context = SecurityContext(withTrustedRoots: false)
        ..useCertificateChain(certificate.path)
        ..usePrivateKey(privateKey.path);
      return EphemeralLocalhostTlsIdentity(
        context: context,
        fingerprint: hashes.sha256.convert(der).toString(),
      );
    } finally {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
  }
}
