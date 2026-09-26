import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';

/// Legacy whole-journal snapshot helpers. New sync seals one [SealedSyncRecord]
/// per entry. [migrateSnapshot] turns decrypted rows into those records.
abstract final class E2eeJournalSync {
  E2eeJournalSync._();

  static const blobId = 'journal-e2ee';
  static const blobType = 'journal_snapshot';

  /// Newer [JournalEntry.updatedAt] wins. A tie keeps the copy already on device.
  static JournalEntry lastWriteWins(JournalEntry local, JournalEntry incoming) {
    if (incoming.updatedAt.isAfter(local.updatedAt)) return incoming;
    return local;
  }

  static List<JournalEntry> mergeByUpdatedAt({
    required List<JournalEntry> local,
    required List<JournalEntry> remote,
  }) {
    final byId = {for (final entry in local) entry.id: entry};
    for (final incoming in remote) {
      final current = byId[incoming.id];
      byId[incoming.id] = current == null
          ? incoming
          : lastWriteWins(current, incoming);
    }
    return byId.values.toList();
  }

  static EntryFieldState fieldsFor(JournalEntry entry, String deviceId) {
    final when = entry.updatedAt;
    return EntryFieldState(
      transcript: entry.transcript,
      baseTranscript: entry.transcript,
      transcriptUpdatedAt: when,
      transcriptDeviceId: deviceId,
      title: entry.display.title ?? '',
      titleUpdatedAt: when,
      titleDeviceId: deviceId,
      mood: entry.reflection.mood,
      moodUpdatedAt: when,
      moodDeviceId: deviceId,
      place: entry.display.locationLabel ?? '',
      placeUpdatedAt: when,
      placeDeviceId: deviceId,
      tags: const [],
      tagsUpdatedAt: when,
      tagsDeviceId: deviceId,
    );
  }

  /// Upgrades a decrypted snapshot into per-entry records on the next sync.
  static Future<List<SealedSyncRecord>> migrateSnapshot({
    required List<int> accountKey,
    required List<JournalEntry> entries,
    required String deviceId,
  }) async {
    final records = <SealedSyncRecord>[];
    for (final entry in entries) {
      records.add(
        await RecordSync.sealEntry(
          accountKey: accountKey,
          recordId: entry.id,
          version: 1,
          deviceId: deviceId,
          state: fieldsFor(entry, deviceId),
        ),
      );
    }
    return records;
  }
}
