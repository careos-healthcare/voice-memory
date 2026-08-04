import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../../services/security/sync_identity_service.dart';
import 'e2ee_sync_models.dart';

class SyncOutbox {
  SyncOutbox._(this._database, {required this.databasePath});

  final Database _database;
  final String databasePath;
  final E2EESyncCipher _cipher = const E2EESyncCipher();
  final StreamController<int> _changes = StreamController<int>.broadcast();
  bool _closed = false;

  static SyncOutbox open({required String databasePath}) {
    final file = File(databasePath);
    file.parent.createSync(recursive: true);
    final database = sqlite3.open(databasePath);
    database
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('''
        CREATE TABLE IF NOT EXISTS sync_outbox (
          operation_id TEXT PRIMARY KEY,
          encrypted_operation TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS sync_seen_envelopes (
          envelope_id TEXT PRIMARY KEY,
          seen_at TEXT NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE IF NOT EXISTS sync_crdt_heads (
          entity_key TEXT PRIMARY KEY,
          encrypted_operation TEXT NOT NULL
        )
      ''')
      // Chunk operations are immutable transport fragments, not CRDT state.
      // Remove any rows written by versions that retained them as giant heads.
      ..execute(
        "DELETE FROM sync_crdt_heads WHERE entity_key LIKE 'mediaChunk:%'",
      )
      ..userVersion = 1;
    return SyncOutbox._(database, databasePath: databasePath);
  }

  int get pendingCount {
    _ensureOpen();
    return _database
            .select('SELECT COUNT(*) AS count FROM sync_outbox')
            .single['count']
        as int;
  }

  Stream<int> get changes => _changes.stream;

  /// Flushes WAL pages before a portability snapshot or database close.
  void checkpoint() {
    _ensureOpen();
    _database.execute('PRAGMA wal_checkpoint(FULL)');
  }

  Future<void> enqueue(
    CrdtOperation operation, {
    required SyncEncryptionKey key,
    required int keyEpoch,
  }) async {
    _ensureOpen();
    final envelope = await _cipher.encrypt(
      id: 'local-${operation.id}',
      deviceId: operation.deviceId,
      vectorClock: operation.vectorClock,
      operations: [operation],
      key: key,
      keyEpoch: keyEpoch,
      createdAt: operation.timestamp,
    );
    _database.execute(
      '''
      INSERT OR REPLACE INTO sync_outbox
        (operation_id, encrypted_operation, created_at)
      VALUES (?, ?, ?)
      ''',
      [
        operation.id,
        jsonEncode(envelope.toRelayBlob()),
        operation.timestamp.toIso8601String(),
      ],
    );
    await putHead(operation, key: key, keyEpoch: keyEpoch);
    _emitChange();
  }

  Future<Map<String, CrdtOperation>> heads({
    required SyncEncryptionKey key,
  }) async {
    _ensureOpen();
    final result = <String, CrdtOperation>{};
    for (final row in _database.select(
      'SELECT entity_key, encrypted_operation FROM sync_crdt_heads',
    )) {
      final raw = jsonDecode(row['encrypted_operation'] as String);
      final envelope = E2EESyncEnvelope.fromRelayBlob(
        Map<String, dynamic>.from(raw as Map),
      );
      final operations = await _cipher.decrypt(envelope, key: key);
      if (operations.isNotEmpty) {
        result[row['entity_key'] as String] = operations.single;
      }
    }
    return result;
  }

  /// Returns CRDT winners in a stable order without touching cloud delivery
  /// state. Mesh reconciliation uses this instead of [pending], because peers
  /// exchange current winners rather than consuming relay-bound operations.
  Future<List<MapEntry<String, CrdtOperation>>> orderedHeads({
    required SyncEncryptionKey key,
    String? afterEntityKey,
  }) async {
    final values =
        (await heads(key: key)).entries
            .where(
              (entry) =>
                  afterEntityKey == null ||
                  entry.key.compareTo(afterEntityKey) > 0,
            )
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));
    return List.unmodifiable(values);
  }

  Future<void> putHead(
    CrdtOperation operation, {
    required SyncEncryptionKey key,
    required int keyEpoch,
  }) async {
    if (operation.entityKind == CrdtEntityKind.mediaChunk) {
      _database.execute('DELETE FROM sync_crdt_heads WHERE entity_key = ?', [
        '${operation.entityKind.name}:${operation.entityId}',
      ]);
      return;
    }
    final envelope = await _cipher.encrypt(
      id: 'head-${operation.id}',
      deviceId: operation.deviceId,
      vectorClock: operation.vectorClock,
      operations: [operation],
      key: key,
      keyEpoch: keyEpoch,
      createdAt: operation.timestamp,
    );
    _database.execute(
      'INSERT OR REPLACE INTO sync_crdt_heads '
      '(entity_key, encrypted_operation) VALUES (?, ?)',
      [
        '${operation.entityKind.name}:${operation.entityId}',
        jsonEncode(envelope.toRelayBlob()),
      ],
    );
  }

  Future<List<CrdtOperation>> pending({
    required SyncEncryptionKey key,
    int limit = 100,
  }) async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT encrypted_operation FROM sync_outbox '
      'ORDER BY created_at, operation_id LIMIT ?',
      [limit],
    );
    final operations = <CrdtOperation>[];
    for (final row in rows) {
      final raw = jsonDecode(row['encrypted_operation'] as String);
      final envelope = E2EESyncEnvelope.fromRelayBlob(
        Map<String, dynamic>.from(raw as Map),
      );
      operations.addAll(await _cipher.decrypt(envelope, key: key));
    }
    return operations;
  }

  void markDelivered(Iterable<String> operationIds) {
    _ensureOpen();
    _database.execute('BEGIN IMMEDIATE');
    try {
      for (final id in operationIds) {
        _database.execute('DELETE FROM sync_outbox WHERE operation_id = ?', [
          id,
        ]);
      }
      _database.execute('COMMIT');
      _emitChange();
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  bool hasSeen(String envelopeId) {
    _ensureOpen();
    return _database.select(
      'SELECT 1 FROM sync_seen_envelopes WHERE envelope_id = ?',
      [envelopeId],
    ).isNotEmpty;
  }

  void markSeen(String envelopeId, {DateTime? at}) {
    _ensureOpen();
    _database.execute(
      'INSERT OR IGNORE INTO sync_seen_envelopes (envelope_id, seen_at) '
      'VALUES (?, ?)',
      [envelopeId, (at ?? DateTime.now()).toUtc().toIso8601String()],
    );
  }

  void clear() {
    _ensureOpen();
    _database
      ..execute('DELETE FROM sync_outbox')
      ..execute('DELETE FROM sync_seen_envelopes')
      ..execute('DELETE FROM sync_crdt_heads');
    _emitChange();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _database.close();
    unawaited(_changes.close());
  }

  void _ensureOpen() {
    if (_closed) throw StateError('SyncOutbox is closed.');
  }

  void _emitChange() {
    if (!_closed && !_changes.isClosed) _changes.add(pendingCount);
  }
}
