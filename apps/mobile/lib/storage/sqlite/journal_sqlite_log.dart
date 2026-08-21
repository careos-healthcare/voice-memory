import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';

/// Release-safe logging for local journal SQLite mirror queries.
abstract class JournalSqliteLog {
  JournalSqliteLog._();

  static void fetchPageFtsFallback({required Object error}) {
    ReleaseLogger.emit(
      event: 'journal_sqlite_fetch_page_fts_fallback',
      category: ReleaseLogCategory.storage,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'error_code': ReleaseLogSanitizer.errorCodeFromObject(error),
      },
    );
  }

  static void corruptPayloadJson({required String entryId}) {
    ReleaseLogger.emit(
      event: 'journal_sqlite_corrupt_payload',
      category: ReleaseLogCategory.storage,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'entry_id': ReleaseLogSanitizer.sanitizeReasonCode(entryId),
      },
    );
  }

  static void entryDataIssue({
    required String entryId,
    required String issue,
  }) {
    ReleaseLogger.emit(
      event: 'journal_sqlite_entry_data_issue',
      category: ReleaseLogCategory.storage,
      severity: ReleaseLogSeverity.warn,
      fields: {
        'entry_id': ReleaseLogSanitizer.sanitizeReasonCode(entryId),
        'issue': ReleaseLogSanitizer.sanitizeReasonCode(issue),
      },
    );
  }
}
