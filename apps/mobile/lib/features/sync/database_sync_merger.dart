import 'package:archiveme_mobile/storage/sqlite/mesh_crdt_repository.dart';

export 'package:archiveme_mobile/storage/sqlite/mesh_crdt_repository.dart'
    show SyncChangelogEntry, SyncMergeResult;

/// Mesh entry point for [MeshCrdtRepository].
///
/// Conflict rules stay in the SQLite repository. This type only names the
/// local device that owns the writes.
class DatabaseSyncMerger extends MeshCrdtRepository {
  DatabaseSyncMerger({required super.database, required super.deviceId});
}
