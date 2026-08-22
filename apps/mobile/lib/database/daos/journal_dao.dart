import 'dart:convert';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:drift/drift.dart';

part 'journal_dao.g.dart';

@DriftAccessor(tables: [JournalEntries])
class JournalDao extends DatabaseAccessor<AppDatabase> with _$JournalDaoMixin {
  JournalDao(super.db);

  Future<List<Map<String, Object?>>> fetchActivePageAfter({
    required int limit,
    DateTime? afterCreatedAt,
    String? afterId,
  }) async {
    final query = select(journalEntries)
      ..where((t) => t.deletedAt.isNull())
      ..where(_keysetCondition(afterCreatedAt: afterCreatedAt, afterId: afterId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_journalRowToSqlMap).toList();
  }

  Future<List<Map<String, dynamic>>> fetchJournalEntryRows({
    DateTime? afterCreatedAt,
    String? afterId,
    int limit = DatabaseConstants.defaultPageSize,
  }) async {
    if (limit <= 0) return const [];
    final rows = await fetchActivePageAfter(
      limit: limit,
      afterCreatedAt: afterCreatedAt,
      afterId: afterId,
    );
    return rows.map(Map<String, dynamic>.from).toList(growable: false);
  }

  Future<Map<String, Object?>?> findActiveRowByCaptureContextTag(String tag) async {
    final row = await customSelect(
      '''
      SELECT
        id,
        created_at,
        updated_at,
        deleted_at,
        is_archived,
        transcript,
        has_verified_proof,
        payload_json
      FROM ${DatabaseConstants.journalEntriesTable}
      WHERE deleted_at IS NULL
        AND json_extract(payload_json, '${DatabaseConstants.captureContextTagJsonPath}') = ?
      LIMIT 1
      ''',
      variables: [Variable<String>(tag)],
      readsFrom: {journalEntries},
    ).getSingleOrNull();
    return row?.data;
  }

  Future<List<Map<String, Object?>>> fetchAllActiveRows() async {
    final rows = await (select(journalEntries)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return rows.map(_journalRowToSqlMap).toList(growable: false);
  }

  Future<int> countActive({String? likePattern}) async {
    if (likePattern == null || likePattern.isEmpty) {
      final count = countAll();
      final query = selectOnly(journalEntries)
        ..addColumns([count])
        ..where(journalEntries.deletedAt.isNull());
      final row = await query.getSingle();
      return row.read(count) ?? 0;
    }

    final count = countAll();
    final query = selectOnly(journalEntries)
      ..addColumns([count])
      ..where(
        journalEntries.deletedAt.isNull() &
            journalEntries.transcript.lower().like(likePattern),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<List<Map<String, Object?>>> fetchProofContextStubRows() async {
    final rows = await (select(journalEntries)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return rows
        .map(
          (row) => {
            'id': row.id,
            'created_at': row.createdAt,
            'transcript': row.transcript,
            'is_archived': row.isArchived,
          },
        )
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> fetchVerifiedProofRows() async {
    final rows = await (select(journalEntries)
          ..where(
            (t) => t.deletedAt.isNull() & t.hasVerifiedProof.equals(1),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_journalRowToSqlMap).toList(growable: false);
  }

  Future<Map<String, ExistingJournalSyncState>> loadExistingSyncState(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return const {};

    final rows = await (select(journalEntries)..where((t) => t.id.isIn(ids))).get();
    return {
      for (final row in rows)
        row.id: ExistingJournalSyncState(
          transcript: row.transcript,
          deletedAt: row.deletedAt,
        ),
    };
  }

  Future<void> upsertJournalEntry(JournalEntry entry) async {
    await into(journalEntries).insertOnConflictUpdate(_companionFor(entry));
  }

  JournalEntriesCompanion _companionFor(JournalEntry entry) {
    return JournalEntriesCompanion.insert(
      id: entry.id,
      createdAt: entry.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAt: entry.updatedAt.toUtc().millisecondsSinceEpoch,
      deletedAt: Value(entry.deletedAt?.toUtc().millisecondsSinceEpoch),
      isArchived: entry.isArchived ? 1 : 0,
      transcript: entry.transcript,
      hasVerifiedProof: entry.verifiedProof != null ? 1 : 0,
      payloadJson: Value(_encodeResidualPayload(entry)),
    );
  }

  String? _encodeResidualPayload(JournalEntry entry) {
    final payload = entry.toResidualJson();
    if (payload.isEmpty) return null;
    return jsonEncode(payload);
  }

  Expression<bool> Function(JournalEntries tbl) _keysetCondition({
    required DateTime? afterCreatedAt,
    required String? afterId,
  }) {
    if (afterCreatedAt == null || afterId == null) {
      return (_) => const Constant(true);
    }

    final createdAtMillis = afterCreatedAt.toUtc().millisecondsSinceEpoch;
    return (t) =>
        t.createdAt.isSmallerThanValue(createdAtMillis) |
        (t.createdAt.equals(createdAtMillis) &
            t.id.isSmallerThanValue(afterId));
  }

  Map<String, Object?> _journalRowToSqlMap(JournalEntryRow row) => {
    'id': row.id,
    'created_at': row.createdAt,
    'updated_at': row.updatedAt,
    'deleted_at': row.deletedAt,
    'is_archived': row.isArchived,
    'transcript': row.transcript,
    'has_verified_proof': row.hasVerifiedProof,
    'payload_json': row.payloadJson,
  };
}

/// Transcript/deletion snapshot used during journal bulk mirror sync.
final class ExistingJournalSyncState {
  const ExistingJournalSyncState({
    required this.transcript,
    required this.deletedAt,
  });

  final String transcript;
  final int? deletedAt;
}
