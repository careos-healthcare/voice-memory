import 'dart:convert';

import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:drift/drift.dart';

part 'fact_ledger_dao.g.dart';

@DriftAccessor(tables: [FactLedgerEntries])
class FactLedgerDao extends DatabaseAccessor<AppDatabase>
    with _$FactLedgerDaoMixin {
  FactLedgerDao(super.db);

  Future<void> upsert(ArchiveFact fact) async {
    await into(factLedgerEntries).insertOnConflictUpdate(_companionFor(fact));
  }

  Future<void> deleteById(String id) async {
    await (delete(factLedgerEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<int> countFacts() async {
    final count = countAll();
    final query = selectOnly(factLedgerEntries)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countDistinctEntries() async {
    final rows = await customSelect(
      'SELECT COUNT(DISTINCT source_entry_id) AS count FROM fact_ledger',
      readsFrom: {factLedgerEntries},
    ).getSingle();
    return rows.read<int>('count');
  }

  Future<List<ArchiveFact>> forEntry(String sourceEntryId) async {
    final rows = await (select(factLedgerEntries)
          ..where((t) => t.sourceEntryId.equals(sourceEntryId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_factFromRow).toList(growable: false);
  }

  Future<List<ArchiveFact>> loadEvidenceCitations() async {
    final rows = await (select(factLedgerEntries)
          ..where((t) => t.factType.equals(FactType.evidenceCitation.id))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_factFromRow).toList(growable: false);
  }

  Future<List<ArchiveFact>> citationsForEntry(String sourceEntryId) async {
    final rows = await (select(factLedgerEntries)
          ..where(
            (t) =>
                t.sourceEntryId.equals(sourceEntryId) &
                t.factType.equals(FactType.evidenceCitation.id),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_factFromRow).toList(growable: false);
  }

  Future<List<ArchiveFact>> loadAll() async {
    final rows = await (select(factLedgerEntries)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
    return rows.map(_factFromRow).toList(growable: false);
  }

  FactLedgerEntriesCompanion _companionFor(ArchiveFact fact) {
    return FactLedgerEntriesCompanion.insert(
      id: fact.id,
      sourceEntryId: fact.sourceEntryId,
      label: fact.label,
      value: fact.value,
      note: Value(fact.note),
      createdAt: fact.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAt: fact.updatedAt.toUtc().millisecondsSinceEpoch,
      factType: fact.factType,
      archivePackId: Value(fact.archivePackId),
      archiveThreadId: Value(fact.archiveThreadId),
      collectionIdsJson: Value(jsonEncode(fact.collectionIds)),
      isPinned: Value(fact.isPinned ? 1 : 0),
      preserveOriginal: Value(fact.preserveOriginal ? 1 : 0),
    );
  }

  ArchiveFact _factFromRow(FactLedgerRow row) {
    final collectionRaw = row.collectionIdsJson;
    List<String> collectionIds = const [];
    try {
      final decoded = jsonDecode(collectionRaw);
      if (decoded is List) {
        collectionIds = decoded.whereType<String>().toList(growable: false);
      }
    } on Object {
      collectionIds = const [];
    }

    return ArchiveFact(
      id: row.id,
      sourceEntryId: row.sourceEntryId,
      label: row.label,
      value: row.value,
      note: row.note,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      factType: row.factType,
      archivePackId: row.archivePackId,
      archiveThreadId: row.archiveThreadId,
      collectionIds: collectionIds,
      isPinned: row.isPinned != 0,
      preserveOriginal: row.preserveOriginal != 0,
    );
  }
}
