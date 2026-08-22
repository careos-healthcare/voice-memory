import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/graph/domain/graph_topology.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_011_reflection_graph_fts.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_013_entry_edges.dart';

/// Loads graph topology via recursive SQLite CTEs without journal payloads.
class GraphRepository {
  GraphRepository(this._sqlite);

  final AppSqliteDatabase _sqlite;
  AppDatabase? _drift;

  AppDatabase get _db => _drift ??= AppDatabase.fromSqflite(_sqlite.database);

  static const nodesTable = Migration011ReflectionGraphFts.nodesTable;
  static const edgesTable = Migration013EntryEdges.edgesTable;

  /// Expands [seedEntryId] through [entry_edges] and loads reflection nodes.
  Future<GraphTopology> loadNeighborhood({
    required String seedEntryId,
    int maxDepth = 2,
    int maxNodes = 160,
  }) async {
    if (seedEntryId.isEmpty) {
      return const GraphTopology(nodes: [], links: []);
    }

    final entryIds = await _db.entryEdgesDao.recursiveEntryIds(
      seedEntryId: seedEntryId,
      maxDepth: maxDepth,
    );
    if (entryIds.isEmpty) {
      return GraphTopology(seedEntryId: seedEntryId, nodes: const [], links: const []);
    }

    final nodes = await _loadNodeMetadata(
      entryIds: entryIds,
      maxNodes: maxNodes,
    );
    if (nodes.isEmpty) {
      return GraphTopology(seedEntryId: seedEntryId, nodes: const [], links: const []);
    }

    final nodeEntryIds = nodes.map((node) => node.entryId).toSet();
    final entryLinks = await _loadEntryEdgeLinks(entryIds: nodeEntryIds);
    final reflectionLinks = _inferReflectionLinks(nodes);
    final semanticLinks = _mapEntryLinksToNodes(
      nodes: nodes,
      entryLinks: entryLinks,
    );

    return GraphTopology(
      seedEntryId: seedEntryId,
      nodes: nodes,
      links: [...reflectionLinks, ...semanticLinks],
    );
  }

  Future<List<GraphNodeRecord>> _loadNodeMetadata({
    required Set<String> entryIds,
    required int maxNodes,
  }) async {
    final rows = await _db.reflectionGraphDao.loadNodeMetadataForEntries(
      entryIds: entryIds,
      maxNodes: maxNodes,
    );

    return rows
        .map(GraphNodeRecord.fromRow)
        .where((node) => node.id.isNotEmpty && node.entryId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<_EntryEdgeRow>> _loadEntryEdgeLinks({
    required Set<String> entryIds,
  }) async {
    final rows = await _db.entryEdgesDao.loadEntryEdgeLinks(entryIds: entryIds);

    return rows
        .map(
          (row) => _EntryEdgeRow(
            sourceEntryId: row['source_entry_id'] as String? ?? '',
            targetEntryId: row['target_entry_id'] as String? ?? '',
            relation: row['relation'] as String? ??
                Migration013EntryEdges.relationSemanticSimilarity,
            weight: (row['weight'] as num?)?.toDouble() ?? 0,
          ),
        )
        .where(
          (edge) =>
              edge.sourceEntryId.isNotEmpty && edge.targetEntryId.isNotEmpty,
        )
        .toList(growable: false);
  }

  List<GraphLinkRecord> _inferReflectionLinks(List<GraphNodeRecord> nodes) {
    final grouped = <String, List<GraphNodeRecord>>{};
    for (final node in nodes) {
      grouped.putIfAbsent(node.entryId, () => []).add(node);
    }

    final links = <GraphLinkRecord>[];
    for (final entryNodes in grouped.values) {
      GraphNodeRecord? hub;
      for (final node in entryNodes) {
        if (node.kind == 'journal_entry') {
          hub = node;
          break;
        }
      }
      hub ??= entryNodes.isEmpty ? null : entryNodes.first;
      if (hub == null) continue;

      for (final node in entryNodes) {
        if (node.id == hub.id) continue;
        links.add(
          GraphLinkRecord(
            fromNodeId: hub.id,
            toNodeId: node.id,
            relation: _relationForKind(node.kind),
            weight: 1,
          ),
        );
      }
    }
    return links;
  }

  List<GraphLinkRecord> _mapEntryLinksToNodes({
    required List<GraphNodeRecord> nodes,
    required List<_EntryEdgeRow> entryLinks,
  }) {
    final hubByEntry = <String, GraphNodeRecord>{};
    for (final node in nodes) {
      if (node.kind != 'journal_entry') continue;
      hubByEntry.putIfAbsent(node.entryId, () => node);
    }
    for (final node in nodes) {
      hubByEntry.putIfAbsent(node.entryId, () => node);
    }

    final links = <GraphLinkRecord>[];
    final seen = <String>{};
    for (final edge in entryLinks) {
      final from = hubByEntry[edge.sourceEntryId];
      final to = hubByEntry[edge.targetEntryId];
      if (from == null || to == null || from.id == to.id) continue;
      final key = '${from.id}->${to.id}';
      if (!seen.add(key)) continue;
      links.add(
        GraphLinkRecord(
          fromNodeId: from.id,
          toNodeId: to.id,
          relation: edge.relation,
          weight: edge.weight,
        ),
      );
    }
    return links;
  }

  static String _relationForKind(String kind) {
    return switch (kind) {
      'tension' => 'has_tension',
      'next_action' => 'suggests_action',
      'theme' => 'mentions_theme',
      _ => 'related',
    };
  }
}

final class _EntryEdgeRow {
  const _EntryEdgeRow({
    required this.sourceEntryId,
    required this.targetEntryId,
    required this.relation,
    required this.weight,
  });

  final String sourceEntryId;
  final String targetEntryId;
  final String relation;
  final double weight;
}
