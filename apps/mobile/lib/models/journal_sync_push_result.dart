import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// One entry the server refused to accept out of a `POST /api/journal` batch.
class JournalEntryRejection {
  const JournalEntryRejection({
    required this.id,
    required this.reason,
    required this.message,
    this.winning,
  });

  factory JournalEntryRejection.fromJson(Map<String, dynamic> json) {
    return JournalEntryRejection(
      id: JsonConverters.stringOrEmpty(json['id']).isEmpty
          ? 'unknown'
          : JsonConverters.stringOrEmpty(json['id']),
      reason: JsonConverters.stringOrEmpty(json['reason']).isEmpty
          ? 'INVALID_ENTRY'
          : JsonConverters.stringOrEmpty(json['reason']),
      message: JsonConverters.stringOrEmpty(json['message']),
      winning: JsonConverters.nullableObject(
        json['winning'],
        JournalEntry.fromJson,
      ),
    );
  }

  final String id;
  final String reason;
  final String message;
  final JournalEntry? winning;
}

/// Parsed response body of `POST /api/journal`.
class JournalSyncPushResult {
  const JournalSyncPushResult({
    required this.accepted,
    required this.rejected,
    required this.upserted,
  });

  factory JournalSyncPushResult.fromJson(Map<String, dynamic> json) {
    final accepted = JsonConverters.stringList(json['accepted']);
    return JournalSyncPushResult(
      accepted: accepted,
      rejected: JsonConverters.objectList(
        json['rejected'],
        JournalEntryRejection.fromJson,
        field: 'rejected',
      ),
      upserted: JsonConverters.nullableInt(json['upserted']) ?? accepted.length,
    );
  }

  final List<String> accepted;
  final List<JournalEntryRejection> rejected;
  final int upserted;
}
