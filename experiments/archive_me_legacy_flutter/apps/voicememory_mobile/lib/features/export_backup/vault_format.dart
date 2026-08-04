import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

import 'vault_backup_models.dart';

const String vaultManifestPath = 'manifest.json';
const String vaultKeyringPath = 'portable-keyring.json';
const String vaultDataPrefix = 'data/';

final class VaultManifestEntry {
  const VaultManifestEntry({
    required this.schema,
    required this.relativePath,
    required this.size,
    required this.sha256,
    required this.createdAt,
  });

  final int schema;
  final String relativePath;
  final int size;
  final String sha256;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'schema': schema,
    'relativePath': relativePath,
    'size': size,
    'sha256': sha256,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory VaultManifestEntry.fromJson(Map<String, Object?> json) {
    _exactKeys(json, const {
      'schema',
      'relativePath',
      'size',
      'sha256',
      'createdAt',
    });
    final schema = json['schema'];
    final relativePath = json['relativePath'];
    final size = json['size'];
    final sha256 = json['sha256'];
    final createdAt = json['createdAt'];
    if (schema != 1 ||
        relativePath is! String ||
        size is! int ||
        size < 0 ||
        sha256 is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
        createdAt is! String) {
      throw const VaultBackupValidationException('Invalid manifest entry.');
    }
    validateSafeRelativePath(relativePath);
    return VaultManifestEntry(
      schema: schema as int,
      relativePath: relativePath,
      size: size,
      sha256: sha256,
      createdAt: DateTime.parse(createdAt).toUtc(),
    );
  }
}

final class VaultManifest {
  const VaultManifest({
    required this.schema,
    required this.createdAt,
    required this.entries,
    required this.hasPortableKeyring,
  });

  static const format = 'ArchiveMe.MemoryVault';
  static const currentSchema = 1;

  final int schema;
  final DateTime createdAt;
  final List<VaultManifestEntry> entries;
  final bool hasPortableKeyring;

  Uint8List toBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': format,
        'schema': schema,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'hasPortableKeyring': hasPortableKeyring,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      }),
    ),
  );

  factory VaultManifest.fromBytes(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException('Expected object.');
      final json = Map<String, Object?>.from(decoded);
      _exactKeys(json, const {
        'format',
        'schema',
        'createdAt',
        'hasPortableKeyring',
        'entries',
      });
      if (json['format'] != format ||
          json['schema'] != currentSchema ||
          json['createdAt'] is! String ||
          json['hasPortableKeyring'] is! bool ||
          json['entries'] is! List) {
        throw const FormatException('Invalid manifest metadata.');
      }
      final paths = <String>{};
      final entries = (json['entries']! as List)
          .map((raw) {
            if (raw is! Map) throw const FormatException('Invalid entry.');
            final entry = VaultManifestEntry.fromJson(
              Map<String, Object?>.from(raw),
            );
            if (!paths.add(entry.relativePath)) {
              throw const FormatException('Duplicate path.');
            }
            return entry;
          })
          .toList(growable: false);
      return VaultManifest(
        schema: json['schema']! as int,
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
        entries: entries,
        hasPortableKeyring: json['hasPortableKeyring']! as bool,
      );
    } on VaultBackupException {
      rethrow;
    } on Object catch (error) {
      throw VaultBackupValidationException('Invalid manifest: $error');
    }
  }
}

final class VaultEnvelope {
  VaultEnvelope({
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.tag,
  });

  static const format = 'ArchiveMe.MemoryVault';
  static const version = 1;
  static const kdf = 'PBKDF2-HMAC-SHA256';
  static const iterations = 100000;
  static const cipher = 'AES-256-GCM';

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List tag;

  Uint8List toBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': format,
        'version': version,
        'kdf': kdf,
        'iterations': iterations,
        'cipher': cipher,
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(ciphertext),
        'tag': base64Encode(tag),
      }),
    ),
  );

  factory VaultEnvelope.fromBytes(Uint8List bytes) {
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
        'salt',
        'nonce',
        'ciphertext',
        'tag',
      });
      if (json['format'] != format ||
          json['version'] != version ||
          json['kdf'] != kdf ||
          json['iterations'] != iterations ||
          json['cipher'] != cipher) {
        throw const FormatException('Unsupported envelope metadata.');
      }
      final envelope = VaultEnvelope(
        salt: _base64Field(json, 'salt'),
        nonce: _base64Field(json, 'nonce'),
        ciphertext: _base64Field(json, 'ciphertext'),
        tag: _base64Field(json, 'tag'),
      );
      if (envelope.salt.length != 16 ||
          envelope.nonce.length != 12 ||
          envelope.tag.length != 16) {
        throw const FormatException('Invalid cryptographic field length.');
      }
      return envelope;
    } on VaultBackupException {
      rethrow;
    } on Object catch (error) {
      throw VaultBackupValidationException('Invalid backup envelope: $error');
    }
  }
}

abstract interface class VaultZipCodec {
  Uint8List encode(Map<String, Uint8List> entries);
  Map<String, Uint8List> decode(Uint8List bytes, VaultBackupLimits limits);
}

final class ArchiveVaultZipCodec implements VaultZipCodec {
  const ArchiveVaultZipCodec();

  @override
  Uint8List encode(Map<String, Uint8List> entries) {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  @override
  Map<String, Uint8List> decode(Uint8List bytes, VaultBackupLimits limits) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.files.length > limits.maxEntries + 2) {
      throw const VaultBackupValidationException('Too many ZIP entries.');
    }
    var total = 0;
    final result = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      validateSafeRelativePath(file.name);
      if (result.containsKey(file.name)) {
        throw VaultBackupValidationException(
          'Duplicate ZIP path: ${file.name}.',
        );
      }
      if (file.size > limits.maxEntryBytes) {
        throw VaultBackupValidationException(
          'ZIP entry exceeds its size limit: ${file.name}.',
        );
      }
      total += file.size;
      if (total > limits.maxTotalBytes) {
        throw const VaultBackupValidationException(
          'ZIP exceeds its total size limit.',
        );
      }
      final content = Uint8List.fromList(file.content as List<int>);
      if (content.length != file.size) {
        throw VaultBackupValidationException(
          'ZIP entry size is inconsistent: ${file.name}.',
        );
      }
      result[file.name] = content;
    }
    return result;
  }
}

final class VaultCryptography {
  VaultCryptography({Random? random, AesGcm? aes})
    : _random = random ?? Random.secure(),
      _aes = aes ?? AesGcm.with256bits();

  final Random _random;
  final AesGcm _aes;

  Future<VaultEnvelope> encrypt(
    Uint8List plaintext,
    VaultCredential credential,
  ) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final keyBytes = await _deriveKey(credential.value, salt);
    try {
      final box = await _aes.encrypt(
        plaintext,
        secretKey: SecretKey(keyBytes),
        nonce: nonce,
        aad: _aad(),
      );
      return VaultEnvelope(
        salt: salt,
        nonce: nonce,
        ciphertext: Uint8List.fromList(box.cipherText),
        tag: Uint8List.fromList(box.mac.bytes),
      );
    } finally {
      wipeBytes(keyBytes);
    }
  }

  Future<Uint8List> decrypt(
    VaultEnvelope envelope,
    VaultCredential credential,
  ) async {
    final keyBytes = await _deriveKey(credential.value, envelope.salt);
    try {
      final clear = await _aes.decrypt(
        SecretBox(
          envelope.ciphertext,
          nonce: envelope.nonce,
          mac: Mac(envelope.tag),
        ),
        secretKey: SecretKey(keyBytes),
        aad: _aad(),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const VaultBackupAuthenticationException();
    } finally {
      wipeBytes(keyBytes);
    }
  }

  Future<Uint8List> _deriveKey(String value, List<int> salt) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: VaultEnvelope.iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: value, nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256), growable: false),
  );

  static Uint8List _aad() => Uint8List.fromList(
    utf8.encode(
      '${VaultEnvelope.format}|${VaultEnvelope.version}|'
      '${VaultEnvelope.kdf}|${VaultEnvelope.iterations}|${VaultEnvelope.cipher}',
    ),
  );
}

String vaultSha256(List<int> bytes) => hashes.sha256.convert(bytes).toString();

void _exactKeys(Map<String, Object?> json, Set<String> keys) {
  if (json.keys.toSet().length != keys.length ||
      !json.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unexpected or missing fields.');
  }
}

Uint8List _base64Field(Map<String, Object?> json, String name) {
  final value = json[name];
  if (value is! String) throw FormatException('$name must be base64.');
  return Uint8List.fromList(base64Decode(value));
}
