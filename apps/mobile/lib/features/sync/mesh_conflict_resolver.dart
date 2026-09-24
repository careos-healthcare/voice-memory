/// One moment's vector version and the local entity-graph edits beside it.
class MeshEntryVersion {
  const MeshEntryVersion({
    required this.entryId,
    required this.updatedAt,
    required this.vectorGeneration,
    required this.entityEdgeIds,
  });

  final String entryId;
  final DateTime updatedAt;
  final int vectorGeneration;
  final List<String> entityEdgeIds;

  MeshEntryVersion copyWith({
    DateTime? updatedAt,
    int? vectorGeneration,
    List<String>? entityEdgeIds,
  }) {
    return MeshEntryVersion(
      entryId: entryId,
      updatedAt: updatedAt ?? this.updatedAt,
      vectorGeneration: vectorGeneration ?? this.vectorGeneration,
      entityEdgeIds: entityEdgeIds ?? this.entityEdgeIds,
    );
  }
}

/// Last-write-wins on the moment timestamp, keeping local graph edits.
abstract final class MeshConflictResolver {
  static MeshEntryVersion resolve({
    required MeshEntryVersion local,
    required MeshEntryVersion remote,
  }) {
    if (local.entryId != remote.entryId) {
      throw ArgumentError('Versions must share an entry id.');
    }
    if (!remote.updatedAt.isAfter(local.updatedAt)) return local;
    return local.copyWith(
      updatedAt: remote.updatedAt,
      vectorGeneration: remote.vectorGeneration,
      entityEdgeIds: local.entityEdgeIds,
    );
  }
}
