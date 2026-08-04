import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../storage/secure_storage.dart';
import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import '../graph/personal_knowledge_graph_store.dart';

enum EncryptedGraphSyncMode { portable, deviceBound }

enum EncryptedGraphSyncTarget { iCloudDrive, googleDrive }

class EncryptedGraphSyncException implements Exception {
  const EncryptedGraphSyncException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class EncryptedGraphSyncFormatException extends EncryptedGraphSyncException {
  const EncryptedGraphSyncFormatException(super.message);
}

class EncryptedGraphSyncIntegrityException extends EncryptedGraphSyncException {
  const EncryptedGraphSyncIntegrityException()
    : super('Encrypted graph authentication failed.');
}

/// Authentication failures can mean that the supplied key source is wrong.
///
/// It extends [EncryptedGraphSyncIntegrityException] because AES-GCM
/// intentionally cannot distinguish a wrong key from modified authenticated
/// data without weakening the envelope.
class EncryptedGraphSyncKeyException
    extends EncryptedGraphSyncIntegrityException {
  const EncryptedGraphSyncKeyException();
}

class EncryptedGraphSyncTransportException extends EncryptedGraphSyncException {
  const EncryptedGraphSyncTransportException(super.message);
}

/// Version 1 uses PBKDF2-HMAC-SHA256 with 210,000 iterations, a random
/// 16-byte salt, and AES-256-GCM with a random 12-byte nonce and 128-bit MAC.
class EncryptedGraphSyncEnvelope {
  const EncryptedGraphSyncEnvelope({
    required this.version,
    required this.algorithm,
    required this.kdf,
    required this.mode,
    required this.salt,
    required this.iterations,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  static const fields = <String>{
    'version',
    'algorithm',
    'kdf',
    'mode',
    'salt',
    'iterations',
    'nonce',
    'ciphertext',
    'mac',
  };

  final int version;
  final String algorithm;
  final String kdf;
  final EncryptedGraphSyncMode mode;
  final String salt;
  final int iterations;
  final String nonce;
  final String ciphertext;
  final String mac;

  Map<String, dynamic> toJson() => {
    'version': version,
    'algorithm': algorithm,
    'kdf': kdf,
    'mode': mode.name,
    'salt': salt,
    'iterations': iterations,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };

  String encode() => jsonEncode(toJson());

  factory EncryptedGraphSyncEnvelope.decode(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! Map) {
        throw const EncryptedGraphSyncFormatException(
          'Encrypted graph envelope must be a JSON object.',
        );
      }
      return EncryptedGraphSyncEnvelope.fromJson(
        Map<String, dynamic>.from(value),
      );
    } on EncryptedGraphSyncFormatException {
      rethrow;
    } on Object {
      throw const EncryptedGraphSyncFormatException(
        'Encrypted graph envelope is malformed.',
      );
    }
  }

  factory EncryptedGraphSyncEnvelope.fromJson(Map<String, dynamic> json) {
    if (json.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(json.keys.toSet()).isNotEmpty) {
      throw const EncryptedGraphSyncFormatException(
        'Encrypted graph envelope fields are invalid.',
      );
    }
    final version = json['version'];
    final algorithm = json['algorithm'];
    final kdf = json['kdf'];
    final modeName = json['mode'];
    final iterations = json['iterations'];
    if (version is! int ||
        algorithm is! String ||
        kdf is! String ||
        modeName is! String ||
        iterations is! int ||
        json['salt'] is! String ||
        json['nonce'] is! String ||
        json['ciphertext'] is! String ||
        json['mac'] is! String) {
      throw const EncryptedGraphSyncFormatException(
        'Encrypted graph envelope field types are invalid.',
      );
    }
    final mode = EncryptedGraphSyncMode.values
        .where((item) => item.name == modeName)
        .firstOrNull;
    if (version != EncryptedGraphSyncEngine.envelopeVersion ||
        algorithm != EncryptedGraphSyncEngine.algorithmName ||
        kdf != EncryptedGraphSyncEngine.kdfName ||
        mode == null ||
        iterations != EncryptedGraphSyncEngine.pbkdf2Iterations) {
      throw const EncryptedGraphSyncFormatException(
        'Encrypted graph envelope parameters are unsupported.',
      );
    }
    _decodeField(json['salt'] as String, 'salt', expectedLength: 16);
    _decodeField(json['nonce'] as String, 'nonce', expectedLength: 12);
    _decodeField(json['mac'] as String, 'mac', expectedLength: 16);
    _decodeField(json['ciphertext'] as String, 'ciphertext', allowEmpty: false);
    return EncryptedGraphSyncEnvelope(
      version: version,
      algorithm: algorithm,
      kdf: kdf,
      mode: mode,
      salt: json['salt'] as String,
      iterations: iterations,
      nonce: json['nonce'] as String,
      ciphertext: json['ciphertext'] as String,
      mac: json['mac'] as String,
    );
  }

  static List<int> _decodeField(
    String value,
    String name, {
    int? expectedLength,
    bool allowEmpty = true,
  }) {
    try {
      final bytes = base64Decode(value);
      if ((expectedLength != null && bytes.length != expectedLength) ||
          (!allowEmpty && bytes.isEmpty) ||
          base64Encode(bytes) != value) {
        throw const FormatException();
      }
      return bytes;
    } on Object {
      throw EncryptedGraphSyncFormatException(
        'Encrypted graph envelope $name is invalid.',
      );
    }
  }
}

abstract interface class SyncSeedStore {
  Future<List<int>?> readSeed();

  Future<void> writeSeed(List<int> seed);

  Future<void> deleteSeed();
}

/// Stores only the dedicated graph-sync seed under a distinct secure-storage
/// alias. It never reads the app-lock PIN hash or journal encryption key.
class SecureGraphSyncSeedStore implements SyncSeedStore {
  SecureGraphSyncSeedStore({SecureStorageService? secureStorage})
    : _secureStorage = secureStorage ?? SecureStorageService();

  static const storageAlias = 'archive_graph_sync_material_v1';
  static const seedLength = 32;

  final SecureStorageService _secureStorage;

  @override
  Future<List<int>?> readSeed() async {
    final encoded = await _secureStorage.read(storageAlias);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final seed = base64Decode(encoded);
      return seed.length == seedLength ? seed : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> writeSeed(List<int> seed) {
    if (seed.length != seedLength) {
      throw ArgumentError.value(seed.length, 'seed.length', 'expected 32');
    }
    return _secureStorage.write(storageAlias, base64Encode(seed));
  }

  @override
  Future<void> deleteSeed() => _secureStorage.delete(storageAlias);
}

class InMemorySyncSeedStore implements SyncSeedStore {
  InMemorySyncSeedStore({List<int>? seed})
    : _seed = seed == null ? null : List<int>.from(seed);

  List<int>? _seed;

  @override
  Future<List<int>?> readSeed() async =>
      _seed == null ? null : List<int>.from(_seed!);

  @override
  Future<void> writeSeed(List<int> seed) async {
    if (seed.length != SecureGraphSyncSeedStore.seedLength) {
      throw ArgumentError.value(seed.length, 'seed.length', 'expected 32');
    }
    _seed = List<int>.from(seed);
  }

  @override
  Future<void> deleteSeed() async => _seed = null;
}

abstract interface class EncryptedGraphSyncTransport {
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  });

  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  });
}

/// Safe production default while iCloud entitlements and Google OAuth are not
/// configured. It never reports a successful upload.
class UnavailableEncryptedGraphSyncTransport
    implements EncryptedGraphSyncTransport {
  const UnavailableEncryptedGraphSyncTransport();

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) => throw const EncryptedGraphSyncTransportException(
    'Cloud graph sync is unavailable until its platform integration is configured.',
  );

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) => throw const EncryptedGraphSyncTransportException(
    'Cloud graph sync is unavailable until its platform integration is configured.',
  );
}

/// Explicit, foreground-only transport for a directory selected by the user.
///
/// The selected directory may itself be exposed by Files or a drive provider;
/// this class makes no cloud-upload or background-sync claim.
class ManualLocalFileEncryptedGraphSyncTransport
    implements EncryptedGraphSyncTransport {
  ManualLocalFileEncryptedGraphSyncTransport(this.selectedDirectory);

  final Directory selectedDirectory;

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) => _fileFor(path).readAsString();

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) async {
    final file = _fileFor(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(encryptedEnvelope, flush: true);
  }

  File _fileFor(String relativePath) {
    final segments = relativePath.split('/');
    if (segments.isEmpty ||
        segments.any(
          (segment) =>
              segment.isEmpty ||
              segment == '.' ||
              segment == '..' ||
              segment.contains('\\'),
        ) ||
        relativePath.startsWith('/')) {
      throw const EncryptedGraphSyncTransportException(
        'Manual sync path must be a safe relative path.',
      );
    }
    return File(
      '${selectedDirectory.path}${Platform.pathSeparator}'
      '${segments.join(Platform.pathSeparator)}',
    );
  }
}

class EncryptedGraphSyncEngine {
  EncryptedGraphSyncEngine({
    this.seedStore,
    EncryptedGraphSyncTransport? transport,
    Random? random,
    AesGcm? aesGcm,
  }) : _transport = transport ?? const UnavailableEncryptedGraphSyncTransport(),
       _random = random ?? Random.secure(),
       _aesGcm = aesGcm ?? AesGcm.with256bits();

  static const envelopeVersion = 1;
  static const algorithmName = 'AES-256-GCM';
  static const kdfName = 'PBKDF2-HMAC-SHA256';
  static const pbkdf2Iterations = 210000;
  static const _formatName = 'ArchiveMe.EncryptedPersonalKnowledgeGraph';

  final SyncSeedStore? seedStore;
  final EncryptedGraphSyncTransport _transport;
  final Random _random;
  final AesGcm _aesGcm;

  Future<EncryptedGraphSyncEnvelope> encryptWithPassphrase(
    PersonalKnowledgeGraph graph,
    String passphrase,
  ) {
    if (passphrase.isEmpty) {
      throw const EncryptedGraphSyncKeyException();
    }
    return _encrypt(
      graph,
      mode: EncryptedGraphSyncMode.portable,
      keyMaterial: utf8.encode(passphrase),
    );
  }

  Future<EncryptedGraphSyncEnvelope> encryptWithDeviceSeed(
    PersonalKnowledgeGraph graph,
  ) async => _encrypt(
    graph,
    mode: EncryptedGraphSyncMode.deviceBound,
    keyMaterial: await _deviceSeed(create: true),
  );

  Future<PersonalKnowledgeGraph> decrypt(
    EncryptedGraphSyncEnvelope envelope, {
    String? passphrase,
  }) async {
    final validated = EncryptedGraphSyncEnvelope.fromJson(envelope.toJson());
    final keyMaterial = switch (validated.mode) {
      EncryptedGraphSyncMode.portable when passphrase?.isNotEmpty == true =>
        utf8.encode(passphrase!),
      EncryptedGraphSyncMode.portable =>
        throw const EncryptedGraphSyncKeyException(),
      EncryptedGraphSyncMode.deviceBound => await _deviceSeed(create: false),
    };
    final key = await _deriveKey(
      keyMaterial,
      base64Decode(validated.salt),
      validated.iterations,
    );
    late final List<int> clearBytes;
    try {
      clearBytes = await _aesGcm.decrypt(
        SecretBox(
          base64Decode(validated.ciphertext),
          nonce: base64Decode(validated.nonce),
          mac: Mac(base64Decode(validated.mac)),
        ),
        secretKey: key,
        aad: _aad(validated.mode),
      );
    } on SecretBoxAuthenticationError {
      throw const EncryptedGraphSyncKeyException();
    } on Object {
      throw const EncryptedGraphSyncIntegrityException();
    }
    try {
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! Map) {
        throw const FormatException();
      }
      final json = Map<String, dynamic>.from(decoded);
      _validateGraphJson(json);
      return PersonalKnowledgeGraph.fromJson(json);
    } on Object {
      throw const EncryptedGraphSyncFormatException(
        'Decrypted graph schema is invalid.',
      );
    }
  }

  Future<EncryptedGraphSyncEnvelope> _encrypt(
    PersonalKnowledgeGraph graph, {
    required EncryptedGraphSyncMode mode,
    required List<int> keyMaterial,
  }) async {
    _validateGraphJson(graph.toJson());
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(keyMaterial, salt, pbkdf2Iterations);
    final box = await _aesGcm.encrypt(
      utf8.encode(jsonEncode(graph.toJson())),
      secretKey: key,
      nonce: nonce,
      aad: _aad(mode),
    );
    return EncryptedGraphSyncEnvelope(
      version: envelopeVersion,
      algorithm: algorithmName,
      kdf: kdfName,
      mode: mode,
      salt: base64Encode(salt),
      iterations: pbkdf2Iterations,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(box.cipherText),
      mac: base64Encode(box.mac.bytes),
    );
  }

  Future<SecretKey> _deriveKey(
    List<int> keyMaterial,
    List<int> salt,
    int iterations,
  ) => Pbkdf2.hmacSha256(
    iterations: iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(keyMaterial), nonce: salt);

  Future<List<int>> _deviceSeed({required bool create}) async {
    final store = seedStore;
    if (store == null) throw const EncryptedGraphSyncKeyException();
    final existing = await store.readSeed();
    if (existing != null &&
        existing.length == SecureGraphSyncSeedStore.seedLength) {
      return existing;
    }
    if (!create) throw const EncryptedGraphSyncKeyException();
    final seed = _randomBytes(SecureGraphSyncSeedStore.seedLength);
    await store.writeSeed(seed);
    return seed;
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256), growable: false);

  static List<int> _aad(EncryptedGraphSyncMode mode) =>
      utf8.encode('$_formatName|$envelopeVersion|${mode.name}');

  static String suggestedPath(
    EncryptedGraphSyncTarget target,
    String filename,
  ) {
    if (filename.isEmpty ||
        filename.contains('/') ||
        filename.contains('\\') ||
        filename == '.' ||
        filename == '..') {
      throw const EncryptedGraphSyncFormatException(
        'Sync filename is invalid.',
      );
    }
    return switch (target) {
      EncryptedGraphSyncTarget.iCloudDrive =>
        'Documents/ArchiveMe_Sync/$filename',
      EncryptedGraphSyncTarget.googleDrive => 'ArchiveMe_Sync/$filename',
    };
  }

  Future<EncryptedGraphSyncEnvelope> exportWithPassphrase({
    required PersonalKnowledgeGraph graph,
    required EncryptedGraphSyncTarget target,
    required String filename,
    required String passphrase,
  }) async {
    final envelope = await encryptWithPassphrase(graph, passphrase);
    await _transport.upload(
      target: target,
      path: suggestedPath(target, filename),
      encryptedEnvelope: envelope.encode(),
    );
    return envelope;
  }

  Future<EncryptedGraphSyncEnvelope> exportWithDeviceSeed({
    required PersonalKnowledgeGraph graph,
    required EncryptedGraphSyncTarget target,
    required String filename,
  }) async {
    final envelope = await encryptWithDeviceSeed(graph);
    await _transport.upload(
      target: target,
      path: suggestedPath(target, filename),
      encryptedEnvelope: envelope.encode(),
    );
    return envelope;
  }

  Future<PersonalKnowledgeGraph> importWithPassphrase({
    required EncryptedGraphSyncTarget target,
    required String filename,
    required String passphrase,
  }) async {
    final encoded = await _transport.download(
      target: target,
      path: suggestedPath(target, filename),
    );
    return decrypt(
      EncryptedGraphSyncEnvelope.decode(encoded),
      passphrase: passphrase,
    );
  }

  Future<PersonalKnowledgeGraph> importWithDeviceSeed({
    required EncryptedGraphSyncTarget target,
    required String filename,
  }) async {
    final encoded = await _transport.download(
      target: target,
      path: suggestedPath(target, filename),
    );
    return decrypt(EncryptedGraphSyncEnvelope.decode(encoded));
  }

  Future<PersonalKnowledgeGraph> restoreWithPassphrase({
    required PersonalKnowledgeGraphStore store,
    required EncryptedGraphSyncTarget target,
    required String filename,
    required String passphrase,
  }) async {
    final graph = await importWithPassphrase(
      target: target,
      filename: filename,
      passphrase: passphrase,
    );
    await store.save(graph);
    return graph;
  }

  Future<PersonalKnowledgeGraph> restoreWithDeviceSeed({
    required PersonalKnowledgeGraphStore store,
    required EncryptedGraphSyncTarget target,
    required String filename,
  }) async {
    final graph = await importWithDeviceSeed(
      target: target,
      filename: filename,
    );
    await store.save(graph);
    return graph;
  }

  static void _validateGraphJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    final expectedTopLevel = version == 1
        ? const {'schemaVersion', 'nodes', 'edges'}
        : const {
            'schemaVersion',
            'nodes',
            'edges',
            'trajectories',
            'materialization',
          };
    if ((version != 1 && version != 2) ||
        !_hasExactKeys(json, expectedTopLevel) ||
        json['nodes'] is! List ||
        json['edges'] is! List ||
        (version == 2 &&
            (json['trajectories'] is! List ||
                json['materialization'] is! Map))) {
      throw const EncryptedGraphSyncFormatException(
        'Personal knowledge graph schema is invalid.',
      );
    }
    final nodeIds = <String>{};
    for (final value in json['nodes'] as List) {
      if (value is! Map) {
        throw const EncryptedGraphSyncFormatException(
          'Personal knowledge graph node is invalid.',
        );
      }
      final node = Map<String, dynamic>.from(value);
      if (!_hasExactKeys(node, const {
            'id',
            'type',
            'label',
            'confidence',
            'evidence',
          }) ||
          node['id'] is! String ||
          (node['id'] as String).isEmpty ||
          !NodeType.values.any((item) => item.name == node['type']) ||
          node['label'] is! String ||
          (node['label'] as String).trim().isEmpty ||
          node['confidence'] is! num ||
          node['evidence'] is! List ||
          (node['evidence'] as List).isEmpty ||
          !nodeIds.add(node['id'] as String)) {
        throw const EncryptedGraphSyncFormatException(
          'Personal knowledge graph node is invalid.',
        );
      }
      _validateEvidence(node['evidence'] as List, requireOffsets: version == 2);
    }
    for (final value in json['edges'] as List) {
      if (value is! Map) {
        throw const EncryptedGraphSyncFormatException(
          'Personal knowledge graph edge is invalid.',
        );
      }
      final edge = Map<String, dynamic>.from(value);
      if (!_hasExactKeys(edge, const {
            'id',
            'sourceNodeId',
            'targetNodeId',
            'type',
            'isDirected',
            'weight',
            'evidence',
          }) ||
          edge['id'] is! String ||
          (edge['id'] as String).isEmpty ||
          !nodeIds.contains(edge['sourceNodeId']) ||
          !nodeIds.contains(edge['targetNodeId']) ||
          !EdgeType.values.any((item) => item.name == edge['type']) ||
          edge['isDirected'] is! bool ||
          edge['weight'] is! num ||
          edge['evidence'] is! List ||
          (edge['evidence'] as List).isEmpty) {
        throw const EncryptedGraphSyncFormatException(
          'Personal knowledge graph edge is invalid.',
        );
      }
      _validateEvidence(edge['evidence'] as List, requireOffsets: version == 2);
    }
    if (version == 2) {
      _validateTrajectories(json['trajectories'] as List, nodeIds);
      _validateMaterialization(
        Map<String, dynamic>.from(json['materialization'] as Map),
      );
    }
  }

  static void _validateEvidence(
    List<dynamic> values, {
    required bool requireOffsets,
  }) {
    for (final value in values) {
      if (value is! Map) {
        throw const EncryptedGraphSyncFormatException(
          'Personal knowledge graph evidence is invalid.',
        );
      }
      final evidence = Map<String, dynamic>.from(value);
      final expected = requireOffsets
          ? const {
              'entryId',
              'observedAt',
              'confidence',
              'excerpt',
              'startUtf16',
              'endUtf16',
            }
          : const {'entryId', 'observedAt', 'confidence', 'excerpt'};
      if ((!_hasExactKeys(evidence, expected) &&
              !(requireOffsets == false &&
                  _hasExactKeys(evidence, const {
                    'entryId',
                    'observedAt',
                    'confidence',
                    'excerpt',
                    'startUtf16',
                    'endUtf16',
                  }))) ||
          evidence['entryId'] is! String ||
          (evidence['entryId'] as String).isEmpty ||
          evidence['observedAt'] is! String ||
          DateTime.tryParse(evidence['observedAt'] as String) == null ||
          evidence['confidence'] is! num ||
          evidence['excerpt'] is! String ||
          (requireOffsets &&
              (evidence['startUtf16'] is! int ||
                  evidence['endUtf16'] is! int ||
                  evidence['startUtf16'] < 0 ||
                  evidence['endUtf16'] <= evidence['startUtf16'] ||
                  evidence['endUtf16'] - evidence['startUtf16'] !=
                      (evidence['excerpt'] as String).length))) {
        throw const EncryptedGraphSyncFormatException(
          'Personal knowledge graph evidence is invalid.',
        );
      }
    }
  }

  static void _validateTrajectories(List<dynamic> values, Set<String> nodeIds) {
    for (final value in values) {
      if (value is! Map) {
        throw const EncryptedGraphSyncFormatException(
          'Personal knowledge graph trajectory is invalid.',
        );
      }
      final trajectory = Map<String, dynamic>.from(value);
      if (!_hasExactKeys(trajectory, const {
            'id',
            'type',
            'subjectNodeId',
            'relatedNodeId',
            'windows',
          }) ||
          trajectory['id'] is! String ||
          !GraphTrajectoryType.values.any(
            (item) => item.name == trajectory['type'],
          ) ||
          !nodeIds.contains(trajectory['subjectNodeId']) ||
          (trajectory['relatedNodeId'] != null &&
              !nodeIds.contains(trajectory['relatedNodeId'])) ||
          trajectory['windows'] is! List) {
        throw const EncryptedGraphSyncFormatException(
          'Personal knowledge graph trajectory is invalid.',
        );
      }
      for (final rawWindow in trajectory['windows'] as List) {
        if (rawWindow is! Map) {
          throw const EncryptedGraphSyncFormatException(
            'Personal knowledge graph trajectory window is invalid.',
          );
        }
        final window = Map<String, dynamic>.from(rawWindow);
        if (!_hasExactKeys(window, const {
              'id',
              'start',
              'end',
              'value',
              'label',
              'evidence',
            }) ||
            window['id'] is! String ||
            DateTime.tryParse(window['start'] as String? ?? '') == null ||
            DateTime.tryParse(window['end'] as String? ?? '') == null ||
            window['value'] is! num ||
            window['label'] is! String ||
            window['evidence'] is! List ||
            (window['evidence'] as List).isEmpty) {
          throw const EncryptedGraphSyncFormatException(
            'Personal knowledge graph trajectory window is invalid.',
          );
        }
        _validateEvidence(window['evidence'] as List, requireOffsets: true);
      }
    }
  }

  static void _validateMaterialization(Map<String, dynamic> value) {
    if (!_hasExactKeys(value, const {
          'processedEntryRevisions',
          'extractorVersion',
          'governanceVersion',
          'governanceHash',
          'materializedAt',
        }) ||
        value['processedEntryRevisions'] is! Map ||
        value['extractorVersion'] is! String ||
        value['governanceVersion'] is! String ||
        value['governanceHash'] is! String ||
        (value['materializedAt'] != null &&
            DateTime.tryParse(value['materializedAt'] as String? ?? '') ==
                null)) {
      throw const EncryptedGraphSyncFormatException(
        'Personal knowledge graph materialization metadata is invalid.',
      );
    }
  }

  static bool _hasExactKeys(Map<String, dynamic> value, Set<String> expected) =>
      value.keys.toSet().length == expected.length &&
      value.keys.toSet().containsAll(expected);
}
