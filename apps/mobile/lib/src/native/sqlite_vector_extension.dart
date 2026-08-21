import 'dart:ffi';

import 'package:sqlite3/sqlite3.dart';

/// Native sqlite-vector entry point resolved via the app build hook asset.
@Native<Int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>)>(
  assetId: 'package:archiveme_mobile/src/native/sqlite_vector_extension.dart',
)
external int sqlite3_vector_init(
  Pointer<Void> db,
  Pointer<Void> pzErrMsg,
  Pointer<Void> pApi,
);

extension ArchiveMeSqliteVectorExtension on Sqlite3 {
  /// Loads the sqlite-vector extension bundled by [hook/build.dart].
  void loadSqliteVectorExtension() {
    ensureExtensionLoaded(
      SqliteExtension(
        Native.addressOf<
            NativeFunction<
                Int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>)>>(
          sqlite3_vector_init,
        ).cast(),
      ),
    );
  }
}
