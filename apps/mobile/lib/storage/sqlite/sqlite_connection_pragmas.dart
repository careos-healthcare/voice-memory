import 'package:sqflite/sqflite.dart';

/// Performance-oriented SQLite PRAGMA defaults applied on every connection.
abstract final class SqliteConnectionPragmas {
  SqliteConnectionPragmas._();

  /// 4 KiB pages — balanced for mobile flash and read amplification.
  static const pageSize = 4096;

  /// Negative values are KiB; -65536 ≈ 64 MiB page cache.
  static const cacheSizeKiB = -65536;

  /// 256 MiB memory-mapped I/O budget for read-heavy local search.
  static const mmapSizeBytes = 268435456;

  /// Applies baseline durability + performance PRAGMAs.
  ///
  /// [page_size] only takes effect before the database file is first written.
  /// Existing files keep their on-disk page size; the statement is still safe.
  static Future<void> apply(Database database) async {
    await database.execute('PRAGMA page_size = $pageSize');
    await database.execute('PRAGMA cache_size = $cacheSizeKiB');
    await database.execute('PRAGMA mmap_size = $mmapSizeBytes');
    await database.execute('PRAGMA temp_store = MEMORY');
    await database.execute('PRAGMA journal_mode = WAL');
    await database.execute('PRAGMA synchronous = NORMAL');
    await database.execute('PRAGMA foreign_keys = ON');
  }
}
