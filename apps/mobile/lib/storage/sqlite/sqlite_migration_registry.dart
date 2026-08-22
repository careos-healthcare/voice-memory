import 'package:archiveme_mobile/storage/sqlite/migrations/migration_001_user_relationships.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_002_fact_ledger.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_003_account_pro_status.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_004_journal_entries.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_006_image_embeddings.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_007_journal_payload_slim.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_008_sync_outbox.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_009_reflection_embeddings.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_010_quick_capture_outbox.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_011_reflection_graph_fts.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_012_sync_outbox_retry_schedule.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_013_entry_edges.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_014_embedding_deferred_queue.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_015_vec_chunks.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_016_audio_processing_queue.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_017_capture_audio_metadata.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_018_transcript_provenance.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';

/// Ordered, validated catalog of [SqliteMigration] steps for the local DB.
class SqliteMigrationRegistry {
  SqliteMigrationRegistry([List<SqliteMigration>? migrations])
      : migrations = List.unmodifiable(migrations ?? defaultMigrations) {
    _validate();
  }

  static final List<SqliteMigration> defaultMigrations = [
    Migration001UserRelationships(),
    Migration002FactLedger(),
    Migration003AccountProStatus(),
    Migration004JournalEntries(),
    Migration005HybridSearch(),
    Migration006ImageEmbeddings(),
    Migration007JournalPayloadSlim(),
    Migration008SyncOutbox(),
    Migration009ReflectionEmbeddings(),
    Migration010QuickCaptureOutbox(),
    Migration011ReflectionGraphFts(),
    Migration012SyncOutboxRetrySchedule(),
    Migration013EntryEdges(),
    Migration014EmbeddingDeferredQueue(),
    Migration015VecChunks(),
    Migration016AudioProcessingQueue(),
    Migration017CaptureAudioMetadata(),
    Migration018TranscriptProvenance(),
  ];

  static int get latestVersion =>
      defaultMigrations.isEmpty ? 0 : defaultMigrations.last.version;

  final List<SqliteMigration> migrations;

  SqliteMigration? migrationForVersion(int version) {
    for (final migration in migrations) {
      if (migration.version == version) {
        return migration;
      }
    }
    return null;
  }

  /// Pending steps with `version` greater than [appliedVersion], ascending.
  List<SqliteMigration> pendingAfter(int appliedVersion) {
    return migrations.where((m) => m.version > appliedVersion).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
  }

  void _validate() {
    if (migrations.isEmpty) {
      throw StateError('SqliteMigrationRegistry requires at least one migration');
    }

    final seenVersions = <int>{};
    final seenIds = <String>{};
    var expectedVersion = 1;

    for (final migration in migrations) {
      if (migration.version != expectedVersion) {
        throw StateError(
          'Migration versions must be sequential starting at 1; '
          'expected $expectedVersion but found ${migration.version} (${migration.id})',
        );
      }
      if (!seenVersions.add(migration.version)) {
        throw StateError('Duplicate migration version ${migration.version}');
      }
      if (!seenIds.add(migration.id)) {
        throw StateError('Duplicate migration id ${migration.id}');
      }
      expectedVersion++;
    }
  }
}
