import 'package:archiveme_mobile/features/insight_engine/hybrid_search_engine.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/image_attachment_embedding_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/pro_status_sqlite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSqliteDatabaseHolder {
  AppSqliteDatabase? value;
}

final appSqliteDatabaseHolderProvider = Provider<AppSqliteDatabaseHolder>(
  (ref) => AppSqliteDatabaseHolder(),
);

final appSqliteDatabaseProvider = Provider<AppSqliteDatabase>(
  (ref) {
    final db = ref.watch(appSqliteDatabaseHolderProvider).value;
    if (db == null) {
      throw StateError('AppSqliteDatabase has not been bound yet');
    }
    return db;
  },
);

final proStatusSqliteRepositoryProvider = Provider<ProStatusSqliteRepository>(
  (ref) => ProStatusSqliteRepository(ref.watch(appSqliteDatabaseProvider)),
);

final journalSqliteRepositoryProvider = Provider<JournalSqliteRepository>(
  (ref) => JournalSqliteRepository(ref.watch(appSqliteDatabaseProvider)),
);

final memoryTranscriptSearchRepositoryProvider =
    Provider<MemoryTranscriptSearchRepository>(
  (ref) => MemoryTranscriptSearchRepository(
    ref.watch(appSqliteDatabaseProvider),
  ),
);

final imageAttachmentEmbeddingRepositoryProvider =
    Provider<ImageAttachmentEmbeddingRepository>(
  (ref) => ImageAttachmentEmbeddingRepository(
    ref.watch(appSqliteDatabaseProvider),
  ),
);

final hybridSearchEngineProvider = Provider<HybridSearchEngine>(
  (ref) => HybridSearchEngine(
    repository: ref.watch(memoryTranscriptSearchRepositoryProvider),
    imageRepository: ref.watch(imageAttachmentEmbeddingRepositoryProvider),
  ),
);