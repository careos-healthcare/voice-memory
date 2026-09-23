import 'package:archiveme_mobile/features/guided_entry/presentation/archive_template_materializer.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/archive_entry_template.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Writes a template page and its supporting moments into the journal SQLite mirror.
class ArchiveTemplateSqliteWriter {
  const ArchiveTemplateSqliteWriter(this._repository);

  final JournalSqliteRepository _repository;

  Future<ArchiveTemplateDraft> apply(
    ArchiveEntryTemplate template, {
    DateTime? now,
  }) async {
    final draft = ArchiveTemplateMaterializer.materialize(template, now: now);
    await _repository.upsertEntries(draft.entries);
    return draft;
  }
}
