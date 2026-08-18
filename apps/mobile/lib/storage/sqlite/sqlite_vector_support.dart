import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/src/native/sqlite_vector_extension.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;

/// Loads the SQLite Vector extension when the platform supports it.
abstract final class SqliteVectorSupport {
  SqliteVectorSupport._();

  static bool _loadAttempted = false;
  static bool _available = false;

  /// True after a successful [ensureLoaded] on this process.
  static bool get isAvailable => _available;

  /// Loads sqlite-vector once. Safe to call repeatedly.
  static bool ensureLoaded() {
    if (_loadAttempted) return _available;
    _loadAttempted = true;
    try {
      sqlite3_lib.sqlite3.loadSqliteVectorExtension();
      _available = true;
    } on Object {
      _available = false;
    }
    return _available;
  }

  /// Initializes vector search on [Migration005HybridSearch.embeddingsTable].
  static Future<void> initTranscriptEmbeddingIndex(Database db) async {
    if (!ensureLoaded()) return;
    try {
      await db.execute(
        "SELECT vector_init('${Migration005HybridSearch.embeddingsTable}', "
        "'embedding', "
        "'type=FLOAT32,dimension=$localTranscriptEmbeddingDimensions')",
      );
    } on Object {
      // Extension unavailable on this SQLite build — blob + Dart fallback remains.
    }
  }
}
