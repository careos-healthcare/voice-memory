import 'package:archiveme_mobile/storage/sqlite/sqlite_vec_support.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vector_support.dart';
import 'package:sqflite/sqflite.dart';

/// Loads sqlite-vec / sqlite-vector extensions and prepares hybrid-search indexes.
abstract final class SqliteHybridSearchInitializer {
  SqliteHybridSearchInitializer._();

  static Future<void> initialize(Database db) async {
    SqliteVectorSupport.ensureLoaded();
    await SqliteVectorSupport.initTranscriptEmbeddingIndex(db);
    await SqliteVectorSupport.initReflectionEmbeddingIndex(db);

    SqliteVecSupport.ensureLoaded();
    await SqliteVecSupport.initVecChunks(db);
  }
}
