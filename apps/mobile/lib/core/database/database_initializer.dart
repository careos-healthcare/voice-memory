import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vector_support.dart';
import 'package:sqflite/sqflite.dart' hide SqfliteDarwin;
import 'package:sqflite_darwin/sqflite_darwin.dart';

/// Loads sqlite-vec on the database opened by sqflite on Apple platforms.
///
/// [SqfliteDarwin] is the iOS and macOS database factory. The vec0 extension
/// is optional: a failed load keeps the embedding blob tables for similarity
/// ranking and does not fail database open.
abstract final class DatabaseInitializer {
  DatabaseInitializer._();

  static bool vecExtensionLoaded = false;

  /// Darwin plugin that owns the on-device SQLite connection.
  static Type get darwinFactory => SqfliteDarwin;

  /// Attempts to load sqlite-vec. Returns false when the binary is missing.
  static Future<bool> loadSqliteVec(Database database) async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        assert(
          darwinFactory == SqfliteDarwin,
          'sqflite_darwin must be the Apple database factory.',
        );
      }
      SqliteVectorSupport.ensureLoaded();
      await database.rawQuery('SELECT vec_version()');
      vecExtensionLoaded = true;
      return true;
    } on Object catch (error, stackTrace) {
      vecExtensionLoaded = false;
      AppLogger.error(
        'sqlite-vec extension failed to load. Similarity search will use the embedding blob tables.',
        name: 'sqlite-vec',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
