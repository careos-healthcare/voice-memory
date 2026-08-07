import '../../models/journal_entry.dart';

/// Schema version for mobile encrypted archive-core payloads.
/// Matches web [SYNC_SCHEMA_VERSION] where possible.
abstract final class EncryptedSyncSchema {
  static const int version = 2;
  static const String coreBlobId = 'archive-core';
  static const String coreBlobType = 'journal_snapshot';
}

/// Builds a SyncContinuityModel-compatible JSON map from local journal entries.
/// Mobile V1 ships entries only; other domains are empty defaults so web can
/// merge without losing its richer continuity fields on cross-device restore.
Map<String, dynamic> buildEncryptedJournalSnapshot({
  required String deviceId,
  required String accountNamespace,
  required List<JournalEntry> entries,
  required DateTime updatedAt,
  DateTime? lastSyncedAt,
}) {
  final isoUpdated = updatedAt.toUtc().toIso8601String();
  return {
    'envelope': {
      'schemaVersion': EncryptedSyncSchema.version,
      'deviceId': deviceId,
      'updatedAt': isoUpdated,
      'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
    },
    'entries': entries
        .map(
          (entry) => {
            'entry': entry.toJson(),
            'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
            'sourceDeviceId': deviceId,
          },
        )
        .toList(),
    'audioMetadata': <Map<String, dynamic>>[],
    'photoMetadata': <Map<String, dynamic>>[],
    'bookmarks': <Map<String, dynamic>>[],
    'settings': {
      'reminders': {
        'dailyReflection': false,
        'afterStressfulEntry': false,
        'weeklyReview': false,
        'inactiveThreeDays': false,
        'preferredReflectionHour': 20,
      },
      'reflectionGoal': {'targetPerWeek': 3},
      'listeningMode': false,
      'fullDetail': false,
      'updatedAt': isoUpdated,
      'sourceDeviceId': deviceId,
    },
    'reviews': <Map<String, dynamic>>[],
    'localEvents': <Map<String, dynamic>>[],
    'emotionalContinuity': null,
    'debugEventsAllowed': false,
  };
}

/// Extracts journal entries from a decrypted archive-core snapshot.
List<JournalEntry> journalEntriesFromSnapshot(Map<String, dynamic> snapshot) {
  final rawEntries = snapshot['entries'];
  if (rawEntries is! List) return const [];
  final parsed = <JournalEntry>[];
  for (final item in rawEntries) {
    if (item is! Map<String, dynamic>) continue;
    final entryJson = item['entry'];
    if (entryJson is! Map<String, dynamic>) continue;
    try {
      parsed.add(JournalEntry.fromJson(entryJson));
    } catch (_) {
      // Skip corrupt records — caller verifies coverage separately.
    }
  }
  return parsed;
}
