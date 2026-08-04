import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as path;
import 'package:pointycastle/export.dart' as pc;

/// Data that may be included in a portable disaster-recovery backup.
enum RecoveryDataKind { journal, preferences, ledger, audio }

/// A normalized input supplied by the application.
///
/// Journal, preferences, and ledger snapshots must each use their kind's
/// canonical filename. Audio paths are relative paths below the audio root.
final class RecoveryInput {
  RecoveryInput({
    required this.kind,
    required this.logicalPath,
    required List<int> bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final RecoveryDataKind kind;
  final String logicalPath;
  final Uint8List bytes;
}

/// Application adapter that supplies normalized, non-secret backup inputs.
abstract interface class DisasterRecoverySource {
  Future<List<RecoveryInput>> readNormalizedInputs();
}

/// Begins a staged import. Nothing should become visible before [commit].
abstract interface class DisasterRecoverySink {
  Future<DisasterRecoveryImportTransaction> beginStagedImport();
}

/// A rollback-capable staging area owned by the application.
abstract interface class DisasterRecoveryImportTransaction {
  Future<void> stage(RecoveryInput input);

  Future<void> commit();

  Future<void> rollback();
}

/// ZIP implementation boundary.
///
/// A production implementation must encode a ZIP byte stream and reject
/// duplicate archive names while decoding. Keeping this boundary separate
/// allows the recovery core to compile without a direct `archive` dependency.
abstract interface class DisasterRecoveryZipCodec {
  Future<Uint8List> encode(Map<String, Uint8List> entries);

  Future<Map<String, Uint8List>> decode(Uint8List zipBytes);
}

/// Secure material is intentionally outside the portable backup format.
abstract final class DisasterRecoveryExclusionPolicy {
  static const excludedData = <String>[
    'device_encryption_keys',
    'secure_storage_credentials',
    'device_bound_secrets',
  ];

  static const _reservedPathSegments = <String>{
    'credentials',
    'keys',
    'secure',
    'secure_keys',
    'secrets',
  };

  static bool isReservedPath(String value) {
    final segments = value.toLowerCase().split('/');
    return segments.any(_reservedPathSegments.contains);
  }
}

final class DisasterRecoveryKdfMetadata {
  const DisasterRecoveryKdfMetadata({
    required this.name,
    required this.version,
    required this.iterations,
    required this.keyBits,
    required this.memoryKiB,
    required this.parallelism,
  });

  static const argon2idV1 = DisasterRecoveryKdfMetadata(
    name: 'Argon2id',
    version: 1,
    iterations: 3,
    keyBits: 256,
    memoryKiB: 65536,
    parallelism: 1,
  );

  final String name;
  final int version;
  final int iterations;
  final int keyBits;
  final int memoryKiB;
  final int parallelism;

  Map<String, Object> toJson() => {
    'name': name,
    'version': version,
    'iterations': iterations,
    'keyBits': keyBits,
    'memoryKiB': memoryKiB,
    'parallelism': parallelism,
  };

  factory DisasterRecoveryKdfMetadata.fromJson(Map<String, Object?> json) {
    return DisasterRecoveryKdfMetadata(
      name: _requiredString(json, 'name'),
      version: _requiredInt(json, 'version'),
      iterations: _requiredInt(json, 'iterations'),
      keyBits: _requiredInt(json, 'keyBits'),
      memoryKiB: _requiredInt(json, 'memoryKiB'),
      parallelism: _requiredInt(json, 'parallelism'),
    );
  }
}

/// Authenticated portable envelope whose plaintext is a ZIP byte stream.
final class DisasterRecoveryEnvelope {
  DisasterRecoveryEnvelope({
    required this.version,
    required this.cipher,
    required this.kdf,
    required List<int> salt,
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> mac,
  }) : salt = Uint8List.fromList(salt),
       nonce = Uint8List.fromList(nonce),
       ciphertext = Uint8List.fromList(ciphertext),
       mac = Uint8List.fromList(mac);

  static const format = 'ArchiveMe.DisasterRecovery';
  static const currentVersion = 1;
  static const cipherName = 'AES-256-GCM';

  final int version;
  final String cipher;
  final DisasterRecoveryKdfMetadata kdf;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;

  Map<String, Object> toJson() => {
    'format': format,
    'version': version,
    'cipher': cipher,
    'kdf': kdf.toJson(),
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(ciphertext),
    'mac': base64Encode(mac),
  };

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory DisasterRecoveryEnvelope.fromBytes(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException('Envelope must be a JSON object.');
      }
      final json = Map<String, Object?>.from(decoded);
      if (_requiredString(json, 'format') != format) {
        throw const FormatException('Unknown disaster-recovery format.');
      }
      final kdfJson = json['kdf'];
      if (kdfJson is! Map) {
        throw const FormatException('Missing KDF metadata.');
      }
      final envelope = DisasterRecoveryEnvelope(
        version: _requiredInt(json, 'version'),
        cipher: _requiredString(json, 'cipher'),
        kdf: DisasterRecoveryKdfMetadata.fromJson(
          Map<String, Object?>.from(kdfJson),
        ),
        salt: base64Decode(_requiredString(json, 'salt')),
        nonce: base64Decode(_requiredString(json, 'nonce')),
        ciphertext: base64Decode(_requiredString(json, 'ciphertext')),
        mac: base64Decode(_requiredString(json, 'mac')),
      );
      envelope.validateMetadata();
      return envelope;
    } on DisasterRecoveryException {
      rethrow;
    } on Object catch (error) {
      throw DisasterRecoveryFormatException('Invalid envelope: $error');
    }
  }

  void validateMetadata() {
    if (version != currentVersion) {
      throw DisasterRecoveryFormatException(
        'Unsupported envelope version: $version.',
      );
    }
    if (cipher != cipherName) {
      throw DisasterRecoveryFormatException('Unsupported cipher: $cipher.');
    }
    if (kdf.name != DisasterRecoveryKdfMetadata.argon2idV1.name ||
        kdf.version != DisasterRecoveryKdfMetadata.argon2idV1.version ||
        kdf.iterations != DisasterRecoveryKdfMetadata.argon2idV1.iterations ||
        kdf.keyBits != DisasterRecoveryKdfMetadata.argon2idV1.keyBits ||
        kdf.memoryKiB != DisasterRecoveryKdfMetadata.argon2idV1.memoryKiB ||
        kdf.parallelism != DisasterRecoveryKdfMetadata.argon2idV1.parallelism) {
      throw DisasterRecoveryFormatException(
        'Unsupported or unsafe KDF metadata.',
      );
    }
    if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
      throw DisasterRecoveryFormatException(
        'Invalid salt, nonce, or authentication tag length.',
      );
    }
  }
}

final class DisasterRecoveryManifestEntry {
  const DisasterRecoveryManifestEntry({
    required this.kind,
    required this.archivePath,
    required this.logicalPath,
    required this.length,
    required this.sha256,
  });

  final RecoveryDataKind kind;
  final String archivePath;
  final String logicalPath;
  final int length;
  final String sha256;

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'archivePath': archivePath,
    'logicalPath': logicalPath,
    'length': length,
    'sha256': sha256,
  };

  factory DisasterRecoveryManifestEntry.fromJson(Map<String, Object?> json) {
    final kindName = _requiredString(json, 'kind');
    final kind = RecoveryDataKind.values.where((value) {
      return value.name == kindName;
    }).firstOrNull;
    if (kind == null) {
      throw DisasterRecoveryFormatException('Unknown data kind: $kindName.');
    }
    return DisasterRecoveryManifestEntry(
      kind: kind,
      archivePath: _requiredString(json, 'archivePath'),
      logicalPath: _requiredString(json, 'logicalPath'),
      length: _requiredInt(json, 'length'),
      sha256: _requiredString(json, 'sha256'),
    );
  }
}

final class DisasterRecoveryManifest {
  const DisasterRecoveryManifest({
    required this.version,
    required this.entries,
    required this.excludedData,
  });

  static const currentVersion = 1;
  static const archivePath = 'manifest.json';

  final int version;
  final List<DisasterRecoveryManifestEntry> entries;
  final List<String> excludedData;

  Map<String, Object> toJson() => {
    'format': DisasterRecoveryEnvelope.format,
    'version': version,
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    'excludedData': excludedData,
  };

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory DisasterRecoveryManifest.fromBytes(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException('Manifest must be a JSON object.');
      }
      final json = Map<String, Object?>.from(decoded);
      if (_requiredString(json, 'format') != DisasterRecoveryEnvelope.format) {
        throw const FormatException('Unknown manifest format.');
      }
      final rawEntries = json['entries'];
      final rawExclusions = json['excludedData'];
      if (rawEntries is! List || rawExclusions is! List) {
        throw const FormatException('Invalid manifest collections.');
      }
      return DisasterRecoveryManifest(
        version: _requiredInt(json, 'version'),
        entries: rawEntries
            .map((entry) {
              if (entry is! Map) {
                throw const FormatException('Invalid manifest entry.');
              }
              return DisasterRecoveryManifestEntry.fromJson(
                Map<String, Object?>.from(entry),
              );
            })
            .toList(growable: false),
        excludedData: rawExclusions.cast<String>().toList(growable: false),
      );
    } on DisasterRecoveryException {
      rethrow;
    } on Object catch (error) {
      throw DisasterRecoveryFormatException('Invalid manifest: $error');
    }
  }
}

final class DisasterRecoveryCore {
  DisasterRecoveryCore({required this.zipCodec, Random? random, AesGcm? cipher})
    : _random = random ?? Random.secure(),
      _cipher = cipher ?? AesGcm.with256bits();

  final DisasterRecoveryZipCodec zipCodec;
  final Random _random;
  final AesGcm _cipher;

  Future<DisasterRecoveryEnvelope> export({
    required String passphrase,
    required DisasterRecoverySource source,
  }) async {
    _requirePassphrase(passphrase);
    final inputs = await source.readNormalizedInputs();
    final prepared = _prepareInputs(inputs);
    final manifestEntries = <DisasterRecoveryManifestEntry>[];
    final archiveEntries = SplayTreeMap<String, Uint8List>();
    for (final input in prepared) {
      final archivePath = _archivePath(input);
      archiveEntries[archivePath] = Uint8List.fromList(input.bytes);
      manifestEntries.add(
        DisasterRecoveryManifestEntry(
          kind: input.kind,
          archivePath: archivePath,
          logicalPath: input.logicalPath,
          length: input.bytes.length,
          sha256: hashes.sha256.convert(input.bytes).toString(),
        ),
      );
    }
    final manifest = DisasterRecoveryManifest(
      version: DisasterRecoveryManifest.currentVersion,
      entries: List.unmodifiable(manifestEntries),
      excludedData: DisasterRecoveryExclusionPolicy.excludedData,
    );
    archiveEntries[DisasterRecoveryManifest.archivePath] = manifest.toBytes();
    final zipBytes = await zipCodec.encode(UnmodifiableMapView(archiveEntries));
    return _encryptZip(zipBytes, passphrase);
  }

  Future<void> import({
    required List<int> envelopeBytes,
    required String passphrase,
    required DisasterRecoverySink sink,
  }) async {
    _requirePassphrase(passphrase);
    final envelope = DisasterRecoveryEnvelope.fromBytes(envelopeBytes);
    final zipBytes = await _decryptZip(envelope, passphrase);
    final archiveEntries = await zipCodec.decode(zipBytes);
    final inputs = _validateArchive(archiveEntries);

    final transaction = await sink.beginStagedImport();
    try {
      for (final input in inputs) {
        await transaction.stage(input);
      }
      await transaction.commit();
    } on Object {
      try {
        await transaction.rollback();
      } on Object {
        // Preserve the operation that caused the rollback.
      }
      rethrow;
    }
  }

  Future<DisasterRecoveryEnvelope> _encryptZip(
    Uint8List zipBytes,
    String passphrase,
  ) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    const kdf = DisasterRecoveryKdfMetadata.argon2idV1;
    final secretKey = await _deriveKey(passphrase, salt, kdf);
    final box = await _cipher.encrypt(
      zipBytes,
      secretKey: secretKey,
      nonce: nonce,
      aad: _aad(DisasterRecoveryEnvelope.currentVersion, kdf),
    );
    return DisasterRecoveryEnvelope(
      version: DisasterRecoveryEnvelope.currentVersion,
      cipher: DisasterRecoveryEnvelope.cipherName,
      kdf: kdf,
      salt: salt,
      nonce: nonce,
      ciphertext: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  Future<Uint8List> _decryptZip(
    DisasterRecoveryEnvelope envelope,
    String passphrase,
  ) async {
    envelope.validateMetadata();
    final key = await _deriveKey(passphrase, envelope.salt, envelope.kdf);
    try {
      final cleartext = await _cipher.decrypt(
        SecretBox(
          envelope.ciphertext,
          nonce: envelope.nonce,
          mac: Mac(envelope.mac),
        ),
        secretKey: key,
        aad: _aad(envelope.version, envelope.kdf),
      );
      return Uint8List.fromList(cleartext);
    } on SecretBoxAuthenticationError {
      throw const DisasterRecoveryAuthenticationException();
    }
  }

  Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
    DisasterRecoveryKdfMetadata kdf,
  ) async {
    final bytes = await Isolate.run(
      () => _deriveArgon2id(
        passphrase,
        salt,
        iterations: kdf.iterations,
        memoryKiB: kdf.memoryKiB,
        parallelism: kdf.parallelism,
        keyLength: kdf.keyBits ~/ 8,
      ),
    );
    return SecretKey(bytes);
  }

  List<RecoveryInput> _prepareInputs(List<RecoveryInput> inputs) {
    final prepared = <RecoveryInput>[];
    final singletonKinds = <RecoveryDataKind, int>{};
    final archivePaths = <String>{};
    for (final input in inputs) {
      _validateLogicalPath(input.kind, input.logicalPath);
      if (input.kind != RecoveryDataKind.audio) {
        singletonKinds.update(
          input.kind,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      final candidate = _archivePath(input);
      if (!archivePaths.add(candidate)) {
        throw DisasterRecoveryFormatException(
          'Duplicate recovery path: $candidate.',
        );
      }
      prepared.add(input);
    }
    for (final kind in const [
      RecoveryDataKind.journal,
      RecoveryDataKind.preferences,
      RecoveryDataKind.ledger,
    ]) {
      if (singletonKinds[kind] != 1) {
        throw DisasterRecoveryFormatException(
          'Exactly one normalized ${kind.name} input is required.',
        );
      }
    }
    prepared.sort((left, right) {
      return _archivePath(left).compareTo(_archivePath(right));
    });
    return List.unmodifiable(prepared);
  }

  List<RecoveryInput> _validateArchive(Map<String, Uint8List> entries) {
    for (final archivePath in entries.keys) {
      _validateSafeRelativePath(archivePath);
    }
    final manifestBytes = entries[DisasterRecoveryManifest.archivePath];
    if (manifestBytes == null) {
      throw const DisasterRecoveryFormatException('Manifest is missing.');
    }
    final manifest = DisasterRecoveryManifest.fromBytes(manifestBytes);
    if (manifest.version != DisasterRecoveryManifest.currentVersion) {
      throw DisasterRecoveryFormatException(
        'Unsupported manifest version: ${manifest.version}.',
      );
    }
    if (!Set<String>.from(
      manifest.excludedData,
    ).containsAll(DisasterRecoveryExclusionPolicy.excludedData)) {
      throw const DisasterRecoveryFormatException(
        'Manifest does not declare the secure-key exclusions.',
      );
    }

    final expectedPaths = <String>{DisasterRecoveryManifest.archivePath};
    final inputs = <RecoveryInput>[];
    for (final manifestEntry in manifest.entries) {
      _validateLogicalPath(manifestEntry.kind, manifestEntry.logicalPath);
      _validateSafeRelativePath(manifestEntry.archivePath);
      final expectedPath = _archivePathFor(
        manifestEntry.kind,
        manifestEntry.logicalPath,
      );
      if (manifestEntry.archivePath != expectedPath ||
          !expectedPaths.add(expectedPath)) {
        throw DisasterRecoveryFormatException(
          'Invalid or duplicate manifest path: ${manifestEntry.archivePath}.',
        );
      }
      final bytes = entries[expectedPath];
      if (bytes == null) {
        throw DisasterRecoveryIntegrityException(
          'Archive entry is missing: $expectedPath.',
        );
      }
      final digest = hashes.sha256.convert(bytes).toString();
      if (bytes.length != manifestEntry.length ||
          digest != manifestEntry.sha256) {
        throw DisasterRecoveryIntegrityException(
          'Hash or length mismatch for: $expectedPath.',
        );
      }
      inputs.add(
        RecoveryInput(
          kind: manifestEntry.kind,
          logicalPath: manifestEntry.logicalPath,
          bytes: bytes,
        ),
      );
    }
    if (!Set<String>.from(entries.keys).containsAll(expectedPaths) ||
        entries.length != expectedPaths.length) {
      throw const DisasterRecoveryFormatException(
        'Archive contains unlisted entries.',
      );
    }
    return _prepareInputs(inputs);
  }

  static Uint8List _aad(int envelopeVersion, DisasterRecoveryKdfMetadata kdf) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': DisasterRecoveryEnvelope.format,
          'version': envelopeVersion,
          'cipher': DisasterRecoveryEnvelope.cipherName,
          'kdf': kdf.toJson(),
        }),
      ),
    );
  }

  static String _archivePath(RecoveryInput input) {
    return _archivePathFor(input.kind, input.logicalPath);
  }

  static String _archivePathFor(RecoveryDataKind kind, String logicalPath) {
    return 'data/${kind.name}/$logicalPath';
  }

  static void _validateLogicalPath(RecoveryDataKind kind, String logicalPath) {
    _validateSafeRelativePath(logicalPath);
    if (DisasterRecoveryExclusionPolicy.isReservedPath(logicalPath)) {
      throw DisasterRecoveryFormatException(
        'Reserved secure-material path: $logicalPath.',
      );
    }
    final expected = switch (kind) {
      RecoveryDataKind.journal => 'journal.json',
      RecoveryDataKind.preferences => 'preferences.json',
      RecoveryDataKind.ledger => 'ledger.json',
      RecoveryDataKind.audio => null,
    };
    if (expected != null && logicalPath != expected) {
      throw DisasterRecoveryFormatException('${kind.name} must use $expected.');
    }
  }

  static void _validateSafeRelativePath(String value) {
    final normalized = path.posix.normalize(value);
    if (value.isEmpty ||
        value.contains('\u0000') ||
        value.contains('\\') ||
        value.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(value) ||
        normalized == '.' ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        normalized != value) {
      throw DisasterRecoveryPathException(value);
    }
  }

  static void _requirePassphrase(String passphrase) {
    if (passphrase.isEmpty) {
      throw const DisasterRecoveryPassphraseException();
    }
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256), growable: false),
    );
  }
}

Uint8List _deriveArgon2id(
  String passphrase,
  List<int> salt, {
  required int iterations,
  required int memoryKiB,
  required int parallelism,
  required int keyLength,
}) {
  final generator = pc.Argon2BytesGenerator()
    ..init(
      pc.Argon2Parameters(
        pc.Argon2Parameters.ARGON2_id,
        Uint8List.fromList(salt),
        desiredKeyLength: keyLength,
        iterations: iterations,
        memory: memoryKiB,
        lanes: parallelism,
        version: pc.Argon2Parameters.ARGON2_VERSION_13,
      ),
    );
  return generator.process(Uint8List.fromList(utf8.encode(passphrase)));
}

sealed class DisasterRecoveryException implements Exception {
  const DisasterRecoveryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class DisasterRecoveryPassphraseException
    extends DisasterRecoveryException {
  const DisasterRecoveryPassphraseException()
    : super('A non-empty passphrase is required.');
}

final class DisasterRecoveryAuthenticationException
    extends DisasterRecoveryException {
  const DisasterRecoveryAuthenticationException()
    : super('The passphrase is wrong or the envelope was tampered with.');
}

final class DisasterRecoveryFormatException extends DisasterRecoveryException {
  const DisasterRecoveryFormatException(super.message);
}

final class DisasterRecoveryIntegrityException
    extends DisasterRecoveryException {
  const DisasterRecoveryIntegrityException(super.message);
}

final class DisasterRecoveryPathException extends DisasterRecoveryException {
  DisasterRecoveryPathException(String unsafePath)
    : super('Unsafe archive path: $unsafePath.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer.');
  }
  return value;
}
