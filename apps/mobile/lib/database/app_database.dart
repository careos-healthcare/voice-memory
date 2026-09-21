import 'package:archiveme_mobile/database/daos/account_dao.dart';
import 'package:archiveme_mobile/database/daos/entry_edges_dao.dart';
import 'package:archiveme_mobile/database/daos/fact_ledger_dao.dart';
import 'package:archiveme_mobile/database/daos/journal_dao.dart';
import 'package:archiveme_mobile/database/daos/queue_dao.dart';
import 'package:archiveme_mobile/database/daos/reflection_graph_dao.dart';
import 'package:archiveme_mobile/database/daos/search_custom_queries.dart';
import 'package:archiveme_mobile/database/daos/transcript_embeddings_dao.dart';
import 'package:archiveme_mobile/database/executor/wrapped_sqflite_executor.dart';
import 'package:archiveme_mobile/database/tables/account_tables.dart';
import 'package:archiveme_mobile/database/tables/embedding_tables.dart';
import 'package:archiveme_mobile/database/tables/entry_edges.dart';
import 'package:archiveme_mobile/database/tables/fact_ledger.dart';
import 'package:archiveme_mobile/database/tables/journal_entries.dart';
import 'package:archiveme_mobile/database/tables/queue_tables.dart';
import 'package:archiveme_mobile/database/tables/reflection_embeddings.dart';
import 'package:archiveme_mobile/database/tables/reflection_graph_nodes.dart';
import 'package:archiveme_mobile/database/tables/sync_outbox.dart';
import 'package:drift/drift.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

export 'package:archiveme_mobile/database/daos/account_dao.dart';
export 'package:archiveme_mobile/database/daos/entry_edges_dao.dart';
export 'package:archiveme_mobile/database/daos/fact_ledger_dao.dart';
export 'package:archiveme_mobile/database/daos/journal_dao.dart';
export 'package:archiveme_mobile/database/daos/queue_dao.dart';
export 'package:archiveme_mobile/database/daos/reflection_graph_dao.dart';
export 'package:archiveme_mobile/database/daos/search_custom_queries.dart';
export 'package:archiveme_mobile/database/daos/transcript_embeddings_dao.dart';
export 'package:archiveme_mobile/database/executor/wrapped_sqflite_executor.dart';
export 'package:archiveme_mobile/database/tables/account_tables.dart';
export 'package:archiveme_mobile/database/tables/embedding_tables.dart';
export 'package:archiveme_mobile/database/tables/entry_edges.dart';
export 'package:archiveme_mobile/database/tables/fact_ledger.dart';
export 'package:archiveme_mobile/database/tables/journal_entries.dart';
export 'package:archiveme_mobile/database/tables/queue_tables.dart';
export 'package:archiveme_mobile/database/tables/reflection_embeddings.dart';
export 'package:archiveme_mobile/database/tables/reflection_graph_nodes.dart';
export 'package:archiveme_mobile/database/tables/sync_outbox.dart';

part 'app_database.g.dart';

/// Per-isolate cache so repeated calls to [AppDatabase.fromSqflite] for the
/// same underlying [sqflite.Database] return the same wrapper instead of
/// each building its own drift [GeneratedDatabase] around one executor —
/// drift's own docs treat that as a real corruption risk, not cosmetic.
/// Expando state is per-isolate (isolates don't share heaps), so this is
/// automatically safe for code that constructs its own AppDatabase inside
/// a worker isolate — it gets its own independent cache, never this one.
final Expando<AppDatabase> _appDatabaseCache = Expando<AppDatabase>(
  'AppDatabase.fromSqflite cache',
);

/// Unified Drift access layer for all account-scoped SQLite tables.
///
/// Physical schema creation remains in [SqliteMigrationManager]; this database
/// opens read/write against the existing sqflite handle for type-safe queries.
@DriftDatabase(
  tables: [
    JournalEntries,
    SyncOutboxEntries,
    ReflectionEmbeddings,
    ReflectionGraphNodes,
    AppSqliteMeta,
    EntryEdges,
    FactLedgerEntries,
    AccountIdentities,
    UserRelationships,
    AccountProStatus,
    MemoryTranscriptEmbeddings,
    JournalImageEmbeddings,
    QuickCaptureOutboxEntries,
    EmbeddingDeferredQueueEntries,
    AudioProcessingQueueEntries,
    CaptureAudioMetadataEntries,
  ],
  daos: [
    JournalDao,
    ReflectionGraphDao,
    FactLedgerDao,
    EntryEdgesDao,
    AccountDao,
    QueueDao,
    TranscriptEmbeddingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.fromSqflite(sqflite.Database db) {
    final cached = _appDatabaseCache[db];
    if (cached != null) return cached;
    final created = AppDatabase(WrappedSqfliteExecutor(db));
    _appDatabaseCache[db] = created;
    return created;
  }

  SearchCustomQueries? _searchCustomQueries;

  /// FTS5 / vec0 queries that require [customSelect].
  SearchCustomQueries get searchCustomQueries =>
      _searchCustomQueries ??= SearchCustomQueries(this);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {},
    onUpgrade: (Migrator m, int from, int to) async {},
  );
}

/// Legacy alias retained while call sites migrate to [AppDatabase].
typedef JournalDatabase = AppDatabase;
