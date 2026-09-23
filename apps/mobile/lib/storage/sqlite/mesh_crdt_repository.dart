import 'dart:typed_data';

import 'package:archiveme_mobile/core/database/vector_store.dart';
import 'package:archiveme_mobile/features/sample_vault/sample_vault_embedder.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_020_entity_graph.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_026_habits.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_027_sync_changelog.dart';
import 'package:sqflite/sqflite.dart';

/// One changelog row plus the record a peer should apply.
class SyncChangelogEntry {
  const SyncChangelogEntry({
    required this.entityTable,
    required this.recordId,
    required this.updatedAt,
    required this.deviceId,
    this.row = const {},
  });

  final String entityTable;
  final String recordId;
  final DateTime updatedAt;
  final String deviceId;

  /// Current columns for this record. Relationship [row] `weight` is this
  /// device's own contribution, not the summed edge.
  final Map<String, Object?> row;

  int get updatedAtMillis => updatedAt.toUtc().millisecondsSinceEpoch;
}

/// How many remote changes landed, and the vector hits refreshed afterward.
class SyncMergeResult {
  const SyncMergeResult({
    required this.applied,
    required this.keptLocal,
    required this.mergedEntryIds,
    required this.vectorHits,
  });

  final int applied;
  final int keptLocal;
  final List<String> mergedEntryIds;
  final List<VectorStoreHit> vectorHits;
}

/// Last-write-wins rows and additive graph weights, applied inside SQLite.
///
/// Journal entries, habits, and habit logs keep the newer clock. Equal clocks
/// keep the greater device id. Entity rows are a union. Relationship weights
/// from different devices add; a later write from the same device replaces
/// only that device's share. Callers never choose a winner.
class MeshCrdtRepository {
  MeshCrdtRepository({required this.database, required this.deviceId}) {
    if (deviceId.trim().isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Must not be empty');
    }
  }

  final DatabaseExecutor database;
  final String deviceId;

  static const changelogTable = Migration027SyncChangelog.changelogTable;
  static const weightReplicasTable =
      Migration027SyncChangelog.weightReplicasTable;

  static const lwwTables = <String>{
    'journal_entries',
    Migration026Habits.habitsTable,
    Migration026Habits.logsTable,
  };

  static const additiveTables = <String>{
    Migration020EntityGraph.entitiesTable,
    Migration020EntityGraph.relationshipsTable,
  };

  final Map<String, Set<String>> _columns = {};

  /// Writes [row] and appends this device's changelog clock.
  ///
  /// For relationships, [row] `weight` is this device's contribution.
  Future<void> recordChange({
    required String entityTable,
    required String recordId,
    required Map<String, Object?> row,
    DateTime? updatedAt,
  }) async {
    await Future<void>.delayed(Duration.zero);
    _requireTable(entityTable);
    final clock = (updatedAt ?? DateTime.now()).toUtc();
    final logged = SyncChangelogEntry(
      entityTable: entityTable,
      recordId: recordId,
      updatedAt: clock,
      deviceId: deviceId,
      row: row,
    );
    if (entityTable == Migration020EntityGraph.relationshipsTable) {
      await _setDeviceWeight(
        relationshipId: recordId,
        ownerId: deviceId,
        weight: _weightOf(row),
        updatedAt: clock.millisecondsSinceEpoch,
        row: row,
      );
    } else {
      await _upsert(entityTable, recordId, row, clock.millisecondsSinceEpoch);
      if (entityTable == 'journal_entries') {
        await _storeEmbedding(logged);
      }
    }
    await _log(
      entityTable: entityTable,
      recordId: recordId,
      updatedAt: clock.millisecondsSinceEpoch,
      ownerId: deviceId,
    );
  }

  /// Changes this device has made at or after [since], newest last.
  Future<List<SyncChangelogEntry>> exportChanges({
    DateTime? since,
  }) async {
    final floor = since?.toUtc().millisecondsSinceEpoch ?? 0;
    final rows = await database.query(
      changelogTable,
      where: 'device_id = ? AND updated_at >= ?',
      whereArgs: [deviceId, floor],
      orderBy: 'updated_at ASC, record_id ASC',
    );
    final changes = <SyncChangelogEntry>[];
    for (final logged in rows) {
      final table = '${logged['entity_table']}';
      final recordId = '${logged['record_id']}';
      final stored = await _readRow(table, recordId);
      if (stored == null) continue;
      final row = Map<String, Object?>.from(stored);
      if (table == Migration020EntityGraph.relationshipsTable) {
        row['weight'] = await _replicaWeight(recordId, deviceId);
      } else if (table == 'journal_entries') {
        final embedding = await _embeddingBlob(recordId);
        if (embedding != null) row['embedding'] = embedding;
      }
      changes.add(
        SyncChangelogEntry(
          entityTable: table,
          recordId: recordId,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (logged['updated_at'] as num).toInt(),
            isUtc: true,
          ),
          deviceId: deviceId,
          row: row,
        ),
      );
    }
    return changes;
  }

  /// Applies [remote] changes. Replaying the same batch does not move weights.
  Future<SyncMergeResult> merge(List<SyncChangelogEntry> remote) async {
    await Future<void>.delayed(Duration.zero);
    var applied = 0;
    var keptLocal = 0;
    final mergedEntries = <String>[];
    for (final change in remote) {
      _requireTable(change.entityTable);
      if (change.deviceId.trim().isEmpty) {
        throw ArgumentError('Remote device id is empty');
      }
      final didApply = await _apply(change);
      if (didApply) {
        applied += 1;
        if (change.entityTable == 'journal_entries') {
          mergedEntries.add(change.recordId);
        }
      } else {
        keptLocal += 1;
      }
    }
    final hits = await _refreshVectors(mergedEntries);
    return SyncMergeResult(
      applied: applied,
      keptLocal: keptLocal,
      mergedEntryIds: mergedEntries,
      vectorHits: hits,
    );
  }

  Future<bool> _apply(SyncChangelogEntry change) async {
    if (change.entityTable == Migration020EntityGraph.relationshipsTable) {
      return _applyRelationship(change);
    }
    if (change.entityTable == Migration020EntityGraph.entitiesTable) {
      return _applyEntity(change);
    }
    final local = await _latest(change.entityTable, change.recordId);
    if (!_remoteWins(local, change)) return false;
    await _upsert(
      change.entityTable,
      change.recordId,
      change.row,
      change.updatedAtMillis,
    );
    if (change.entityTable == 'journal_entries') {
      await _storeEmbedding(change);
    }
    await _log(
      entityTable: change.entityTable,
      recordId: change.recordId,
      updatedAt: change.updatedAtMillis,
      ownerId: change.deviceId,
    );
    return true;
  }

  Future<bool> _applyEntity(SyncChangelogEntry change) async {
    final existing = await _readRow(
      Migration020EntityGraph.entitiesTable,
      change.recordId,
    );
    if (existing == null) {
      await _upsert(
        change.entityTable,
        change.recordId,
        change.row,
        change.updatedAtMillis,
      );
      await _log(
        entityTable: change.entityTable,
        recordId: change.recordId,
        updatedAt: change.updatedAtMillis,
        ownerId: change.deviceId,
      );
      return true;
    }
    final local = await _latest(change.entityTable, change.recordId);
    if (!_remoteWins(local, change)) return false;
    await _upsert(
      change.entityTable,
      change.recordId,
      change.row,
      change.updatedAtMillis,
    );
    await _log(
      entityTable: change.entityTable,
      recordId: change.recordId,
      updatedAt: change.updatedAtMillis,
      ownerId: change.deviceId,
    );
    return true;
  }

  Future<bool> _applyRelationship(SyncChangelogEntry change) async {
    final current = await _replicaClock(change.recordId, change.deviceId);
    if (current != null && change.updatedAtMillis < current) return false;
    if (current == change.updatedAtMillis) {
      final stored = await _replicaWeight(change.recordId, change.deviceId);
      if (stored == _weightOf(change.row)) return false;
    }
    await _setDeviceWeight(
      relationshipId: change.recordId,
      ownerId: change.deviceId,
      weight: _weightOf(change.row),
      updatedAt: change.updatedAtMillis,
      row: change.row,
    );
    await _log(
      entityTable: change.entityTable,
      recordId: change.recordId,
      updatedAt: change.updatedAtMillis,
      ownerId: change.deviceId,
    );
    return true;
  }

  Future<void> _setDeviceWeight({
    required String relationshipId,
    required String ownerId,
    required double weight,
    required int updatedAt,
    required Map<String, Object?> row,
  }) async {
    await database.insert(weightReplicasTable, {
      'relationship_id': relationshipId,
      'device_id': ownerId,
      'weight': weight,
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final summed = await _sumWeights(relationshipId);
    final next = Map<String, Object?>.from(row)..['weight'] = summed;
    await _upsert(
      Migration020EntityGraph.relationshipsTable,
      relationshipId,
      next,
      updatedAt,
    );
  }

  Future<double> _sumWeights(String relationshipId) async {
    final rows = await database.query(
      weightReplicasTable,
      columns: ['weight'],
      where: 'relationship_id = ?',
      whereArgs: [relationshipId],
    );
    var total = 0.0;
    for (final row in rows) {
      total += (row['weight'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  Future<double?> _replicaWeight(String relationshipId, String ownerId) async {
    final rows = await database.query(
      weightReplicasTable,
      columns: ['weight'],
      where: 'relationship_id = ? AND device_id = ?',
      whereArgs: [relationshipId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.single['weight'] as num?)?.toDouble();
  }

  Future<int?> _replicaClock(String relationshipId, String ownerId) async {
    final rows = await database.query(
      weightReplicasTable,
      columns: ['updated_at'],
      where: 'relationship_id = ? AND device_id = ?',
      whereArgs: [relationshipId, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.single['updated_at'] as num?)?.toInt();
  }

  Future<List<VectorStoreHit>> _refreshVectors(List<String> entryIds) async {
    if (entryIds.isEmpty) return const [];
    final rows = <VectorStoreRow>[];
    for (final entryId in entryIds) {
      final blob = await _embeddingBlob(entryId);
      if (blob == null) continue;
      rows.add(
        VectorStoreRow(
          id: entryId,
          values: SampleVaultEmbedder.fromBlob(blob),
        ),
      );
    }
    if (rows.isEmpty) return const [];
    return VectorStore.scan(
      rows: rows,
      query: rows.first.values,
      limit: rows.length,
    );
  }

  Future<Uint8List?> _embeddingBlob(String entryId) async {
    final stored = await database.query(
      Migration005HybridSearch.embeddingsTable,
      columns: ['embedding'],
      where: 'entry_id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (stored.isEmpty) return null;
    return _asBytes(stored.single['embedding']);
  }

  Future<void> _storeEmbedding(SyncChangelogEntry change) async {
    final blob = _asBytes(change.row['embedding']);
    if (blob == null || blob.length < 4) return;
    await database.insert(
      Migration005HybridSearch.embeddingsTable,
      {
        'entry_id': change.recordId,
        'embedding': blob,
        'dimensions': blob.length ~/ 4,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<_Clock?> _latest(String entityTable, String recordId) async {
    final rows = await database.query(
      changelogTable,
      columns: ['updated_at', 'device_id'],
      where: 'entity_table = ? AND record_id = ?',
      whereArgs: [entityTable, recordId],
      orderBy: 'updated_at DESC, device_id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _Clock(
      updatedAt: (rows.single['updated_at'] as num).toInt(),
      deviceId: '${rows.single['device_id']}',
    );
  }

  bool _remoteWins(_Clock? local, SyncChangelogEntry change) {
    if (local == null) return true;
    if (change.updatedAtMillis != local.updatedAt) {
      return change.updatedAtMillis > local.updatedAt;
    }
    return change.deviceId.compareTo(local.deviceId) > 0;
  }

  Future<void> _log({
    required String entityTable,
    required String recordId,
    required int updatedAt,
    required String ownerId,
  }) async {
    final existing = await database.query(
      changelogTable,
      columns: ['updated_at'],
      where: 'entity_table = ? AND record_id = ? AND device_id = ?',
      whereArgs: [entityTable, recordId, ownerId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final current = (existing.single['updated_at'] as num?)?.toInt() ?? 0;
      if (updatedAt < current) return;
    }
    await database.insert(changelogTable, {
      'entity_table': entityTable,
      'record_id': recordId,
      'updated_at': updatedAt,
      'device_id': ownerId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> _readRow(String table, String recordId) async {
    final rows = await database.query(
      table,
      where: 'id = ?',
      whereArgs: [recordId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.single;
  }

  Future<void> _upsert(
    String table,
    String recordId,
    Map<String, Object?> row,
    int updatedAt,
  ) async {
    final allowed = await _tableColumns(table);
    final payload = <String, Object?>{'id': recordId};
    for (final entry in row.entries) {
      if (entry.key == 'id' || entry.key == 'embedding') continue;
      if (!allowed.contains(entry.key)) continue;
      payload[entry.key] = entry.value;
    }
    if (allowed.contains('updated_at') && !payload.containsKey('updated_at')) {
      payload['updated_at'] = updatedAt;
    }
    final existing = await _readRow(table, recordId);
    if (existing == null) {
      _fillRequired(table, payload, updatedAt);
      await database.insert(table, payload);
      return;
    }
    payload.remove('id');
    if (payload.isEmpty) return;
    await database.update(
      table,
      payload,
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  void _fillRequired(
    String table,
    Map<String, Object?> payload,
    int updatedAt,
  ) {
    if (table == 'journal_entries') {
      payload.putIfAbsent('created_at', () => updatedAt);
      payload.putIfAbsent('updated_at', () => updatedAt);
      payload.putIfAbsent('is_archived', () => 0);
      payload.putIfAbsent('transcript', () => '');
      payload.putIfAbsent('has_verified_proof', () => 0);
      payload.putIfAbsent('payload_json', () => '{}');
    } else if (table == Migration026Habits.habitsTable) {
      payload.putIfAbsent('title', () => '');
      payload.putIfAbsent('frequency', () => 'daily');
      payload.putIfAbsent('target_count', () => 1);
      payload.putIfAbsent('created_at', () => updatedAt);
    } else if (table == Migration026Habits.logsTable) {
      payload.putIfAbsent('habit_id', () => '');
      payload.putIfAbsent('logged_at', () => updatedAt);
    }
  }

  Future<Set<String>> _tableColumns(String table) async {
    final cached = _columns[table];
    if (cached != null) return cached;
    final rows = await database.rawQuery('PRAGMA table_info($table)');
    final names = <String>{
      for (final row in rows) '${row['name']}',
    };
    _columns[table] = names;
    return names;
  }

  Uint8List? _asBytes(Object? blob) {
    if (blob is Uint8List) return blob.isEmpty ? null : blob;
    if (blob is List<int> && blob.isNotEmpty) return Uint8List.fromList(blob);
    return null;
  }

  double _weightOf(Map<String, Object?> row) {
    final weight = row['weight'];
    if (weight is num) return weight.toDouble();
    return 0;
  }

  void _requireTable(String entityTable) {
    if (lwwTables.contains(entityTable)) return;
    if (additiveTables.contains(entityTable)) return;
    throw ArgumentError.value(entityTable, 'entityTable', 'Not a sync table');
  }
}

class _Clock {
  const _Clock({required this.updatedAt, required this.deviceId});

  final int updatedAt;
  final String deviceId;
}
