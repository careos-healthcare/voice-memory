import 'package:archiveme_mobile/core/copy_with_unset.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'journal_sync_metadata.freezed.dart';

/// Sync, revision, and tombstone metadata for a [JournalEntry].
@Freezed(fromJson: false, toJson: false, copyWith: false)
abstract class JournalSyncMetadata with _$JournalSyncMetadata {
  const JournalSyncMetadata._();

  const factory JournalSyncMetadata.stored({
    @Default(SyncStatus.localOnly) SyncStatus syncStatus,
    required DateTime updatedAt,
    required int revision,
    required String changeId,
    DateTime? deletedAt,
    @Default(JournalSyncMetadata.currentSchemaVersion) int schemaVersion,
  }) = _JournalSyncMetadata;

  factory JournalSyncMetadata({
    SyncStatus syncStatus = SyncStatus.localOnly,
    DateTime? updatedAt,
    required DateTime createdAt,
    required String entryId,
    int? revision,
    String? changeId,
    DateTime? deletedAt,
    int? schemaVersion,
  }) {
    final resolvedRevision = (revision == null || revision < 1) ? 1 : revision;
    return JournalSyncMetadata.stored(
      syncStatus: syncStatus,
      updatedAt: (updatedAt ?? createdAt).toUtc(),
      revision: resolvedRevision,
      changeId: (changeId == null || changeId.isEmpty)
          ? JournalSyncIds.deterministicChangeId(
              id: entryId,
              createdAt: createdAt,
              revision: resolvedRevision,
            )
          : changeId,
      deletedAt: deletedAt,
      schemaVersion: schemaVersion ?? currentSchemaVersion,
    );
  }

  factory JournalSyncMetadata.fromJson(
    Map<String, dynamic> json, {
    required DateTime createdAt,
    required String entryId,
  }) {
    final revision = JsonConverters.nullableInt(json['revision']);
    final changeId = JsonConverters.nullableString(json['changeId']);
    return JournalSyncMetadata(
      syncStatus: _parseSync(JsonConverters.nullableString(json['_syncStatus'])),
      updatedAt: DateTime.tryParse(
        JsonConverters.stringOrEmpty(json['updatedAt']),
      ),
      createdAt: createdAt,
      entryId: entryId,
      revision: revision,
      changeId: changeId,
      deletedAt: DateTime.tryParse(
        JsonConverters.stringOrEmpty(json['deletedAt']),
      ),
      schemaVersion: JsonConverters.nullableInt(json['schemaVersion']),
    );
  }

  /// Bumped whenever the persisted-entry schema gains fields that older
  /// installs must migrate on read.
  static const int currentSchemaVersion = 3;

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
    '_syncStatus': _syncToString(syncStatus),
    'updatedAt': updatedAt.toIso8601String(),
    'revision': revision,
    'changeId': changeId,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  /// Preserves [entryId] and [createdAt] anchors used for legacy [changeId]
  /// derivation when constructing a fresh metadata object.
  JournalSyncMetadata copyWithAnchors({
    required DateTime createdAt,
    required String entryId,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    int? revision,
    String? changeId,
    Object? deletedAt = copyWithUnset,
    int? schemaVersion,
  }) => JournalSyncMetadata(
    syncStatus: syncStatus ?? this.syncStatus,
    updatedAt: updatedAt ?? this.updatedAt,
    createdAt: createdAt,
    entryId: entryId,
    revision: revision ?? this.revision,
    changeId: changeId ?? this.changeId,
    deletedAt: identical(deletedAt, copyWithUnset)
        ? this.deletedAt
        : deletedAt as DateTime?,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );

  static SyncStatus _parseSync(String? raw) {
    switch (raw) {
      case 'synced':
        return SyncStatus.synced;
      case 'pending':
        return SyncStatus.pendingUpload;
      default:
        return SyncStatus.localOnly;
    }
  }

  static String _syncToString(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.pendingUpload:
        return 'pending';
      default:
        return 'local';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalSyncMetadata &&
          other.syncStatus == syncStatus &&
          other.updatedAt == updatedAt &&
          other.revision == revision &&
          other.changeId == changeId &&
          other.deletedAt == deletedAt &&
          other.schemaVersion == schemaVersion;

  @override
  int get hashCode => Object.hash(
        syncStatus,
        updatedAt,
        revision,
        changeId,
        deletedAt,
        schemaVersion,
      );
}

/// Deterministic id generation used only for legacy-entry migration.
abstract class JournalSyncIds {
  JournalSyncIds._();

  static const _migrationNamespace = '6c9c53f2-6c39-4c7a-9b3a-9d2f9c8f3a11';

  static String newOfflineEntryId() => generateUlid();

  static bool isOfflineEntryId(String id) => isValidUlid(id);

  static String deterministicChangeId({
    required String id,
    required DateTime createdAt,
    required int revision,
  }) {
    return const Uuid().v5(
      _migrationNamespace,
      'archiveme-legacy:$id:${createdAt.toUtc().toIso8601String()}:$revision',
    );
  }
}
