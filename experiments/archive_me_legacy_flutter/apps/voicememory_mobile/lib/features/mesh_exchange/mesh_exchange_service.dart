import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../core/graph/personal_knowledge_graph.dart';
import '../../services/security/mesh_identity_service.dart';
import '../cognitive_council/council_persona.dart';
import '../p2p_mesh/sync/peer_sync_channel.dart';
import '../semantic_clusters/semantic_cluster.dart';
import 'mesh_exchange_models.dart';

final class MeshExchangeException implements Exception {
  const MeshExchangeException(this.message);
  final String message;
  @override
  String toString() => 'MeshExchangeException: $message';
}

final class MeshExchangePackage {
  MeshExchangePackage({
    required this.exchangeId,
    required Uint8List bytes,
    required this.frames,
  }) : bytes = Uint8List.fromList(bytes);

  final String exchangeId;
  final Uint8List bytes;
  final List<MeshQrFrame> frames;
}

final class MeshExchangeService {
  MeshExchangeService({
    required this.identity,
    DateTime Function()? clock,
    Random? random,
    X25519? keyExchange,
    AesGcm? cipher,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure(),
       _keyExchange = keyExchange ?? X25519(),
       _cipher = cipher ?? AesGcm.with256bits();

  static const maxPlaintextBytes = 8 * 1024 * 1024;
  static const maxEnvelopeBytes = 9 * 1024 * 1024;
  static const defaultQrPayloadCharacters = 720;
  static final _hkdfInfo = utf8.encode(
    'ArchiveMe.MeshExchange.X25519.AES256GCM.v1',
  );

  final MeshIdentityService identity;
  final DateTime Function() _clock;
  final Random _random;
  final X25519 _keyExchange;
  final AesGcm _cipher;
  final Map<String, _PendingInvitation> _pendingInvitations = {};
  final Set<String> _consumedExchangeIds = {};

  Future<MeshExchangeInvitation> createInvitation({
    Duration lifetime = const Duration(minutes: 2),
  }) async {
    if (lifetime <= Duration.zero || lifetime > const Duration(minutes: 5)) {
      throw ArgumentError.value(lifetime, 'lifetime');
    }
    _removeExpiredInvitations();
    final keyPair = await _keyExchange.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final invitation = MeshExchangeInvitation(
      id: const Uuid().v4(),
      receiverEphemeralPublicKey: Uint8List.fromList(publicKey.bytes),
      nonce: _randomBytes(32),
      expiresAt: _clock().toUtc().add(lifetime),
    );
    _pendingInvitations[invitation.id] = _PendingInvitation(
      invitation,
      keyPair,
    );
    return invitation;
  }

  MeshExchangeContent buildContent({
    required String senderName,
    required PersonalKnowledgeGraph graph,
    required Iterable<String> selectedNodeIds,
    Iterable<SemanticCluster> clusters = const [],
    Iterable<CouncilPersona> personas = const [],
    Iterable<MeshJournalFragment> journalFragments = const [],
    MeshExchangePolicy policy = MeshExchangePolicy.reusable,
    DateTime? destructAt,
  }) {
    final selected = selectedNodeIds.toSet();
    final nodes = graph.nodes
        .where((node) => selected.contains(node.id))
        .toList();
    final nodeIds = nodes.map((node) => node.id).toSet();
    final edges = graph.edges
        .where(
          (edge) =>
              nodeIds.contains(edge.sourceNodeId) &&
              nodeIds.contains(edge.targetNodeId),
        )
        .toList();
    final includedClusters = clusters
        .where((cluster) => cluster.nodeIds.any(nodeIds.contains))
        .map(
          (cluster) => cluster.copyWith(
            nodeIds: cluster.nodeIds.where(nodeIds.contains),
          ),
        )
        .toList();
    if (nodes.length > 2000 ||
        edges.length > 5000 ||
        personas.length > 50 ||
        journalFragments.length > 100) {
      throw const MeshExchangeException(
        'Mesh Exchange selection is too large.',
      );
    }
    return MeshExchangeContent(
      id: const Uuid().v4(),
      senderName: senderName,
      graph: PersonalKnowledgeGraph(nodes: nodes, edges: edges),
      clusters: includedClusters,
      personas: personas,
      journalFragments: journalFragments,
      policy: policy,
      createdAt: _clock(),
      destructAt: destructAt,
    );
  }

  Future<MeshExchangePackage> package({
    required MeshExchangeInvitation invitation,
    required MeshExchangeContent content,
    int qrPayloadCharacters = defaultQrPayloadCharacters,
  }) async {
    if (!invitation.expiresAt.isAfter(_clock().toUtc())) {
      throw const MeshExchangeException('Recipient invitation has expired.');
    }
    if (qrPayloadCharacters < 128 || qrPayloadCharacters > 1800) {
      throw ArgumentError.value(qrPayloadCharacters, 'qrPayloadCharacters');
    }
    final senderEphemeral = await _keyExchange.newKeyPair();
    final senderPublic = await senderEphemeral.extractPublicKey();
    final shared = await _keyExchange.sharedSecretKey(
      keyPair: senderEphemeral,
      remotePublicKey: SimplePublicKey(
        invitation.receiverEphemeralPublicKey,
        type: KeyPairType.x25519,
      ),
    );
    final clear = Uint8List.fromList(utf8.encode(jsonEncode(content.toJson())));
    if (clear.length > maxPlaintextBytes) {
      throw const MeshExchangeException('Mesh Exchange payload is too large.');
    }
    final compressed = Uint8List.fromList(ZLibCodec().encode(clear));
    final nonce = _randomBytes(12);
    final senderIdentity = await identity.identity();
    final key = await _derive(shared, invitation, senderPublic.bytes);
    try {
      final unsigned = <String, Object>{
        'format': 'ArchiveMe.MeshExchange',
        'version': 1,
        'exchangeId': content.id,
        'invitationId': invitation.id,
        'senderIdentityKey': base64Encode(senderIdentity.publicKey),
        'senderEphemeralKey': base64Encode(senderPublic.bytes),
        'receiverEphemeralKey': base64Encode(
          invitation.receiverEphemeralPublicKey,
        ),
        'nonce': base64Encode(nonce),
        'ciphertext': '',
        'mac': '',
      };
      final aad = _aad(unsigned);
      final box = await _cipher.encrypt(
        compressed,
        secretKey: key,
        nonce: nonce,
        aad: aad,
      );
      unsigned['ciphertext'] = base64Encode(box.cipherText);
      unsigned['mac'] = base64Encode(box.mac.bytes);
      final signature = await identity.signDetached(_signingBytes(unsigned));
      final envelope = Uint8List.fromList(
        utf8.encode(
          jsonEncode({...unsigned, 'signature': base64Encode(signature)}),
        ),
      );
      if (envelope.length > maxEnvelopeBytes) {
        throw const MeshExchangeException('Encrypted envelope is too large.');
      }
      final frames = qrFrames(
        envelope,
        exchangeId: content.id,
        payloadCharacters: qrPayloadCharacters,
      );
      return MeshExchangePackage(
        exchangeId: content.id,
        bytes: envelope,
        frames: frames,
      );
    } finally {
      clear.fillRange(0, clear.length, 0);
      compressed.fillRange(0, compressed.length, 0);
      key.destroy();
      shared.destroy();
      senderEphemeral.destroy();
    }
  }

  Future<MeshExchangeContent> open(Uint8List envelopeBytes) async {
    if (envelopeBytes.isEmpty || envelopeBytes.length > maxEnvelopeBytes) {
      throw const MeshExchangeException('Invalid Mesh Exchange envelope size.');
    }
    try {
      final raw = jsonDecode(utf8.decode(envelopeBytes));
      if (raw is! Map) throw const FormatException();
      final envelope = Map<String, dynamic>.from(raw);
      _validateEnvelope(envelope);
      final exchangeId = envelope['exchangeId'] as String;
      if (_consumedExchangeIds.contains(exchangeId)) {
        throw const MeshExchangeException(
          'This read-once exchange was already consumed.',
        );
      }
      final invitationId = envelope['invitationId'] as String;
      final pending = _pendingInvitations[invitationId];
      if (pending == null ||
          !pending.invitation.expiresAt.isAfter(_clock().toUtc())) {
        throw const MeshExchangeException(
          'No active recipient handshake matches this package.',
        );
      }
      if (!_constantTimeEquals(
        base64Decode(envelope['receiverEphemeralKey'] as String),
        pending.invitation.receiverEphemeralPublicKey,
      )) {
        throw const MeshExchangeException(
          'Package was addressed to a different recipient.',
        );
      }
      final unsigned = Map<String, Object>.from(envelope)..remove('signature');
      final signerPublic = base64Decode(
        envelope['senderIdentityKey'] as String,
      );
      final signatureValid = await Ed25519().verify(
        _signingBytes(unsigned),
        signature: Signature(
          base64Decode(envelope['signature'] as String),
          publicKey: SimplePublicKey(signerPublic, type: KeyPairType.ed25519),
        ),
      );
      if (!signatureValid) {
        throw const MeshExchangeException(
          'Mesh Exchange signature is invalid.',
        );
      }
      final senderPublic = base64Decode(
        envelope['senderEphemeralKey'] as String,
      );
      final shared = await _keyExchange.sharedSecretKey(
        keyPair: pending.keyPair,
        remotePublicKey: SimplePublicKey(
          senderPublic,
          type: KeyPairType.x25519,
        ),
      );
      final key = await _derive(shared, pending.invitation, senderPublic);
      try {
        final compressed = await _cipher.decrypt(
          SecretBox(
            base64Decode(envelope['ciphertext'] as String),
            nonce: base64Decode(envelope['nonce'] as String),
            mac: Mac(base64Decode(envelope['mac'] as String)),
          ),
          secretKey: key,
          aad: _aad(unsigned),
        );
        final clear = _decompressBounded(compressed);
        final content = MeshExchangeContent.fromJson(
          Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map),
        );
        if (content.id != exchangeId ||
            content.policy == MeshExchangePolicy.selfDestruct &&
                !content.destructAt!.isAfter(_clock().toUtc())) {
          throw const MeshExchangeException(
            'Mesh Exchange payload expired or changed identity.',
          );
        }
        return content;
      } finally {
        key.destroy();
        shared.destroy();
      }
    } on MeshExchangeException {
      rethrow;
    } on Object {
      throw const MeshExchangeException(
        'Mesh Exchange package is invalid or was altered.',
      );
    }
  }

  void markConsumed(MeshExchangeContent content) {
    if (content.policy == MeshExchangePolicy.readOnce) {
      _consumedExchangeIds.add(content.id);
    }
  }

  List<MeshQrFrame> qrFrames(
    Uint8List envelope, {
    required String exchangeId,
    int payloadCharacters = defaultQrPayloadCharacters,
  }) {
    final encoded = base64UrlEncode(envelope);
    final digest = hashes.sha256.convert(envelope).toString();
    final total = (encoded.length / payloadCharacters).ceil().clamp(1, 10000);
    return List.unmodifiable([
      for (var index = 0; index < total; index++)
        MeshQrFrame(
          exchangeId: exchangeId,
          index: index,
          total: total,
          digest: digest,
          payload: encoded.substring(
            index * payloadCharacters,
            min(encoded.length, (index + 1) * payloadCharacters),
          ),
        ),
    ]);
  }

  Future<void> sendOverMesh(
    MeshExchangePackage package,
    AuthenticatedPeerSyncChannel channel, {
    int chunkBytes = 48 * 1024,
  }) async {
    final digest = hashes.sha256.convert(package.bytes).toString();
    final total = (package.bytes.length / chunkBytes).ceil();
    for (var index = 0; index < total; index++) {
      await channel.send({
        'type': 'mesh_exchange_chunk',
        'exchangeId': package.exchangeId,
        'index': index,
        'total': total,
        'sha256': digest,
        'data': base64Encode(
          package.bytes.sublist(
            index * chunkBytes,
            min(package.bytes.length, (index + 1) * chunkBytes),
          ),
        ),
      });
    }
  }

  Future<SecretKey> _derive(
    SecretKey shared,
    MeshExchangeInvitation invitation,
    List<int> senderPublic,
  ) => Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: shared,
    nonce: invitation.nonce,
    info: [
      ..._hkdfInfo,
      ...utf8.encode(invitation.id),
      ...senderPublic,
      ...invitation.receiverEphemeralPublicKey,
    ],
  );

  Uint8List _aad(Map<String, Object> envelope) => Uint8List.fromList(
    utf8.encode(
      'ArchiveMe.MeshExchange|1|${envelope['exchangeId']}|'
      '${envelope['invitationId']}|${envelope['senderIdentityKey']}|'
      '${envelope['senderEphemeralKey']}|'
      '${envelope['receiverEphemeralKey']}',
    ),
  );

  Uint8List _signingBytes(Map<String, Object> unsigned) =>
      Uint8List.fromList(utf8.encode(jsonEncode(unsigned)));

  void _validateEnvelope(Map<String, dynamic> envelope) {
    const fields = {
      'format',
      'version',
      'exchangeId',
      'invitationId',
      'senderIdentityKey',
      'senderEphemeralKey',
      'receiverEphemeralKey',
      'nonce',
      'ciphertext',
      'mac',
      'signature',
    };
    if (envelope.keys.toSet().difference(fields).isNotEmpty ||
        envelope.length != fields.length ||
        envelope['format'] != 'ArchiveMe.MeshExchange' ||
        envelope['version'] != 1 ||
        base64Decode(envelope['senderIdentityKey'] as String).length != 32 ||
        base64Decode(envelope['senderEphemeralKey'] as String).length != 32 ||
        base64Decode(envelope['receiverEphemeralKey'] as String).length != 32 ||
        base64Decode(envelope['nonce'] as String).length != 12 ||
        base64Decode(envelope['mac'] as String).length != 16 ||
        base64Decode(envelope['signature'] as String).length != 64) {
      throw const MeshExchangeException('Invalid Mesh Exchange envelope.');
    }
  }

  void _removeExpiredInvitations() {
    final now = _clock().toUtc();
    final expired = _pendingInvitations.entries
        .where((entry) => !entry.value.invitation.expiresAt.isAfter(now))
        .map((entry) => entry.key)
        .toList();
    for (final id in expired) {
      _pendingInvitations.remove(id)?.keyPair.destroy();
    }
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  Uint8List _decompressBounded(List<int> compressed) {
    final output = _BoundedByteSink(maxPlaintextBytes);
    final decoder = ZLibCodec().decoder.startChunkedConversion(output);
    decoder.add(compressed);
    decoder.close();
    return Uint8List.fromList(output.bytes);
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  void dispose() {
    for (final pending in _pendingInvitations.values) {
      pending.keyPair.destroy();
    }
    _pendingInvitations.clear();
    _consumedExchangeIds.clear();
  }
}

final class MeshQrAssembler {
  final Map<int, MeshQrFrame> _frames = {};
  String? _exchangeId;
  String? _digest;
  int? _total;

  double get progress => _total == null ? 0 : _frames.length / _total!;

  Uint8List? add(String encodedFrame) {
    final frame = MeshQrFrame.decode(encodedFrame);
    if (_exchangeId != null &&
        (_exchangeId != frame.exchangeId ||
            _digest != frame.digest ||
            _total != frame.total)) {
      throw const MeshExchangeException('QR sequence does not match.');
    }
    if (frame.total < 1 ||
        frame.total > 10000 ||
        frame.index < 0 ||
        frame.index >= frame.total) {
      throw const MeshExchangeException('QR frame position is invalid.');
    }
    _exchangeId = frame.exchangeId;
    _digest = frame.digest;
    _total = frame.total;
    _frames[frame.index] = frame;
    if (_frames.length != frame.total) return null;
    final bytes = base64Url.decode(
      [
        for (var index = 0; index < frame.total; index++)
          _frames[index]!.payload,
      ].join(),
    );
    if (hashes.sha256.convert(bytes).toString() != frame.digest) {
      throw const MeshExchangeException('QR sequence checksum failed.');
    }
    return Uint8List.fromList(bytes);
  }
}

final class _PendingInvitation {
  const _PendingInvitation(this.invitation, this.keyPair);
  final MeshExchangeInvitation invitation;
  final SimpleKeyPair keyPair;
}

final class _BoundedByteSink extends ByteConversionSink {
  _BoundedByteSink(this.maximumBytes);

  final int maximumBytes;
  final List<int> bytes = [];

  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > maximumBytes) {
      throw const MeshExchangeException(
        'Expanded Mesh Exchange payload is too large.',
      );
    }
    bytes.addAll(chunk);
  }

  @override
  void close() {}
}
