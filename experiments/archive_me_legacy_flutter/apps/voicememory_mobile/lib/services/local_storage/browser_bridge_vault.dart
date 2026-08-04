import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../features/browser_extension_bridge/browser_bridge_models.dart';
import '../../storage/private_data_encryption_key_store.dart';

/// AES-256-GCM field-encrypted SQLite vault for extension trust and web clips.
final class BrowserBridgeVault {
  BrowserBridgeVault._(this._database, this.databasePath, this._keyStore);

  final Database _database;
  final String databasePath;
  final PrivateDataEncryptionKeyStore _keyStore;
  final AesGcm _aes = AesGcm.with256bits();
  bool _closed = false;

  static BrowserBridgeVault open({
    required String databasePath,
    required PrivateDataEncryptionKeyStore keyStore,
  }) {
    Directory(databasePath).parent.createSync(recursive: true);
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('PRAGMA secure_delete = ON')
      ..execute('PRAGMA busy_timeout = 3000')
      ..execute('''
        CREATE TABLE IF NOT EXISTS browser_extensions (
          id TEXT PRIMARY KEY,
          payload BLOB NOT NULL,
          nonce BLOB NOT NULL,
          mac BLOB NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS browser_clips (
          id TEXT PRIMARY KEY,
          extension_id TEXT NOT NULL,
          payload BLOB NOT NULL,
          nonce BLOB NOT NULL,
          mac BLOB NOT NULL,
          captured_at INTEGER NOT NULL
        )
      ''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS browser_clips_extension '
        'ON browser_clips(extension_id, captured_at DESC)',
      );
    return BrowserBridgeVault._(database, databasePath, keyStore);
  }

  Future<List<TrustedBrowserExtension>> extensions() async {
    _ensureOpen();
    final result = <TrustedBrowserExtension>[];
    for (final row in _database.select(
      'SELECT id, payload, nonce, mac FROM browser_extensions '
      'ORDER BY updated_at DESC',
    )) {
      final json = await _decrypt('extension', row);
      result.add(TrustedBrowserExtension.fromJson(json));
    }
    return List.unmodifiable(result);
  }

  Future<TrustedBrowserExtension?> extension(String id) async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT id, payload, nonce, mac FROM browser_extensions WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return TrustedBrowserExtension.fromJson(
      await _decrypt('extension', rows.single),
    );
  }

  Future<void> trust(TrustedBrowserExtension extension) async {
    final encrypted = await _encrypt(
      'extension',
      extension.id,
      extension.toJson(),
    );
    _database.execute(
      'INSERT OR REPLACE INTO browser_extensions'
      '(id, payload, nonce, mac, updated_at) VALUES (?, ?, ?, ?, ?)',
      [
        extension.id,
        encrypted.cipherText,
        encrypted.nonce,
        encrypted.mac,
        extension.lastSeenAt.millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> revoke(String id) async {
    _ensureOpen();
    _database.execute('DELETE FROM browser_extensions WHERE id = ?', [id]);
  }

  Future<void> recordClip(BrowserClipRecord record) async {
    final encrypted = await _encrypt('clip', record.id, {
      'id': record.id,
      'extensionId': record.extensionId,
      'payload': record.payload.toJson(),
      'chunkCount': record.chunkCount,
      'clusterIds': record.clusterIds,
    });
    _database.execute('BEGIN IMMEDIATE');
    try {
      _database.execute(
        'INSERT INTO browser_clips'
        '(id, extension_id, payload, nonce, mac, captured_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          record.id,
          record.extensionId,
          encrypted.cipherText,
          encrypted.nonce,
          encrypted.mac,
          record.payload.capturedAt.millisecondsSinceEpoch,
        ],
      );
      final extension = await this.extension(record.extensionId);
      if (extension != null) {
        await trust(
          extension.copyWith(
            clipCount: extension.clipCount + 1,
            lastSeenAt: DateTime.now(),
          ),
        );
      }
      _database.execute('COMMIT');
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<BrowserClipRecord?> clip(String id) async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT id, payload, nonce, mac FROM browser_clips WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final json = await _decrypt('clip', rows.single);
    return BrowserClipRecord(
      id: json['id'] as String,
      extensionId: json['extensionId'] as String,
      payload: WebClipPayload.fromJson(
        Map<String, dynamic>.from(json['payload'] as Map),
      ),
      chunkCount: (json['chunkCount'] as num).toInt(),
      clusterIds: (json['clusterIds'] as List).whereType<String>().toList(),
    );
  }

  int get clipCount {
    _ensureOpen();
    return _database
            .select('SELECT COUNT(*) AS count FROM browser_clips')
            .single['count']
        as int;
  }

  Future<void> clear() async {
    _ensureOpen();
    _database.execute('DELETE FROM browser_clips');
    _database.execute('DELETE FROM browser_extensions');
  }

  Future<_EncryptedRow> _encrypt(
    String table,
    String id,
    Map<String, Object?> json,
  ) async {
    _ensureOpen();
    final clear = Uint8List.fromList(utf8.encode(jsonEncode(json)));
    try {
      final box = await _aes.encrypt(
        clear,
        secretKey: SecretKey(await _keyBytes()),
        aad: utf8.encode('browser-bridge-v1|$table|$id'),
      );
      return _EncryptedRow(
        Uint8List.fromList(box.cipherText),
        Uint8List.fromList(box.nonce),
        Uint8List.fromList(box.mac.bytes),
      );
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }

  Future<Map<String, dynamic>> _decrypt(String table, Row row) async {
    final id = row['id'] as String;
    final clear = await _aes.decrypt(
      SecretBox(
        row['payload'] as Uint8List,
        nonce: row['nonce'] as Uint8List,
        mac: Mac(row['mac'] as Uint8List),
      ),
      secretKey: SecretKey(await _keyBytes()),
      aad: utf8.encode('browser-bridge-v1|$table|$id'),
    );
    try {
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }

  Future<List<int>> _keyBytes() async {
    final existing = await _keyStore.readKeyBytes();
    if (existing != null && existing.length == 32) return existing;
    final key = await (await _aes.newSecretKey()).extractBytes();
    await _keyStore.writeKeyBytes(key);
    return key;
  }

  void _ensureOpen() {
    if (_closed) throw StateError('BrowserBridgeVault is closed.');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _database.close();
  }
}

final class _EncryptedRow {
  const _EncryptedRow(this.cipherText, this.nonce, this.mac);
  final Uint8List cipherText;
  final Uint8List nonce;
  final Uint8List mac;
}
