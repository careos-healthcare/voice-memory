import 'dart:convert';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/domain/recurrent_topic_cluster.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/domain/weekly_topic_synthesis.dart';
import 'package:archiveme_mobile/features/weekly_synthesis/weekly_synthesis_config.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_fts_query.dart';
import 'package:drift/drift.dart';

part 'reflection_graph_dao.g.dart';

/// Hit from FTS5 search over `reflection_graph_node_fts`.
class ReflectionGraphSearchHit {
  const ReflectionGraphSearchHit({
    required this.nodeId,
    required this.entryId,
    required this.kind,
    required this.label,
  });

  final String nodeId;
  final String entryId;
  final String kind;
  final String label;
}

@DriftAccessor(tables: [ReflectionGraphNodes, AppSqliteMeta])
class ReflectionGraphDao extends DatabaseAccessor<AppDatabase>
    with _$ReflectionGraphDaoMixin {
  ReflectionGraphDao(super.db);

  static const nodesTable = DatabaseConstants.graphNodesTable;
  static const ftsTable = DatabaseConstants.graphNodeFtsTable;
  static const themeKind = 'theme';

  Future<void> replaceGraph(OfflineReflectionKnowledgeGraph graph) async {
    await transaction(() => replaceGraphInTransaction(graph));
  }

  Future<void> replaceGraphInTransaction(
    OfflineReflectionKnowledgeGraph graph,
  ) async {
    await deleteForEntry(graph.entryId);
    final updatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final node in graph.nodes) {
      await into(reflectionGraphNodes).insert(
        ReflectionGraphNodesCompanion.insert(
          id: node.id,
          entryId: graph.entryId,
          kind: node.kind,
          label: node.label,
          payloadJson: Value(
            node.payload.isEmpty ? null : jsonEncode(node.payload),
          ),
          updatedAt: updatedAt,
        ),
      );
      await customStatement(
        '''
        INSERT INTO $ftsTable (node_id, entry_id, kind, label)
        VALUES (?, ?, ?, ?)
        ''',
        [node.id, graph.entryId, node.kind, node.label],
      );
    }
  }

  Future<void> deleteForEntry(String entryId) async {
    if (entryId.isEmpty) return;
    await customStatement(
      'DELETE FROM $ftsTable WHERE entry_id = ?',
      [entryId],
    );
    await (delete(reflectionGraphNodes)..where((t) => t.entryId.equals(entryId)))
        .go();
  }

  Future<void> deleteAbsentEntries(Set<String> keepEntryIds) async {
    if (keepEntryIds.isEmpty) {
      await customStatement('DELETE FROM $ftsTable');
      await delete(reflectionGraphNodes).go();
      return;
    }

    final placeholders = List.filled(keepEntryIds.length, '?').join(', ');
    final args = keepEntryIds.toList(growable: false);
    await customStatement(
      'DELETE FROM $ftsTable WHERE entry_id NOT IN ($placeholders)',
      args,
    );
    await customStatement(
      'DELETE FROM $nodesTable WHERE entry_id NOT IN ($placeholders)',
      args,
    );
  }

  Future<List<ReflectionGraphSearchHit>> searchNodes({
    required String query,
    int limit = 20,
  }) async {
    final ftsQuery = SqliteFtsQuery.toMatchQuery(query);
    if (ftsQuery.isEmpty || limit <= 0) return const [];

    final rows = await customSelect(
      '''
      SELECT node_id, entry_id, kind, label
      FROM $ftsTable
      WHERE $ftsTable MATCH ?
      ORDER BY bm25($ftsTable)
      LIMIT ?
      ''',
      variables: [Variable<String>(ftsQuery), Variable<int>(limit)],
    ).get();

    return rows
        .map(
          (row) => ReflectionGraphSearchHit(
            nodeId: row.read<String>('node_id'),
            entryId: row.read<String>('entry_id'),
            kind: row.read<String>('kind'),
            label: row.read<String>('label'),
          ),
        )
        .where((hit) => hit.nodeId.isNotEmpty && hit.entryId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> searchEntryIds({
    required String query,
    int limit = 20,
  }) async {
    if (limit <= 0 || !SqliteFtsQuery.hasMatchTerms(query)) {
      return const [];
    }

    final hits = await searchNodes(query: query, limit: limit * 4);
    final entryIds = <String>[];
    final seen = <String>{};
    for (final hit in hits) {
      if (seen.add(hit.entryId)) {
        entryIds.add(hit.entryId);
        if (entryIds.length >= limit) break;
      }
    }
    return entryIds;
  }

  Future<List<RecurrentTopicCluster>> fetchRecurrentTopics({
    required DateTime since,
    int minMentions = WeeklySynthesisConfig.minTopicMentions,
    int limit = WeeklySynthesisConfig.maxTopicClusters,
  }) async {
    if (limit <= 0) return const [];

    final sinceMs = since.toUtc().millisecondsSinceEpoch;
    final rows = await customSelect(
      '''
      WITH recent_themes AS (
        SELECT
          n.id AS node_id,
          n.entry_id AS entry_id,
          n.label AS label,
          lower(trim(n.label)) AS normalized_label
        FROM $nodesTable n
        INNER JOIN $ftsTable f ON f.node_id = n.id
        WHERE n.kind = ?
          AND n.updated_at >= ?
      )
      SELECT
        normalized_label,
        MIN(label) AS display_label,
        COUNT(*) AS mention_count,
        GROUP_CONCAT(node_id) AS node_ids,
        GROUP_CONCAT(entry_id) AS entry_ids
      FROM recent_themes
      GROUP BY normalized_label
      HAVING mention_count >= ?
      ORDER BY mention_count DESC, display_label ASC
      LIMIT ?
      ''',
      variables: [
        Variable<String>(themeKind),
        Variable<int>(sinceMs),
        Variable<int>(minMentions),
        Variable<int>(limit),
      ],
      readsFrom: {reflectionGraphNodes},
    ).get();

    return rows
        .map((row) {
          final normalized = row.read<String>('normalized_label');
          final display = row.read<String>('display_label');
          if (normalized.isEmpty || display.isEmpty) return null;
          return RecurrentTopicCluster(
            normalizedLabel: normalized,
            displayLabel: display,
            mentionCount: row.read<int>('mention_count'),
            nodeIds: _splitCsv(row.readNullable<String>('node_ids')),
            entryIds: _splitCsv(row.readNullable<String>('entry_ids')),
          );
        })
        .whereType<RecurrentTopicCluster>()
        .toList(growable: false);
  }

  Future<bool> hasWeeklySynthesisForWeek(String weekKey) async {
    final entryId =
        '${WeeklySynthesisConfig.synthesisEntryIdPrefix}:$weekKey';
    final row = await (select(reflectionGraphNodes)
          ..where(
            (t) =>
                t.entryId.equals(entryId) &
                t.kind.equals(WeeklySynthesisConfig.synthesisNodeKind),
          )
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> saveWeeklySynthesis(WeeklyTopicSynthesis synthesis) async {
    final updatedAt = synthesis.generatedAt.toUtc().millisecondsSinceEpoch;
    final payload = jsonEncode({
      'weekKey': synthesis.weekKey,
      'weekStart': synthesis.weekStart.toUtc().toIso8601String(),
      'headline': synthesis.headline,
      'summary': synthesis.summary,
      'sourceNodeIds': synthesis.sourceNodeIds,
      'recurringThemeLabels': synthesis.recurringThemeLabels,
      'generatedAt': synthesis.generatedAt.toUtc().toIso8601String(),
      'model': 'gemma-litertlm',
    });

    await transaction(() async {
      await deleteForEntry(synthesis.entryId);
      await into(reflectionGraphNodes).insert(
        ReflectionGraphNodesCompanion.insert(
          id: synthesis.nodeId,
          entryId: synthesis.entryId,
          kind: WeeklySynthesisConfig.synthesisNodeKind,
          label: synthesis.headline,
          payloadJson: Value(payload),
          updatedAt: updatedAt,
        ),
      );
      await customStatement(
        '''
        INSERT INTO $ftsTable (node_id, entry_id, kind, label)
        VALUES (?, ?, ?, ?)
        ''',
        [
          synthesis.nodeId,
          synthesis.entryId,
          WeeklySynthesisConfig.synthesisNodeKind,
          '${synthesis.headline} ${synthesis.summary}',
        ],
      );
    });
  }

  Future<List<Map<String, dynamic>>> fetchTaskNodeRows({
    DateTime? afterUpdatedAt,
    String? afterId,
    int limit = DatabaseConstants.defaultPageSize,
  }) async {
    if (limit <= 0) return const [];

    final query = select(reflectionGraphNodes)
      ..where((t) => t.kind.equals('next_action'));

    if (afterUpdatedAt != null && afterId != null) {
      final millis = afterUpdatedAt.toUtc().millisecondsSinceEpoch;
      query.where(
        (t) =>
            t.updatedAt.isSmallerThanValue(millis) |
            (t.updatedAt.equals(millis) & t.id.isSmallerThanValue(afterId)),
      );
    }

    query
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);

    final rows = await query.get();
    return rows
        .map(
          (row) => {
            'id': row.id,
            'entry_id': row.entryId,
            'kind': row.kind,
            'label': row.label,
            'payload_json': row.payloadJson,
            'updated_at': row.updatedAt,
          },
        )
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> loadNodeMetadataForEntries({
    required Set<String> entryIds,
    required int maxNodes,
  }) async {
    if (entryIds.isEmpty || maxNodes <= 0) return const [];

    final placeholders = List.filled(entryIds.length, '?').join(', ');
    final rows = await customSelect(
      '''
      SELECT id, entry_id, kind, label
      FROM $nodesTable
      WHERE entry_id IN ($placeholders)
      ORDER BY updated_at DESC
      LIMIT ?
      ''',
      variables: [
        ...entryIds.map(Variable<String>.new),
        Variable<int>(maxNodes),
      ],
      readsFrom: {reflectionGraphNodes},
    ).get();

    return rows.map((row) => row.data).toList();
  }

  List<String> _splitCsv(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
  }
}
