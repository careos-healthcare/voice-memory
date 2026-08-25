import 'package:archiveme_mobile/models/journal_entry.dart';

/// Reason a journal record failed strict decoding.
enum JournalDecodeIssue {
  emptyId,
  invalidCreatedAt,
  defaultedTimestamp,
  invalidUpdatedAt,
  invalidRevision,
  unsupportedSchemaVersion,
  invalidSyncStatus,
  invalidTombstone,
  malformedMap,
  malformedReflection,
  parseException,
}

/// Result of decoding one journal record from persisted JSON.
sealed class JournalDecodeResult {
  const JournalDecodeResult();
}

final class JournalDecodeAccepted extends JournalDecodeResult {
  const JournalDecodeAccepted(this.entry);
  final JournalEntry entry;
}

final class JournalDecodeQuarantined extends JournalDecodeResult {
  const JournalDecodeQuarantined(this.issues, {this.rawId});
  final List<JournalDecodeIssue> issues;
  final String? rawId;
}

/// Strict, versioned journal entry decoder — invalid records are quarantined
/// instead of aborting the entire archive load.
abstract final class JournalEntryDecoder {
  JournalEntryDecoder._();

  static const int supportedSchemaVersion = JournalEntry.currentSchemaVersion;

  static JournalDecodeResult decodeRecord(Map<String, dynamic> json) {
    final issues = <JournalDecodeIssue>[];

    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      issues.add(JournalDecodeIssue.emptyId);
    }

    final createdAtRaw = json['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is! String) {
      issues.add(JournalDecodeIssue.invalidCreatedAt);
    } else {
      createdAt = DateTime.tryParse(createdAtRaw)?.toUtc();
      if (createdAt == null) {
        issues.add(JournalDecodeIssue.invalidCreatedAt);
      }
    }

    final updatedAtRaw = json['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtRaw == null) {
      issues.add(JournalDecodeIssue.defaultedTimestamp);
    } else if (updatedAtRaw is! String) {
      issues.add(JournalDecodeIssue.invalidUpdatedAt);
    } else {
      updatedAt = DateTime.tryParse(updatedAtRaw)?.toUtc();
      if (updatedAt == null) {
        issues.add(JournalDecodeIssue.invalidUpdatedAt);
      }
    }

    final revisionRaw = json['revision'];
    if (revisionRaw != null && revisionRaw is! int) {
      issues.add(JournalDecodeIssue.invalidRevision);
    } else if (revisionRaw is int && revisionRaw < 1) {
      issues.add(JournalDecodeIssue.invalidRevision);
    }

    final schemaRaw = json['schemaVersion'];
    if (schemaRaw is int && schemaRaw > supportedSchemaVersion) {
      issues.add(JournalDecodeIssue.unsupportedSchemaVersion);
    }

    final syncRaw = json['_syncStatus'] ?? json['syncStatus'];
    if (syncRaw != null &&
        syncRaw is String &&
        !{'synced', 'pending', 'local'}.contains(syncRaw)) {
      issues.add(JournalDecodeIssue.invalidSyncStatus);
    }

    final deletedAtRaw = json['deletedAt'];
    if (deletedAtRaw != null) {
      if (deletedAtRaw is! String || DateTime.tryParse(deletedAtRaw) == null) {
        issues.add(JournalDecodeIssue.invalidTombstone);
      }
    }

    final reflectionRaw = json['reflection'];
    if (reflectionRaw != null && reflectionRaw is! Map) {
      issues.add(JournalDecodeIssue.malformedReflection);
    }

    if (issues.isNotEmpty) {
      return JournalDecodeQuarantined(issues, rawId: id is String ? id : null);
    }

    try {
      final entry = JournalEntry.fromJson(json);
      if (entry.id.trim().isEmpty) {
        return const JournalDecodeQuarantined([JournalDecodeIssue.emptyId]);
      }
      return JournalDecodeAccepted(entry);
    } on Object catch (_, stackTrace) {
      return JournalDecodeQuarantined(const [
        JournalDecodeIssue.parseException,
      ], rawId: id is String ? id : null);
    }
  }

  static List<JournalEntry> decodeList(
    List<dynamic> raw, {
    List<JournalDecodeQuarantined>? quarantineOut,
  }) {
    final accepted = <JournalEntry>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        quarantineOut?.add(
          const JournalDecodeQuarantined([JournalDecodeIssue.malformedMap]),
        );
        continue;
      }
      final result = decodeRecord(item);
      switch (result) {
        case JournalDecodeAccepted(:final entry):
          accepted.add(entry);
        case JournalDecodeQuarantined():
          quarantineOut?.add(result);
      }
    }
    accepted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return accepted;
  }
}