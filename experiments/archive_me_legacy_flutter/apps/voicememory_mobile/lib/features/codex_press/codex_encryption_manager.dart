import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

import '../../services/security/sync_identity_service.dart';
import '../export_backup/vault_backup_models.dart';
import 'codex_models.dart';

typedef CodexRecoveryKeyProvider = Future<SyncEncryptionKey?> Function();
typedef CodexDestroyedKeyObserver =
    void Function(String label, Uint8List destroyedBytes);

final class CodexAuthenticationException implements Exception {
  const CodexAuthenticationException();
}

final class CodexPackageException implements Exception {
  const CodexPackageException(this.message);
  final String message;
}

final class CodexEncryptionManager {
  CodexEncryptionManager({
    required this.recoveryKeyProvider,
    Random? random,
    AesGcm? aes,
    this.passwordIterations = 310000,
    this.destroyedKeyObserver,
  }) : _random = random ?? Random.secure(),
       _aes = aes ?? AesGcm.with256bits();

  static const format = 'ArchiveMe.SovereignCodex';
  static const version = 1;
  static const maximumPackageBytes = 128 * 1024 * 1024;
  static const maximumEntries = 8;

  final CodexRecoveryKeyProvider recoveryKeyProvider;
  final Random _random;
  final AesGcm _aes;
  final int passwordIterations;
  final CodexDestroyedKeyObserver? destroyedKeyObserver;

  Future<Uint8List> encrypt({
    required CodexManuscript manuscript,
    required CodexRenderedArtifacts artifacts,
    String? password,
    bool includeRecoverySlot = false,
  }) async {
    if ((password == null || password.length < 12) && !includeRecoverySlot) {
      throw const FormatException(
        'A password of at least 12 characters or recovery slot is required.',
      );
    }
    if (passwordIterations < 1000 || passwordIterations > 1000000) {
      throw const FormatException('Password KDF iteration count is invalid.');
    }
    final manuscriptBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(manuscript.toJson())),
    );
    final entries = <String, Uint8List>{
      'manuscript.json': manuscriptBytes,
      'publication.pdf': Uint8List.fromList(artifacts.pdf),
      'publication.epub': Uint8List.fromList(artifacts.epub),
      'publication.html': Uint8List.fromList(artifacts.offlineHtml),
    };
    final manifestBytes = _manifest(entries);
    entries['manifest.json'] = manifestBytes;
    final clearPayload = _zip(entries);
    if (clearPayload.length > maximumPackageBytes) {
      throw const CodexPackageException(
        'Codex payload exceeds its size limit.',
      );
    }
    final packageId = manuscript.id;
    final dek = _randomBytes(32);
    final slots = <Map<String, Object?>>[];
    try {
      if (password != null && password.length >= 12) {
        slots.add(await _passwordSlot(packageId, password, dek));
      }
      if (includeRecoverySlot) {
        final syncKey = await recoveryKeyProvider();
        if (syncKey == null) {
          throw const CodexPackageException(
            'Sanctuary recovery key is unavailable.',
          );
        }
        try {
          slots.add(await _recoverySlot(packageId, syncKey.bytes, dek));
        } finally {
          syncKey.destroy();
        }
      }
      final payloadNonce = _randomBytes(12);
      final aad = _payloadAad(
        packageId: packageId,
        createdAt: manuscript.generatedAt.toIso8601String(),
        manifestSha256: _sha256(manifestBytes),
        slots: slots,
      );
      final box = await _aes.encrypt(
        clearPayload,
        secretKey: SecretKey(dek),
        nonce: payloadNonce,
        aad: aad,
      );
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': format,
            'version': version,
            'packageId': packageId,
            'createdAt': manuscript.generatedAt.toIso8601String(),
            'cipher': 'AES-256-GCM',
            'manifestSha256': _sha256(manifestBytes),
            'slots': slots,
            'payloadNonce': base64Encode(payloadNonce),
            'payloadCiphertext': base64Encode(box.cipherText),
            'payloadTag': base64Encode(box.mac.bytes),
          }),
        ),
      );
    } finally {
      _destroyKey('payload-dek', dek);
      wipeBytes(clearPayload);
      for (final value in entries.values) {
        wipeBytes(value);
      }
    }
  }

  Future<Map<String, Uint8List>> decryptWithPassword(
    Uint8List encoded,
    String password,
  ) async {
    final envelope = _parse(encoded);
    final slot = envelope.slots
        .where((item) => item['type'] == 'password')
        .firstOrNull;
    if (slot == null) throw const CodexAuthenticationException();
    final salt = _bytes(slot, 'salt', expected: 16);
    final kek = await _passwordKek(
      password,
      salt,
      (slot['iterations'] as num).toInt(),
    );
    try {
      final dek = await _unwrap(envelope.packageId, slot, kek);
      try {
        return await _decryptPayload(envelope, dek);
      } finally {
        _destroyKey('payload-dek', dek);
      }
    } finally {
      _destroyKey('password-kek', kek);
    }
  }

  Future<Map<String, Uint8List>> decryptWithRecovery(Uint8List encoded) async {
    final envelope = _parse(encoded);
    final slot = envelope.slots
        .where((item) => item['type'] == 'recovery')
        .firstOrNull;
    final syncKey = await recoveryKeyProvider();
    if (slot == null || syncKey == null) {
      syncKey?.destroy();
      throw const CodexAuthenticationException();
    }
    final salt = _bytes(slot, 'salt', expected: 16);
    try {
      final kek = await _recoveryKek(syncKey.bytes, salt);
      try {
        final dek = await _unwrap(envelope.packageId, slot, kek);
        try {
          return await _decryptPayload(envelope, dek);
        } finally {
          _destroyKey('payload-dek', dek);
        }
      } finally {
        _destroyKey('recovery-kek', kek);
      }
    } finally {
      syncKey.destroy();
    }
  }

  Future<Map<String, Object?>> _passwordSlot(
    String packageId,
    String password,
    Uint8List dek,
  ) async {
    final salt = _randomBytes(16);
    final kek = await _passwordKek(password, salt, passwordIterations);
    try {
      return await _wrap(
        packageId: packageId,
        type: 'password',
        kdf: 'PBKDF2-HMAC-SHA256',
        iterations: passwordIterations,
        salt: salt,
        kek: kek,
        dek: dek,
      );
    } finally {
      _destroyKey('password-kek', kek);
    }
  }

  Future<Map<String, Object?>> _recoverySlot(
    String packageId,
    List<int> syncKey,
    Uint8List dek,
  ) async {
    final salt = _randomBytes(16);
    final kek = await _recoveryKek(syncKey, salt);
    try {
      return await _wrap(
        packageId: packageId,
        type: 'recovery',
        kdf: 'HKDF-SHA256',
        iterations: 0,
        salt: salt,
        kek: kek,
        dek: dek,
      );
    } finally {
      _destroyKey('recovery-kek', kek);
    }
  }

  Future<Map<String, Object?>> _wrap({
    required String packageId,
    required String type,
    required String kdf,
    required int iterations,
    required Uint8List salt,
    required Uint8List kek,
    required Uint8List dek,
  }) async {
    final nonce = _randomBytes(12);
    final box = await _aes.encrypt(
      dek,
      secretKey: SecretKey(kek),
      nonce: nonce,
      aad: _slotAad(packageId, type, kdf, iterations),
    );
    return {
      'type': type,
      'kdf': kdf,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    };
  }

  Future<Uint8List> _unwrap(
    String packageId,
    Map<String, Object?> slot,
    Uint8List kek,
  ) async {
    try {
      final clear = await _aes.decrypt(
        SecretBox(
          _bytes(slot, 'ciphertext', expected: 32),
          nonce: _bytes(slot, 'nonce', expected: 12),
          mac: Mac(_bytes(slot, 'tag', expected: 16)),
        ),
        secretKey: SecretKey(kek),
        aad: _slotAad(
          packageId,
          slot['type']! as String,
          slot['kdf']! as String,
          (slot['iterations'] as num).toInt(),
        ),
      );
      return Uint8List.fromList(clear);
    } on Object {
      throw const CodexAuthenticationException();
    }
  }

  Future<Map<String, Uint8List>> _decryptPayload(
    _CodexEnvelope envelope,
    Uint8List dek,
  ) async {
    try {
      final clear = Uint8List.fromList(
        await _aes.decrypt(
          SecretBox(
            envelope.payloadCiphertext,
            nonce: envelope.payloadNonce,
            mac: Mac(envelope.payloadTag),
          ),
          secretKey: SecretKey(dek),
          aad: _payloadAad(
            packageId: envelope.packageId,
            createdAt: envelope.createdAt,
            manifestSha256: envelope.manifestSha256,
            slots: envelope.slots,
          ),
        ),
      );
      try {
        final entries = _unzip(clear);
        final manifest = entries['manifest.json'];
        if (manifest == null || _sha256(manifest) != envelope.manifestSha256) {
          throw const CodexAuthenticationException();
        }
        _validateManifest(entries, manifest);
        return entries;
      } finally {
        wipeBytes(clear);
      }
    } on CodexAuthenticationException {
      rethrow;
    } on Object {
      throw const CodexAuthenticationException();
    }
  }

  Future<Uint8List> _passwordKek(
    String password,
    List<int> salt,
    int iterations,
  ) async {
    if (iterations < 1000 || iterations > 1000000) {
      throw const CodexAuthenticationException();
    }
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }

  Future<Uint8List> _recoveryKek(List<int> syncKey, List<int> salt) async {
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(syncKey),
      nonce: salt,
      info: utf8.encode('ArchiveMe.SovereignCodex.RecoveryWrap.v1'),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  _CodexEnvelope _parse(Uint8List bytes) {
    if (bytes.length > maximumPackageBytes * 2) {
      throw const CodexPackageException('Codex envelope is too large.');
    }
    try {
      final raw = jsonDecode(utf8.decode(bytes));
      if (raw is! Map) throw const FormatException();
      final json = Map<String, Object?>.from(raw);
      const keys = {
        'format',
        'version',
        'packageId',
        'createdAt',
        'cipher',
        'manifestSha256',
        'slots',
        'payloadNonce',
        'payloadCiphertext',
        'payloadTag',
      };
      if (json.keys.toSet().length != keys.length ||
          !json.keys.toSet().containsAll(keys) ||
          json['format'] != format ||
          json['version'] != version ||
          json['cipher'] != 'AES-256-GCM' ||
          json['packageId'] is! String ||
          json['createdAt'] is! String ||
          json['manifestSha256'] is! String ||
          !RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch(json['manifestSha256']! as String) ||
          json['slots'] is! List) {
        throw const FormatException();
      }
      final slots = (json['slots']! as List).map((item) {
        if (item is! Map) throw const FormatException();
        final slot = Map<String, Object?>.from(item);
        const slotKeys = {
          'type',
          'kdf',
          'iterations',
          'salt',
          'nonce',
          'ciphertext',
          'tag',
        };
        if (slot.keys.toSet().length != slotKeys.length ||
            !slot.keys.toSet().containsAll(slotKeys) ||
            !const {'password', 'recovery'}.contains(slot['type']) ||
            slot['kdf'] is! String ||
            slot['iterations'] is! num) {
          throw const FormatException();
        }
        _bytes(slot, 'salt', expected: 16);
        _bytes(slot, 'nonce', expected: 12);
        _bytes(slot, 'ciphertext', expected: 32);
        _bytes(slot, 'tag', expected: 16);
        return slot;
      }).toList();
      if (slots.isEmpty || slots.length > 2) throw const FormatException();
      return _CodexEnvelope(
        packageId: json['packageId']! as String,
        createdAt: DateTime.parse(
          json['createdAt']! as String,
        ).toUtc().toIso8601String(),
        manifestSha256: json['manifestSha256']! as String,
        slots: slots,
        payloadNonce: _bytes(json, 'payloadNonce', expected: 12),
        payloadCiphertext: _bytes(json, 'payloadCiphertext'),
        payloadTag: _bytes(json, 'payloadTag', expected: 16),
      );
    } on Object {
      throw const CodexAuthenticationException();
    }
  }

  Uint8List _manifest(Map<String, Uint8List> entries) => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'entries': [
          for (final entry in entries.entries)
            {
              'path': entry.key,
              'size': entry.value.length,
              'sha256': _sha256(entry.value),
            },
        ],
      }),
    ),
  );

  void _validateManifest(
    Map<String, Uint8List> entries,
    Uint8List manifestBytes,
  ) {
    final raw = jsonDecode(utf8.decode(manifestBytes));
    if (raw is! Map || raw['schemaVersion'] != 1 || raw['entries'] is! List) {
      throw const CodexAuthenticationException();
    }
    final manifestEntries = raw['entries']! as List;
    if (manifestEntries.length != entries.length - 1) {
      throw const CodexAuthenticationException();
    }
    for (final rawEntry in manifestEntries) {
      if (rawEntry is! Map ||
          rawEntry['path'] is! String ||
          rawEntry['size'] is! num ||
          rawEntry['sha256'] is! String) {
        throw const CodexAuthenticationException();
      }
      final path = rawEntry['path']! as String;
      _validatePath(path);
      final content = entries[path];
      if (content == null ||
          content.length != (rawEntry['size'] as num).toInt() ||
          _sha256(content) != rawEntry['sha256']) {
        throw const CodexAuthenticationException();
      }
    }
  }

  Uint8List _zip(Map<String, Uint8List> entries) {
    final archive = Archive();
    for (final entry in entries.entries) {
      _validatePath(entry.key);
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Map<String, Uint8List> _unzip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.files.length > maximumEntries) {
      throw const CodexAuthenticationException();
    }
    var total = 0;
    final result = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      _validatePath(file.name);
      total += file.size;
      if (total > maximumPackageBytes || result.containsKey(file.name)) {
        throw const CodexAuthenticationException();
      }
      result[file.name] = Uint8List.fromList(file.content as List<int>);
    }
    if (result.keys.toSet().difference(const {
          'manuscript.json',
          'publication.pdf',
          'publication.epub',
          'publication.html',
          'manifest.json',
        }).isNotEmpty ||
        result.length != 5) {
      throw const CodexAuthenticationException();
    }
    return result;
  }

  Uint8List _payloadAad({
    required String packageId,
    required String createdAt,
    required String manifestSha256,
    required List<Map<String, Object?>> slots,
  }) => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': format,
        'version': version,
        'packageId': packageId,
        'createdAt': createdAt,
        'cipher': 'AES-256-GCM',
        'manifestSha256': manifestSha256,
        'slots': slots,
      }),
    ),
  );

  Uint8List _slotAad(
    String packageId,
    String type,
    String kdf,
    int iterations,
  ) => Uint8List.fromList(
    utf8.encode('$format|$version|$packageId|$type|$kdf|$iterations'),
  );

  Uint8List _randomBytes(int length) => Uint8List.fromList(
    List.generate(length, (_) => _random.nextInt(256), growable: false),
  );

  static Uint8List _bytes(
    Map<String, Object?> json,
    String field, {
    int? expected,
  }) {
    final value = json[field];
    if (value is! String) throw const FormatException();
    final result = Uint8List.fromList(base64Decode(value));
    if (expected != null && result.length != expected) {
      throw const FormatException();
    }
    return result;
  }

  static void _validatePath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.split('/').contains('..')) {
      throw const CodexAuthenticationException();
    }
  }

  static String _sha256(List<int> bytes) =>
      hashes.sha256.convert(bytes).toString();

  void _destroyKey(String label, Uint8List bytes) {
    wipeBytes(bytes);
    destroyedKeyObserver?.call(label, bytes);
  }
}

final class _CodexEnvelope {
  const _CodexEnvelope({
    required this.packageId,
    required this.createdAt,
    required this.manifestSha256,
    required this.slots,
    required this.payloadNonce,
    required this.payloadCiphertext,
    required this.payloadTag,
  });

  final String packageId;
  final String createdAt;
  final String manifestSha256;
  final List<Map<String, Object?>> slots;
  final Uint8List payloadNonce;
  final Uint8List payloadCiphertext;
  final Uint8List payloadTag;
}
