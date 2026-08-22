import 'dart:async';

import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/features/journal/data/journal_cursor_data_source.dart';
import 'package:archiveme_mobile/features/journal/providers/journal_entity_parse_pool.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SQLite cursor fetcher for paginated journal/task feeds.
final journalCursorDataSourceProvider = Provider<JournalCursorDataSource>(
  (ref) => JournalCursorDataSource(ref.watch(appSqliteDatabaseProvider)),
);

/// Background isolate pool for row JSON decoding and entity normalization.
final journalEntityParsePoolProvider = Provider<JournalEntityParsePool>((ref) {
  final pool = JournalEntityParsePool();
  ref.onDispose(() {
    unawaited(pool.dispose());
  });
  return pool;
});
