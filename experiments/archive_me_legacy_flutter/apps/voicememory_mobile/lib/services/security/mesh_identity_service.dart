import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../features/p2p_mesh/mesh_models.dart';
import 'sync_identity_service.dart';

class MeshIdentity {
  MeshIdentity({
    required this.deviceId,
    required List<int> publicKey,
    required this.fingerprint,
  }) : publicKey = Uint8List.fromList(publicKey);

  final String deviceId;
  final Uint8List publicKey;
  final String fingerprint;
}

class MeshHandshakeEphemeral {
  MeshHandshakeEphemeral._({required this.party, required this._keyPair});

  final MeshHandshakeParty party;
  final SimpleKeyPair _keyPair;

  void destroy() => _keyPair.destroy();
}

class MeshIdentityService {
  MeshIdentityService({
    SyncIdentityStore? store,
    this.deviceIdProvider,
    Random? random,
    Ed25519? signatures,
    X25519? keyExchange,
  }) : _store = store ?? PlatformSyncIdentityStore(),
       _random = random ?? Random.secure(),
       _signatures = signatures ?? Ed25519(),
       _keyExchange = keyExchange ?? X25519();

  static const _seedKey = 'mesh_ed25519_seed_v1';
  static const _deviceIdKey = 'mesh_device_id_v1';
  static final _hkdfSalt = utf8.encode('ArchiveMe.Mesh.Session.v1');
  static final _hkdfInfo = utf8.encode(
    'x25519+ed25519/aes-256-gcm/initiator-responder',
  );

  final SyncIdentityStore _store;
  final Future<String> Function()? deviceIdProvider;
  final Random _random;
  final Ed25519 _signatures;
  final X25519 _keyExchange;
  Future<_StoredIdentity>? _identityFuture;

  Future<MeshIdentity> identity() async {
    final stored = await _storedIdentity();
    return MeshIdentity(
      deviceId: stored.deviceId,
      publicKey: stored.publicKey.bytes,
      fingerprint: await _fingerprint(stored.publicKey.bytes),
    );
  }

  Future<void> destroyIdentityForPrivacyWipe() async {
    _identityFuture = null;
    await _store.delete(_seedKey);
    await _store.delete(_deviceIdKey);
  }

  Future<MeshHandshakeEphemeral> createHandshakeParty({
    List<int>? nonce,
  }) async {
    final identity = await _storedIdentity();
    final ephemeral = await _keyExchange.newKeyPair();
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final resolvedNonce = nonce == null
        ? _randomBytes(32)
        : Uint8List.fromList(nonce);
    if (resolvedNonce.length != 32) {
      ephemeral.destroy();
      throw ArgumentError.value(nonce?.length, 'nonce', 'Expected 32 bytes.');
    }
    return MeshHandshakeEphemeral._(
      party: MeshHandshakeParty(
        deviceId: identity.deviceId,
        identityPublicKey: identity.publicKey.bytes,
        ephemeralPublicKey: ephemeralPublic.bytes,
        nonce: resolvedNonce,
      ),
      keyPair: ephemeral,
    );
  }

  Future<String> fingerprintForPublicKey(List<int> publicKey) {
    if (publicKey.length != 32) {
      throw ArgumentError.value(
        publicKey.length,
        'publicKey',
        'Expected 32 bytes.',
      );
    }
    return _fingerprint(publicKey);
  }

  Future<Uint8List> signDetached(List<int> message) async {
    final identity = await _storedIdentity();
    final signature = await _signatures.sign(
      message,
      keyPair: identity.keyPair,
    );
    return Uint8List.fromList(signature.bytes);
  }

  Future<MeshHandshakeTranscript> signTranscript(
    MeshHandshakeTranscript transcript, {
    required MeshHandshakeRole role,
  }) async {
    final identity = await _storedIdentity();
    final localParty = role == MeshHandshakeRole.initiator
        ? transcript.initiator
        : transcript.responder;
    if (!_constantTimeEquals(
      localParty.identityPublicKey,
      identity.publicKey.bytes,
    )) {
      throw StateError('Transcript does not contain the local mesh identity.');
    }
    final signature = await _signatures.sign(
      transcript.signingBytes,
      keyPair: identity.keyPair,
    );
    return role == MeshHandshakeRole.initiator
        ? transcript.copyWith(initiatorSignature: signature.bytes)
        : transcript.copyWith(responderSignature: signature.bytes);
  }

  Future<bool> verifyTranscript(MeshHandshakeTranscript transcript) async {
    final initiatorSignature = transcript.initiatorSignature;
    final responderSignature = transcript.responderSignature;
    if (initiatorSignature == null || responderSignature == null) return false;
    final bytes = transcript.signingBytes;
    final initiatorValid = await _signatures.verify(
      bytes,
      signature: Signature(
        initiatorSignature,
        publicKey: SimplePublicKey(
          transcript.initiator.identityPublicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!initiatorValid) return false;
    return _signatures.verify(
      bytes,
      signature: Signature(
        responderSignature,
        publicKey: SimplePublicKey(
          transcript.responder.identityPublicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
  }

  Future<MeshSessionKeys> establishSession({
    required MeshHandshakeTranscript transcript,
    required MeshHandshakeRole role,
    required MeshHandshakeEphemeral localEphemeral,
  }) async {
    if (!await verifyTranscript(transcript)) {
      throw StateError('Mesh handshake transcript signatures are invalid.');
    }
    final localParty = role == MeshHandshakeRole.initiator
        ? transcript.initiator
        : transcript.responder;
    final remoteParty = role == MeshHandshakeRole.initiator
        ? transcript.responder
        : transcript.initiator;
    if (!_sameParty(localParty, localEphemeral.party)) {
      throw StateError('Ephemeral key does not belong to this transcript.');
    }
    final shared = await _keyExchange.sharedSecretKey(
      keyPair: localEphemeral._keyPair,
      remotePublicKey: SimplePublicKey(
        remoteParty.ephemeralPublicKey,
        type: KeyPairType.x25519,
      ),
    );
    final transcriptHash = await Sha256().hash(transcript.signingBytes);
    final derived = await Hkdf(hmac: Hmac.sha256(), outputLength: 76).deriveKey(
      secretKey: shared,
      nonce: [..._hkdfSalt, ...transcriptHash.bytes],
      info: _hkdfInfo,
    );
    final bytes = Uint8List.fromList(await derived.extractBytes());
    try {
      final initiatorToResponder = bytes.sublist(0, 32);
      final responderToInitiator = bytes.sublist(32, 64);
      final initiatorNonce = bytes.sublist(64, 68);
      final responderNonce = bytes.sublist(68, 72);
      final sasNumber =
          ((bytes[72] << 24) |
              (bytes[73] << 16) |
              (bytes[74] << 8) |
              bytes[75]) %
          1000000;
      return MeshSessionKeys(
        sendKey: role == MeshHandshakeRole.initiator
            ? initiatorToResponder
            : responderToInitiator,
        receiveKey: role == MeshHandshakeRole.initiator
            ? responderToInitiator
            : initiatorToResponder,
        sendNoncePrefix: role == MeshHandshakeRole.initiator
            ? initiatorNonce
            : responderNonce,
        receiveNoncePrefix: role == MeshHandshakeRole.initiator
            ? responderNonce
            : initiatorNonce,
        sas: sasNumber.toString().padLeft(6, '0'),
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
      shared.destroy();
      derived.destroy();
    }
  }

  Future<_StoredIdentity> _storedIdentity() {
    return _identityFuture ??= _loadOrCreateIdentity();
  }

  Future<_StoredIdentity> _loadOrCreateIdentity() async {
    var seedText = await _store.read(_seedKey);
    var deviceId = await _store.read(_deviceIdKey);
    if (seedText == null) {
      final seed = _randomBytes(32);
      try {
        seedText = base64UrlEncode(seed);
        await _store.write(_seedKey, seedText);
      } finally {
        seed.fillRange(0, seed.length, 0);
      }
    }
    if (deviceId == null || deviceId.isEmpty) {
      deviceId =
          await deviceIdProvider?.call() ??
          base64UrlEncode(_randomBytes(18)).replaceAll('=', '');
      await _store.write(_deviceIdKey, deviceId);
    }
    final seed = base64Url.decode(seedText);
    if (seed.length != 32) {
      throw StateError('Stored mesh identity seed is invalid.');
    }
    try {
      final keyPair = await _signatures.newKeyPairFromSeed(seed);
      return _StoredIdentity(
        deviceId: deviceId,
        keyPair: keyPair,
        publicKey: await keyPair.extractPublicKey(),
      );
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  Future<String> _fingerprint(List<int> publicKey) async {
    final digest = await Sha256().hash(publicKey);
    return base64UrlEncode(digest.bytes.sublist(0, 16)).replaceAll('=', '');
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  bool _sameParty(MeshHandshakeParty left, MeshHandshakeParty right) {
    return left.deviceId == right.deviceId &&
        _constantTimeEquals(left.identityPublicKey, right.identityPublicKey) &&
        _constantTimeEquals(
          left.ephemeralPublicKey,
          right.ephemeralPublicKey,
        ) &&
        _constantTimeEquals(left.nonce, right.nonce);
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}

class _StoredIdentity {
  const _StoredIdentity({
    required this.deviceId,
    required this.keyPair,
    required this.publicKey,
  });

  final String deviceId;
  final SimpleKeyPair keyPair;
  final SimplePublicKey publicKey;
}
