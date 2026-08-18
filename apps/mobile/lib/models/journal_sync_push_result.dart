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
    final winningJson = json['winning'];
    return JournalEntryRejection(
      id: json['id'] as String? ?? 'unknown',
      reason: json['reason'] as String? ?? 'INVALID_ENTRY',
      message: json['message'] as String? ?? '',
      winning: winningJson is Map
          ? JournalEntry.fromJson(Map<String, dynamic>.from(winningJson))
          : null,
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
    final acceptedRaw = json['accepted'] as List<dynamic>? ?? const [];
    final rejectedRaw = json['rejected'] as List<dynamic>? ?? const [];
    final accepted = acceptedRaw.map((e) => e as String).toList();
    return JournalSyncPushResult(
      accepted: accepted,
      rejected: rejectedRaw
          .map((e) => JournalEntryRejection.fromJson(e as Map<String, dynamic>))
          .toList(),
      upserted: (json['upserted'] as num?)?.toInt() ?? accepted.length,
    );
  }

  final List<String> accepted;
  final List<JournalEntryRejection> rejected;
  final int upserted;
}