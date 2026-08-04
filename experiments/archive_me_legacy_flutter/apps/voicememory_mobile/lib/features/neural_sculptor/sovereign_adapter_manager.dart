// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/graph/graph_node.dart';
import '../../services/llama_service_lifecycle.dart';
import '../../services/local_storage/encrypted_sqlite_text_codec.dart';
import '../../storage/private_data_encryption_key_store.dart';

typedef AdapterDirectoryProvider = Future<Directory> Function();
typedef AdapterOwnerAuthenticator = Future<bool> Function(String reason);
typedef ActiveBaseModelFingerprint = Future<String?> Function();
typedef AdapterBackupExcluder = Future<void> Function(String path);

final class SovereignAdapter {
  const SovereignAdapter({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.baseModelSha256,
    required this.rank,
    required this.targetModules,
    required this.finalLoss,
    required this.tokenCount,
    required this.safetensorsArtifact,
    required this.ggufArtifact,
    required this.active,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String baseModelSha256;
  final int rank;
  final List<String> targetModules;
  final double finalLoss;
  final int tokenCount;
  final String safetensorsArtifact;
  final String ggufArtifact;
  final bool active;

  SovereignAdapter copyWith({bool? active}) => SovereignAdapter(
    id: id,
    name: name,
    createdAt: createdAt,
    baseModelSha256: baseModelSha256,
    rank: rank,
    targetModules: targetModules,
    finalLoss: finalLoss,
    tokenCount: tokenCount,
    safetensorsArtifact: safetensorsArtifact,
    ggufArtifact: ggufArtifact,
    active: active ?? this.active,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'baseModelSha256': baseModelSha256,
    'rank': rank,
    'targetModules': targetModules,
    'finalLoss': finalLoss,
    'tokenCount': tokenCount,
    'safetensorsArtifact': safetensorsArtifact,
    'ggufArtifact': ggufArtifact,
    'active': active,
  };

  factory SovereignAdapter.fromJson(Map<String, dynamic> json) =>
      SovereignAdapter(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Personal adapter',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        baseModelSha256: json['baseModelSha256'] as String? ?? '',
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        targetModules: (json['targetModules'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        finalLoss: (json['finalLoss'] as num?)?.toDouble() ?? 0,
        tokenCount: (json['tokenCount'] as num?)?.toInt() ?? 0,
        safetensorsArtifact: json['safetensorsArtifact'] as String? ?? '',
        ggufArtifact: json['ggufArtifact'] as String? ?? '',
        active: json['active'] == true,
      );
}

abstract interface class AdapterRuntimeController {
  Future<void> load(String ggufPath, {double scale});
  Future<void> unload();
}

final class LlamaLifecycleAdapterRuntime implements AdapterRuntimeController {
  const LlamaLifecycleAdapterRuntime(this.lifecycle);

  final LlamaServiceLifecycle lifecycle;

  @override
  Future<void> load(String ggufPath, {double scale = 1}) async {
    final session = await lifecycle.readySession();
    if (session == null) {
      throw StateError('The local base model is not ready.');
    }
    await session.loadAdapter(ggufPath, scale: scale);
  }

  @override
  Future<void> unload() async {
    final session = await lifecycle.readySession();
    await session?.unloadAdapter();
  }
}

final class SovereignAdapterManager {
  SovereignAdapterManager._({
    required Database database,
    required EncryptedSqliteTextCodec codec,
    required this.keyStore,
    required this.adapterDirectory,
    required this.runtimeDirectory,
    required this.runtime,
    required this.activeBaseModelFingerprint,
    required this.ownerAuthenticator,
    required AdapterBackupExcluder? excludeFromBackup,
  }) : _database = database,
       _codec = codec,
       _excludeFromBackup = excludeFromBackup;

  final Database _database;
  final EncryptedSqliteTextCodec _codec;
  final PrivateDataEncryptionKeyStore keyStore;
  final Directory adapterDirectory;
  final Directory runtimeDirectory;
  final AdapterRuntimeController runtime;
  final ActiveBaseModelFingerprint activeBaseModelFingerprint;
  final AdapterOwnerAuthenticator ownerAuthenticator;
  final AdapterBackupExcluder? _excludeFromBackup;
  final AesGcm _algorithm = AesGcm.with256bits();
  bool _closed = false;

  static Future<SovereignAdapterManager> open({
    required String databasePath,
    required EncryptedSqliteTextCodec codec,
    required PrivateDataEncryptionKeyStore keyStore,
    required Directory adapterDirectory,
    required Directory runtimeDirectory,
    required AdapterRuntimeController runtime,
    required ActiveBaseModelFingerprint activeBaseModelFingerprint,
    required AdapterOwnerAuthenticator ownerAuthenticator,
    AdapterBackupExcluder? excludeFromBackup,
  }) async {
    await adapterDirectory.create(recursive: true);
    await runtimeDirectory.create(recursive: true);
    await excludeFromBackup?.call(runtimeDirectory.path);
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('''
        CREATE TABLE IF NOT EXISTS neural_adapters (
          id TEXT PRIMARY KEY,
          encrypted_metadata TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
    final manager = SovereignAdapterManager._(
      database: database,
      codec: codec,
      keyStore: keyStore,
      adapterDirectory: adapterDirectory,
      runtimeDirectory: runtimeDirectory,
      runtime: runtime,
      activeBaseModelFingerprint: activeBaseModelFingerprint,
      ownerAuthenticator: ownerAuthenticator,
      excludeFromBackup: excludeFromBackup,
    );
    await manager.cleanupRuntimeFiles();
    return manager;
  }

  List<SovereignAdapter> list() {
    _ensureOpen();
    return _database
        .select(
          'SELECT encrypted_metadata FROM neural_adapters ORDER BY created_at DESC',
        )
        .map((row) {
          final clear = _codec.decode(row['encrypted_metadata'] as String);
          return SovereignAdapter.fromJson(
            Map<String, dynamic>.from(jsonDecode(clear ?? '') as Map),
          );
        })
        .toList(growable: false);
  }

  SovereignAdapter? get active =>
      list().where((adapter) => adapter.active).firstOrNull;

  Future<SovereignAdapter> importTrained({
    required String name,
    required File safetensors,
    required File ggufAdapter,
    required String baseModelSha256,
    required int rank,
    required List<String> targetModules,
    required double finalLoss,
    required int tokenCount,
  }) async {
    _ensureOpen();
    if (!await safetensors.exists() || !await ggufAdapter.exists()) {
      throw ArgumentError('Both native trainer artifacts must exist.');
    }
    final createdAt = DateTime.now().toUtc();
    final id = stableGraphId('neural-adapter', [
      baseModelSha256,
      createdAt.toIso8601String(),
      await _fileHash(ggufAdapter),
    ]);
    final directory = Directory('${adapterDirectory.path}/$id');
    await directory.create(recursive: true);
    final safeArtifact = File('${directory.path}/adapter.safetensors.enc');
    final ggufArtifact = File('${directory.path}/adapter.gguf.enc');
    try {
      await _encryptFile(safetensors, safeArtifact);
      await _encryptFile(ggufAdapter, ggufArtifact);
      final adapter = SovereignAdapter(
        id: id,
        name: name.trim().isEmpty ? 'Personal adapter' : name.trim(),
        createdAt: createdAt,
        baseModelSha256: baseModelSha256.toLowerCase(),
        rank: rank,
        targetModules: List.unmodifiable(targetModules),
        finalLoss: finalLoss,
        tokenCount: tokenCount,
        safetensorsArtifact: safeArtifact.path,
        ggufArtifact: ggufArtifact.path,
        active: false,
      );
      _write(adapter);
      return adapter;
    } on Object {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> activate(String id, {double scale = 1}) async {
    final adapter = _required(id);
    final fingerprint = (await activeBaseModelFingerprint())?.toLowerCase();
    if (fingerprint == null || fingerprint != adapter.baseModelSha256) {
      throw StateError('Adapter does not match the installed base model.');
    }
    await unload();
    final runtimeFile = File('${runtimeDirectory.path}/active_$id.gguf');
    await _decryptFile(File(adapter.ggufArtifact), runtimeFile);
    await _excludeFromBackup?.call(runtimeFile.path);
    try {
      await runtime.load(runtimeFile.path, scale: scale);
      for (final item in list()) {
        _write(item.copyWith(active: item.id == id));
      }
    } on Object {
      await _secureDelete(runtimeFile);
      rethrow;
    }
  }

  Future<void> unload() async {
    await runtime.unload();
    for (final item in list()) {
      if (item.active) _write(item.copyWith(active: false));
    }
    await cleanupRuntimeFiles();
  }

  Future<File?> exportSafetensors(String id, File destination) async {
    final adapter = _required(id);
    if (!await ownerAuthenticator(
      'Authenticate to export your private neural adapter.',
    )) {
      return null;
    }
    await destination.parent.create(recursive: true);
    await _decryptFile(File(adapter.safetensorsArtifact), destination);
    return destination;
  }

  Future<void> cleanupExport(File exportedFile) => _secureDelete(exportedFile);

  Future<void> delete(String id) async {
    final adapter = _required(id);
    if (adapter.active) await unload();
    _database.execute('DELETE FROM neural_adapters WHERE id = ?', [id]);
    await _secureDelete(File(adapter.safetensorsArtifact));
    await _secureDelete(File(adapter.ggufArtifact));
    final parent = File(adapter.ggufArtifact).parent;
    if (await parent.exists()) await parent.delete(recursive: true);
  }

  Future<void> clear() async {
    await unload();
    _database.execute('DELETE FROM neural_adapters');
    if (await adapterDirectory.exists()) {
      await adapterDirectory.delete(recursive: true);
    }
    await adapterDirectory.create(recursive: true);
  }

  Future<void> cleanupRuntimeFiles() async {
    if (!await runtimeDirectory.exists()) return;
    await for (final entity in runtimeDirectory.list()) {
      if (entity is File) await _secureDelete(entity);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _database.close();
  }

  SovereignAdapter _required(String id) {
    for (final adapter in list()) {
      if (adapter.id == id) return adapter;
    }
    throw StateError('Adapter not found: $id');
  }

  void _write(SovereignAdapter adapter) {
    final encrypted = _codec.encode(jsonEncode(adapter.toJson()));
    _database.execute(
      'INSERT INTO neural_adapters(id, encrypted_metadata, created_at) '
      'VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
      'encrypted_metadata = excluded.encrypted_metadata',
      [adapter.id, encrypted, adapter.createdAt.millisecondsSinceEpoch],
    );
  }

  Future<void> _encryptFile(File source, File destination) async {
    final key = await _key();
    final box = await _algorithm.encrypt(
      await source.readAsBytes(),
      secretKey: SecretKey(key),
    );
    await destination.writeAsString(
      jsonEncode({
        'v': 1,
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
      flush: true,
    );
  }

  Future<void> _decryptFile(File source, File destination) async {
    final envelope = jsonDecode(await source.readAsString()) as Map;
    final clear = await _algorithm.decrypt(
      SecretBox(
        base64Decode(envelope['ciphertext'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      ),
      secretKey: SecretKey(await _key()),
    );
    await destination.writeAsBytes(clear, flush: true);
  }

  Future<List<int>> _key() async {
    final key = await keyStore.readKeyBytes();
    if (key == null || key.length != 32) {
      throw StateError('Neural adapter encryption key is unavailable.');
    }
    return key;
  }

  static Future<String> _fileHash(File file) async =>
      hashes.sha256.convert(await file.readAsBytes()).toString();

  static Future<void> _secureDelete(File file) async {
    if (!await file.exists()) return;
    try {
      final length = await file.length();
      if (length > 0) {
        await file.writeAsBytes(Uint8List(length), flush: true);
      }
    } on FileSystemException {
      // Best effort overwrite; deletion is still required.
    }
    if (await file.exists()) await file.delete();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('SovereignAdapterManager is closed.');
  }
}
