import 'dart:convert';
import 'dart:developer' as developer;

import 'package:archiveme_mobile/storage/sqlite/migrations/migration_029_coach_action_items.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_030_sync_purgatory.dart';
import 'package:sqflite/sqflite.dart';

/// One raw `crsql_changes` row from a peer.
class CrsqlDeltaPacket {
  const CrsqlDeltaPacket({
    required this.table,
    required this.pk,
    required this.cid,
    required this.val,
    this.colVersion = 1,
    this.dbVersion = 1,
    this.siteId = '',
    this.causalLength = 1,
    this.seq,
  });

  final String table;
  final String pk;
  final String cid;
  final String? val;
  final int colVersion;
  final int dbVersion;
  final String siteId;
  final int causalLength;
  final int? seq;

  Map<String, Object?> toJson() => {
    'table': table,
    'pk': pk,
    'cid': cid,
    'val': val,
    'colVersion': colVersion,
    'dbVersion': dbVersion,
    'siteId': siteId,
    'causalLength': causalLength,
    'seq': seq,
  };

  factory CrsqlDeltaPacket.fromJson(Map<String, dynamic> json) {
    return CrsqlDeltaPacket(
      table: '${json['table']}',
      pk: '${json['pk']}',
      cid: '${json['cid']}',
      val: json['val'] as String?,
      colVersion: (json['colVersion'] as num?)?.toInt() ?? 1,
      dbVersion: (json['dbVersion'] as num?)?.toInt() ?? 1,
      siteId: '${json['siteId'] ?? ''}',
      causalLength: (json['causalLength'] as num?)?.toInt() ?? 1,
      seq: (json['seq'] as num?)?.toInt(),
    );
  }
}

/// How many packets landed in a CRR, how many waited, and how many were retried.
class CrsqlIngestResult {
  const CrsqlIngestResult({
    required this.applied,
    required this.parked,
    required this.restored,
  });

  final int applied;
  final int parked;
  final int restored;
}

/// Applies cr-sqlite delta packets without letting a missing parent abort sync.
///
/// Foreign keys are off only while the batch transaction is open. They are
/// turned back on as soon as that transaction finishes.
class CrsqlDeltaIngestor {
  CrsqlDeltaIngestor(
    this.database, {
    this.pragmaTrace,
    this.warningSink,
  });

  /// Notified with the database file path after a parked-row flush.
  ///
  /// The purgatory evaluator installs this so a completed P2P batch starts
  /// the background worker without this class importing that service.
  static void Function(String filePath)? onBatchEvaluated;

  final DatabaseExecutor database;

  /// Receives non-fatal warnings when a parked row still has no parent.
  final void Function(String message)? warningSink;

  /// Records `OFF` and `ON` when set, so tests can see the pragma window.
  final List<String>? pragmaTrace;

  static const _childTables = <String>{
    Migration029CoachActionItems.table,
    Migration029CoachActionItems.clipsTable,
  };

  static const _parentTable = 'journal_entries';
  static const _parentColumn = 'entry_id';

  static final _ident = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Inserts [packets], parking any that still violate a parent link.
  Future<CrsqlIngestResult> ingest(List<CrsqlDeltaPacket> packets) async {
    final db = database;
    if (db is! Database) {
      throw ArgumentError('crsql ingest needs a Database connection');
    }
    await _setForeignKeys(db, enabled: false);
    var applied = 0;
    var parked = 0;
    try {
      final counts = await db.transaction((txn) async {
        return _ingestBatch(txn, packets);
      });
      applied = counts.$1;
      parked = counts.$2;
    } finally {
      await _setForeignKeys(db, enabled: true);
    }
    final restored = await retryAfterMeshSync();
    return CrsqlIngestResult(
      applied: applied,
      parked: parked,
      restored: restored,
    );
  }

  /// Replays parked packets after a mesh sync once their parent transcript exists.
  Future<int> retryAfterMeshSync() async {
    await Future<void>.delayed(Duration.zero);
    final restored = await evaluateInTransaction();
    final db = database;
    final hook = onBatchEvaluated;
    if (hook != null && db is Database) {
      hook(db.path);
    }
    return restored;
  }

  /// Flushes every `sync_purgatory` row inside one transaction.
  ///
  /// A row whose parent is still missing stays parked. That case is logged
  /// and the loop continues so one orphan cannot roll back the rows that
  /// did apply. Foreign keys stay on for this pass.
  Future<int> evaluateInTransaction() async {
    if (!await _tableExists(Migration030SyncPurgatory.table)) return 0;
    final db = database;
    final useCrsql = await _crsqlChangesExists(db);
    if (db is! Database) {
      return _flushParked(db, useCrsql: useCrsql);
    }
    var restored = 0;
    await db.transaction((txn) async {
      restored = await _flushParked(txn, useCrsql: useCrsql);
    });
    return restored;
  }

  Future<int> _flushParked(
    DatabaseExecutor db, {
    required bool useCrsql,
  }) async {
    final waiting = await _loadParked(db);
    if (waiting.isEmpty) return 0;
    final ordered = [...waiting]
      ..sort(
        (a, b) => _rank(a.packet).compareTo(_rank(b.packet)),
      );
    var restored = 0;
    for (final parked in ordered) {
      if (await _parentMissing(db, parked.packet)) {
        _warn(
          'Parked ${parked.packet.table}/${parked.packet.pk} is still '
          'waiting for its parent transcript.',
        );
        continue;
      }
      final applied = await _applyParkedRow(
        db,
        parked,
        useCrsql: useCrsql,
      );
      if (applied) restored += 1;
    }
    return restored;
  }

  Future<bool> _applyParkedRow(
    DatabaseExecutor db,
    _ParkedPacket parked, {
    required bool useCrsql,
  }) async {
    await db.execute('SAVEPOINT purgatory_row');
    try {
      await _applyPacket(db, parked.packet, useCrsql: useCrsql);
      await db.delete(
        Migration030SyncPurgatory.table,
        where: 'id = ?',
        whereArgs: [parked.id],
      );
      await db.execute('RELEASE purgatory_row');
      return true;
    } on Object catch (error) {
      await _rollbackSavepoint(db);
      _warn(
        'Parked ${parked.packet.table}/${parked.packet.pk} stayed in '
        'sync_purgatory: $error',
      );
      return false;
    }
  }

  Future<void> _rollbackSavepoint(DatabaseExecutor db) async {
    try {
      await db.execute('ROLLBACK TO purgatory_row');
      await db.execute('RELEASE purgatory_row');
    } on Object {
      // The statement failure already undid the savepoint.
    }
  }

  void _warn(String message) {
    final sink = warningSink;
    if (sink != null) {
      sink(message);
      return;
    }
    developer.log(message, name: 'PurgatoryEvaluator', level: 900);
  }

  Future<(int, int)> _ingestBatch(
    DatabaseExecutor txn,
    List<CrsqlDeltaPacket> packets,
  ) async {
    final useCrsql = await _crsqlChangesExists(txn);
    final blocked = <String>{};
    var applied = 0;
    var parked = 0;
    for (final packet in _ordered(packets)) {
      final key = '${packet.table}\u0000${packet.pk}';
      final missingParent =
          blocked.contains(key) || await _parentMissing(txn, packet);
      if (missingParent) {
        blocked.add(key);
        await _park(txn, packet);
        parked += 1;
        continue;
      }
      try {
        await _applyPacket(txn, packet, useCrsql: useCrsql);
        applied += 1;
      } on Object catch (error) {
        if (!_isForeignKey(error)) rethrow;
        blocked.add(key);
        await _park(txn, packet);
        parked += 1;
      }
    }
    final moved = await _quarantineForeignKeyViolations(txn, packets);
    return (applied - moved, parked + moved);
  }

  Future<int> _quarantineForeignKeyViolations(
    DatabaseExecutor txn,
    List<CrsqlDeltaPacket> packets,
  ) async {
    final violations = await txn.rawQuery('PRAGMA foreign_key_check');
    var moved = 0;
    for (final violation in violations) {
      final table = '${violation['table']}';
      if (!_ident.hasMatch(table)) continue;
      final rowid = violation['rowid'];
      final idRows = await txn.rawQuery(
        'SELECT id FROM $table WHERE rowid = ?',
        [rowid],
      );
      if (idRows.isEmpty) continue;
      final id = '${idRows.first['id']}';
      final related = packets.where(
        (packet) => packet.table == table && packet.pk == id,
      );
      if (related.isEmpty) continue;
      for (final packet in related) {
        await _park(txn, packet);
        moved += 1;
      }
      await txn.delete(table, where: 'id = ?', whereArgs: [id]);
    }
    return moved;
  }

  Future<void> _applyPacket(
    DatabaseExecutor db,
    CrsqlDeltaPacket packet, {
    required bool useCrsql,
  }) async {
    if (!_ident.hasMatch(packet.table) || !_ident.hasMatch(packet.cid)) {
      throw ArgumentError('Unsafe cr-sqlite identifier');
    }
    if (useCrsql) {
      await db.rawInsert(
        '''
        INSERT INTO crsql_changes (
          "table", pk, cid, val, col_version, db_version, site_id, cl
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          packet.table,
          packet.pk,
          packet.cid,
          packet.val,
          packet.colVersion,
          packet.dbVersion,
          packet.siteId,
          packet.causalLength,
        ],
      );
      return;
    }
    final existing = await db.query(
      packet.table,
      where: 'id = ?',
      whereArgs: [packet.pk],
      limit: 1,
    );
    final value = _typed(packet);
    if (existing.isEmpty) {
      final row = <String, Object?>{
        'id': packet.pk,
        packet.cid: value,
      };
      _fillRequired(packet.table, row);
      await db.insert(packet.table, row);
      return;
    }
    await db.update(
      packet.table,
      {packet.cid: value},
      where: 'id = ?',
      whereArgs: [packet.pk],
    );
  }

  Future<bool> _parentMissing(
    DatabaseExecutor db,
    CrsqlDeltaPacket packet,
  ) async {
    if (!_childTables.contains(packet.table)) return false;
    var entryId = packet.cid == _parentColumn ? packet.val : null;
    if (entryId == null || entryId.isEmpty) {
      final rows = await db.query(
        packet.table,
        columns: const [_parentColumn],
        where: 'id = ?',
        whereArgs: [packet.pk],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final stored = rows.first[_parentColumn];
        if (stored != null) entryId = '$stored';
      }
    }
    if (entryId == null || entryId.isEmpty) return true;
    final parent = await db.query(
      _parentTable,
      columns: const ['id'],
      where: 'id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    return parent.isEmpty;
  }

  Future<void> _park(DatabaseExecutor db, CrsqlDeltaPacket packet) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO ${Migration030SyncPurgatory.table} (
        target_table, pk, cid, val, col_version, db_version, site_id,
        causal_length, seq, packet_json, parked_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        packet.table,
        packet.pk,
        packet.cid,
        packet.val,
        packet.colVersion,
        packet.dbVersion,
        packet.siteId,
        packet.causalLength,
        packet.seq,
        jsonEncode(packet.toJson()),
        now,
      ],
    );
  }

  Future<List<_ParkedPacket>> _loadParked(DatabaseExecutor db) async {
    final rows = await db.query(
      Migration030SyncPurgatory.table,
      orderBy: 'id ASC',
    );
    return [
      for (final row in rows)
        _ParkedPacket(
          id: (row['id'] as num).toInt(),
          packet: CrsqlDeltaPacket.fromJson(
            Map<String, dynamic>.from(
              jsonDecode('${row['packet_json']}') as Map,
            ),
          ),
        ),
    ];
  }

  List<CrsqlDeltaPacket> _ordered(List<CrsqlDeltaPacket> packets) {
    final copy = [...packets];
    copy.sort((a, b) => _rank(a).compareTo(_rank(b)));
    return copy;
  }

  int _rank(CrsqlDeltaPacket packet) {
    if (packet.table == _parentTable) return 0;
    if (packet.cid == _parentColumn) return 1;
    return 2;
  }

  Object? _typed(CrsqlDeltaPacket packet) {
    final val = packet.val;
    if (val == null) return null;
    const ints = {
      'created_at',
      'updated_at',
      'deleted_at',
      'estimate_minutes',
      'start_offset',
      'end_offset',
      'is_archived',
      'has_verified_proof',
      'is_time_capsule',
      'unlock_date',
      'logged_at',
      'target_count',
    };
    if (ints.contains(packet.cid)) return int.tryParse(val) ?? 0;
    return val;
  }

  void _fillRequired(String table, Map<String, Object?> row) {
    const defaults = <String, Map<String, Object?>>{
      'journal_entries': {
        'created_at': 0,
        'updated_at': 0,
        'is_archived': 0,
        'transcript': '',
        'has_verified_proof': 0,
        'is_time_capsule': 0,
      },
      Migration029CoachActionItems.table: {
        'entry_id': '',
        'text': '',
        'timeline_label': '',
        'estimate_minutes': 0,
        'created_at': 0,
      },
      Migration029CoachActionItems.clipsTable: {
        'entry_id': '',
        'start_offset': 0,
        'end_offset': 0,
        'text': '',
      },
    };
    final required = defaults[table];
    if (required == null) return;
    for (final entry in required.entries) {
      row.putIfAbsent(entry.key, () => entry.value);
    }
  }

  Future<void> _setForeignKeys(Database db, {required bool enabled}) async {
    final flag = enabled ? 'ON' : 'OFF';
    await db.execute('PRAGMA foreign_keys = $flag');
    pragmaTrace?.add(flag);
  }

  Future<bool> _crsqlChangesExists(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      '''
      SELECT name FROM sqlite_master
      WHERE name = ? AND type IN ('table', 'view')
      ''',
      ['crsql_changes'],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _tableExists(String name) async {
    final rows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [name],
    );
    return rows.isNotEmpty;
  }

  bool _isForeignKey(Object error) {
    return error.toString().toLowerCase().contains('foreign key');
  }
}

class _ParkedPacket {
  const _ParkedPacket({required this.id, required this.packet});

  final int id;
  final CrsqlDeltaPacket packet;
}
