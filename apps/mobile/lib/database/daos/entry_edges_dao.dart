import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_013_entry_edges.dart';
import 'package:drift/drift.dart';

part 'entry_edges_dao.g.dart';

/// Persisted semantic edge between two journal entries.
final class EntryEdge {
  const EntryEdge({
    required this.sourceEntryId,
    required this.targetEntryId,
    required this.relation,
    required this.weight,
    required this.createdAt,
  });

  final String sourceEntryId;
  final String targetEntryId;
  final String relation;
  final double weight;
  final DateTime createdAt;
}

@DriftAccessor(tables: [EntryEdges])
class EntryEdgesDao extends DatabaseAccessor<AppDatabase>
    with _$EntryEdgesDaoMixin {
  EntryEdgesDao(super.db);

  static const edgesTable = Migration013EntryEdges.edgesTable;

  Future<List<EntryEdge>> readOutgoingEdges(String sourceEntryId) async {
    if (sourceEntryId.isEmpty) return const [];

    final rows = await (select(entryEdges)
          ..where((t) => t.sourceEntryId.equals(sourceEntryId))
          ..orderBy([(t) => OrderingTerm.desc(t.weight)]))
        .get();

    return rows.map(_rowToEdge).toList(growable: false);
  }

  Future<Set<String>> recursiveEntryIds({
    required String seedEntryId,
    required int maxDepth,
  }) async {
    if (seedEntryId.isEmpty) return {};

    final depth = maxDepth.clamp(0, 6);
    final rows = await customSelect(
      '''
      WITH RECURSIVE graph_walk(entry_id, depth) AS (
        SELECT ?, 0
        UNION ALL
        SELECT
          CASE
            WHEN ee.source_entry_id = graph_walk.entry_id THEN ee.target_entry_id
            ELSE ee.source_entry_id
          END,
          graph_walk.depth + 1
        FROM $edgesTable ee
        INNER JOIN graph_walk ON (
          ee.source_entry_id = graph_walk.entry_id
          OR ee.target_entry_id = graph_walk.entry_id
        )
        WHERE graph_walk.depth < ?
      )
      SELECT entry_id FROM graph_walk
      WHERE entry_id IS NOT NULL AND entry_id != ''
      ''',
      variables: [
        Variable<String>(seedEntryId),
        Variable<int>(depth),
      ],
      readsFrom: {entryEdges},
    ).get();

    return rows
        .map((row) => row.read<String>('entry_id'))
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, Object?>>> loadEntryEdgeLinks({
    required Set<String> entryIds,
  }) async {
    if (entryIds.isEmpty) return const [];

    final placeholders = List.filled(entryIds.length, '?').join(', ');
    final args = [...entryIds, ...entryIds];
    final rows = await customSelect(
      '''
      SELECT source_entry_id, target_entry_id, relation, weight, created_at
      FROM $edgesTable
      WHERE source_entry_id IN ($placeholders)
         OR target_entry_id IN ($placeholders)
      ''',
      variables: args.map(Variable<String>.new).toList(),
      readsFrom: {entryEdges},
    ).get();

    return rows.map((row) => row.data).toList();
  }

  EntryEdge _rowToEdge(EntryEdgeRow row) {
    return EntryEdge(
      sourceEntryId: row.sourceEntryId,
      targetEntryId: row.targetEntryId,
      relation: row.relation,
      weight: row.weight,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    );
  }
}
