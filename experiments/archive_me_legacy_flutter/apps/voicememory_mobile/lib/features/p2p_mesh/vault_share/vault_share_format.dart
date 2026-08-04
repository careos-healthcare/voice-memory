// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

import 'vault_share_models.dart';

const vaultShareManifestPath = 'manifest.json';
const vaultShareClustersPath = 'data/clusters.json';
const vaultShareGraphPath = 'data/graph.json';
const vaultShareMediaPrefix = 'media/';

final class VaultShareManifestEntry {
  const VaultShareManifestEntry({
    required this.path,
    required this.size,
    required this.sha256,
  });

  final String path;
  final int size;
  final String sha256;

  Map<String, Object> toJson() => {
    'path': path,
    'size': size,
    'sha256': sha256,
  };

  factory VaultShareManifestEntry.fromJson(Map<String, Object?> json) {
    _exactKeys(json, const {'path', 'size', 'sha256'});
    final path = json['path'];
    final size = json['size'];
    final sha256 = json['sha256'];
    if (path is! String ||
        size is! int ||
        size < 0 ||
        sha256 is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const VaultShareValidationException('Invalid manifest entry.');
    }
    validateVaultSharePath(path);
    return VaultShareManifestEntry(path: path, size: size, sha256: sha256);
  }
}

final class VaultShareManifest {
  VaultShareManifest({
    required this.shareId,
    required DateTime createdAt,
    required this.signerId,
    required this.includesCitationExcerpts,
    required Iterable<String> clusterIds,
    required Iterable<String> mediaAttachmentIds,
    required Iterable<VaultShareManifestEntry> entries,
  }) : createdAt = createdAt.toUtc(),
       clusterIds = List.unmodifiable(clusterIds),
       mediaAttachmentIds = List.unmodifiable(mediaAttachmentIds),
       entries = List.unmodifiable(entries);

  static const format = 'ArchiveMe.SelectiveVaultShare';
  static const schema = 1;

  final String shareId;
  final DateTime createdAt;
  final String signerId;
  final bool includesCitationExcerpts;
  final List<String> clusterIds;
  final List<String> mediaAttachmentIds;
  final List<VaultShareManifestEntry> entries;

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  Map<String, Object> toJson() => {
    'format': format,
    'schema': schema,
    'shareId': shareId,
    'createdAt': createdAt.toIso8601String(),
    'signerId': signerId,
    'includesCitationExcerpts': includesCitationExcerpts,
    'clusterIds': clusterIds,
    'mediaAttachmentIds': mediaAttachmentIds,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory VaultShareManifest.fromBytes(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException('Expected object.');
      final json = Map<String, Object?>.from(decoded);
      _exactKeys(json, const {
        'format',
        'schema',
        'shareId',
        'createdAt',
        'signerId',
        'includesCitationExcerpts',
        'clusterIds',
        'mediaAttachmentIds',
        'entries',
      });
      if (json['format'] != format ||
          json['schema'] != schema ||
          json['shareId'] is! String ||
          json['createdAt'] is! String ||
          json['signerId'] is! String ||
          json['includesCitationExcerpts'] is! bool) {
        throw const FormatException('Unsupported manifest.');
      }
      final createdAt = DateTime.tryParse(json['createdAt']! as String);
      final clusterIds = _stringList(json['clusterIds'], 'clusterIds');
      final mediaIds = _stringList(
        json['mediaAttachmentIds'],
        'mediaAttachmentIds',
      );
      final rawEntries = json['entries'];
      if (createdAt == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(json['shareId']! as String) ||
          (json['signerId']! as String).isEmpty ||
          (json['signerId']! as String).length > 256 ||
          rawEntries is! List) {
        throw const FormatException('Invalid manifest metadata.');
      }
      final paths = <String>{};
      final entries = rawEntries
          .map((raw) {
            if (raw is! Map) throw const FormatException('Invalid entry.');
            final entry = VaultShareManifestEntry.fromJson(
              Map<String, Object?>.from(raw),
            );
            if (!paths.add(entry.path)) {
              throw const FormatException('Duplicate manifest path.');
            }
            return entry;
          })
          .toList(growable: false);
      if (!paths.contains(vaultShareClustersPath) ||
          !paths.contains(vaultShareGraphPath)) {
        throw const FormatException('Required data entries are missing.');
      }
      return VaultShareManifest(
        shareId: json['shareId']! as String,
        createdAt: createdAt,
        signerId: json['signerId']! as String,
        includesCitationExcerpts: json['includesCitationExcerpts']! as bool,
        clusterIds: clusterIds,
        mediaAttachmentIds: mediaIds,
        entries: entries,
      );
    } on VaultShareException {
      rethrow;
    } on Object catch (error) {
      throw VaultShareValidationException('Invalid share manifest: $error');
    }
  }
}

final class VaultShareEnvelope {
  VaultShareEnvelope({
    required this.signerId,
    required this.signerPublicKey,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.tag,
    required this.signature,
  });

  static const format = 'ArchiveMe.SelectiveVaultShare';
  static const version = 1;
  static const kdf = 'PBKDF2-HMAC-SHA256';
  static const iterations = 210000;
  static const cipher = 'AES-256-GCM';
  static const signatureAlgorithm = 'Ed25519';

  final String signerId;
  final Uint8List signerPublicKey;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List tag;
  final Uint8List signature;

  Uint8List signingBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': format,
        'version': version,
        'kdf': kdf,
        'iterations': iterations,
        'cipher': cipher,
        'signatureAlgorithm': signatureAlgorithm,
        'signerId': signerId,
        'signerPublicKey': base64Encode(signerPublicKey),
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(ciphertext),
        'tag': base64Encode(tag),
      }),
    ),
  );

  Uint8List toBytes() {
    final unsigned = jsonDecode(utf8.decode(signingBytes())) as Map;
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({...unsigned, 'signature': base64Encode(signature)}),
      ),
    );
  }

  factory VaultShareEnvelope.fromBytes(
    Uint8List bytes, {
    required VaultShareLimits limits,
  }) {
    if (bytes.length > limits.maxEnvelopeBytes) {
      throw const VaultShareValidationException(
        'Share envelope exceeds its size limit.',
      );
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException('Expected object.');
      final json = Map<String, Object?>.from(decoded);
      _exactKeys(json, const {
        'format',
        'version',
        'kdf',
        'iterations',
        'cipher',
        'signatureAlgorithm',
        'signerId',
        'signerPublicKey',
        'salt',
        'nonce',
        'ciphertext',
        'tag',
        'signature',
      });
      if (json['format'] != format ||
          json['version'] != version ||
          json['kdf'] != kdf ||
          json['iterations'] != iterations ||
          json['cipher'] != cipher ||
          json['signatureAlgorithm'] != signatureAlgorithm ||
          json['signerId'] is! String ||
          (json['signerId']! as String).isEmpty ||
          (json['signerId']! as String).length > 256) {
        throw const FormatException('Unsupported envelope metadata.');
      }
      final envelope = VaultShareEnvelope(
        signerId: json['signerId']! as String,
        signerPublicKey: _base64(json, 'signerPublicKey'),
        salt: _base64(json, 'salt'),
        nonce: _base64(json, 'nonce'),
        ciphertext: _base64(json, 'ciphertext'),
        tag: _base64(json, 'tag'),
        signature: _base64(json, 'signature'),
      );
      if (envelope.signerPublicKey.length != 32 ||
          envelope.salt.length != 16 ||
          envelope.nonce.length != 12 ||
          envelope.tag.length != 16 ||
          envelope.signature.length != 64) {
        throw const FormatException('Invalid cryptographic field length.');
      }
      return envelope;
    } on VaultShareException {
      rethrow;
    } on Object catch (error) {
      throw VaultShareValidationException('Invalid share envelope: $error');
    }
  }
}

final class VaultShareCryptography {
  VaultShareCryptography({Random? random, AesGcm? aes})
    : _random = random ?? Random.secure(),
      _aes = aes ?? AesGcm.with256bits();

  final Random _random;
  final AesGcm _aes;

  Future<VaultShareEnvelope> encryptAndSign({
    required Uint8List plaintext,
    required VaultSharePassword password,
    required VaultShareSigner signer,
  }) async {
    if (signer.signerId.isEmpty ||
        signer.signerId.length > 256 ||
        signer.publicKeyBytes.length != 32) {
      throw const VaultShareValidationException(
        'Invalid Ed25519 signer identity.',
      );
    }
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _derive(password.value, salt);
    try {
      final box = await _aes.encrypt(
        plaintext,
        secretKey: SecretKey(key),
        nonce: nonce,
        aad: _aad(),
      );
      final unsigned = VaultShareEnvelope(
        signerId: signer.signerId,
        signerPublicKey: Uint8List.fromList(signer.publicKeyBytes),
        salt: salt,
        nonce: nonce,
        ciphertext: Uint8List.fromList(box.cipherText),
        tag: Uint8List.fromList(box.mac.bytes),
        signature: Uint8List(0),
      );
      final signature = await signer.sign(unsigned.signingBytes());
      if (signature.length != 64) {
        throw const VaultShareValidationException(
          'Invalid Ed25519 signature length.',
        );
      }
      return VaultShareEnvelope(
        signerId: unsigned.signerId,
        signerPublicKey: unsigned.signerPublicKey,
        salt: salt,
        nonce: nonce,
        ciphertext: unsigned.ciphertext,
        tag: unsigned.tag,
        signature: signature,
      );
    } finally {
      _wipe(key);
    }
  }

  Future<Uint8List> decrypt(
    VaultShareEnvelope envelope,
    VaultSharePassword password,
  ) async {
    final key = await _derive(password.value, envelope.salt);
    try {
      final clear = await _aes.decrypt(
        SecretBox(
          envelope.ciphertext,
          nonce: envelope.nonce,
          mac: Mac(envelope.tag),
        ),
        secretKey: SecretKey(key),
        aad: _aad(),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const VaultShareAuthenticationException();
    } finally {
      _wipe(key);
    }
  }

  Future<Uint8List> _derive(String password, List<int> salt) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: VaultShareEnvelope.iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList(
    List.generate(length, (_) => _random.nextInt(256), growable: false),
  );

  static Uint8List _aad() => Uint8List.fromList(
    utf8.encode(
      '${VaultShareEnvelope.format}|${VaultShareEnvelope.version}|'
      '${VaultShareEnvelope.kdf}|${VaultShareEnvelope.iterations}|'
      '${VaultShareEnvelope.cipher}',
    ),
  );
}

final class CryptographyVaultShareVerifier
    implements VaultShareSignatureVerifier {
  CryptographyVaultShareVerifier({Ed25519? algorithm})
    : _algorithm = algorithm ?? Ed25519();

  final Ed25519 _algorithm;

  @override
  Future<bool> verify({
    required Uint8List message,
    required Uint8List signature,
    required Uint8List publicKeyBytes,
  }) => _algorithm.verify(
    message,
    signature: Signature(
      signature,
      publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
    ),
  );
}

final class CryptographyVaultShareSigner implements VaultShareSigner {
  CryptographyVaultShareSigner._({
    required this.signerId,
    required SimpleKeyPair keyPair,
    required Uint8List publicKeyBytes,
    Ed25519? algorithm,
  }) : _keyPair = keyPair,
       publicKeyBytes = publicKeyBytes,
       _algorithm = algorithm ?? Ed25519();

  static Future<CryptographyVaultShareSigner> create({
    required String signerId,
    required SimpleKeyPair keyPair,
    Ed25519? algorithm,
  }) async {
    final publicKey = await keyPair.extractPublicKey();
    return CryptographyVaultShareSigner._(
      signerId: signerId,
      keyPair: keyPair,
      publicKeyBytes: Uint8List.fromList(publicKey.bytes),
      algorithm: algorithm,
    );
  }

  final SimpleKeyPair _keyPair;
  final Ed25519 _algorithm;

  @override
  final String signerId;

  @override
  final Uint8List publicKeyBytes;

  @override
  Future<Uint8List> sign(Uint8List message) async {
    final signature = await _algorithm.sign(message, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }
}

String vaultShareSha256(List<int> bytes) =>
    hashes.sha256.convert(bytes).toString();

String vaultSharePublicKeyFingerprint(List<int> bytes) =>
    vaultShareSha256(bytes);

void validateVaultSharePath(String value) {
  if (value.isEmpty ||
      value.contains('\u0000') ||
      value.contains('\\') ||
      value.startsWith('/') ||
      RegExp(r'^[a-zA-Z]:').hasMatch(value) ||
      value
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw VaultShareValidationException('Unsafe share path: $value.');
  }
}

void _exactKeys(Map<String, Object?> json, Set<String> keys) {
  if (json.keys.length != keys.length || !json.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unexpected or missing fields.');
  }
}

List<String> _stringList(Object? raw, String field) {
  if (raw is! List) throw FormatException('$field must be a list.');
  final values = <String>[];
  final unique = <String>{};
  for (final value in raw) {
    if (value is! String ||
        value.isEmpty ||
        value.length > 256 ||
        !unique.add(value)) {
      throw FormatException('Invalid $field.');
    }
    values.add(value);
  }
  return List.unmodifiable(values);
}

Uint8List _base64(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String) throw FormatException('$field must be base64.');
  final decoded = base64Decode(value);
  if (base64Encode(decoded) != value) {
    throw FormatException('$field is not canonical base64.');
  }
  return Uint8List.fromList(decoded);
}

void _wipe(List<int> bytes) {
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}
