import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/sync/journal_sync_conflict_resolver.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/journal_sync_metadata.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

void main() {
  test('newer updatedAt wins independent of createdAt', () {
    final result = JournalSyncConflictResolver.merge(
      localEntries: [
        _entry(
          transcript: 'local',
          createdAt: DateTime.utc(2026, 7, 20),
          updatedAt: DateTime.utc(2026, 7, 21),
          deviceId: 'device-a',
        ),
      ],
      remoteEntries: [
        _entry(
          transcript: 'remote',
          createdAt: DateTime.utc(2026, 1),
          updatedAt: DateTime.utc(2026, 7, 22),
          deviceId: 'device-b',
        ),
      ],
      localDeviceId: 'device-a',
    );

    expect(result.entries.single.transcript, 'remote');
    expect(result.entries.single.syncStatus, SyncStatus.synced);
    expect(result.collisions, hasLength(1));
  });

  test('dominating vector clock wins before wall-clock timestamp', () {
    final result = JournalSyncConflictResolver.merge(
      localEntries: [
        _entry(
          transcript: 'local later clock time',
          updatedAt: DateTime.utc(2026, 7, 25),
          deviceId: 'device-a',
          vectorClock: const {'device-a': 2, 'device-b': 1},
        ),
      ],
      remoteEntries: [
        _entry(
          transcript: 'remote causally newer',
          updatedAt: DateTime.utc(2026, 7, 20),
          deviceId: 'device-b',
          vectorClock: const {'device-a': 2, 'device-b': 2},
        ),
      ],
      localDeviceId: 'device-a',
    );

    expect(result.entries.single.transcript, 'remote causally newer');
    expect(
      result.collisions.single.vectorClockRelation,
      VectorClockRelation.isDominated,
    );
  });

  test('concurrent clocks fall back to deterministic LWW tie breakers', () {
    final left = _entry(
      transcript: 'from a',
      updatedAt: DateTime.utc(2026, 7, 25),
      deviceId: 'device-a',
      vectorClock: const {'device-a': 2},
    );
    final right = _entry(
      transcript: 'from b',
      updatedAt: DateTime.utc(2026, 7, 25),
      deviceId: 'device-b',
      vectorClock: const {'device-b': 2},
    );

    final first = JournalSyncConflictResolver.merge(
      localEntries: [left],
      remoteEntries: [right],
      localDeviceId: 'device-a',
    );
    final reversed = JournalSyncConflictResolver.merge(
      localEntries: [right],
      remoteEntries: [left],
      localDeviceId: 'device-b',
    );

    expect(first.entries.single.transcript, 'from b');
    expect(reversed.entries.single.transcript, 'from b');
    expect(
      first.collisions.single.vectorClockRelation,
      VectorClockRelation.concurrent,
    );
  });

  test('remote winner preserves device-only audio and capture context', () {
    final local = _entry(
      transcript: 'local',
      updatedAt: DateTime.utc(2026, 7, 20),
      deviceId: 'device-a',
      localAudioPath: '/private/local.m4a',
    );
    final remote = _entry(
      transcript: 'remote',
      updatedAt: DateTime.utc(2026, 7, 21),
      deviceId: 'device-b',
    );

    final result = JournalSyncConflictResolver.merge(
      localEntries: [local],
      remoteEntries: [remote],
      localDeviceId: 'device-a',
    );

    expect(result.entries.single.transcript, 'remote');
    expect(result.entries.single.localAudioPath, '/private/local.m4a');
  });

  test('remote winner preserves the local encrypted audio reference', () {
    final local = _entry(
      transcript: 'local',
      updatedAt: DateTime.utc(2026, 7, 20),
      deviceId: 'device-a',
      localAudioVaultRef: 'av1:local.m4a.enc',
    );
    final remote = _entry(
      transcript: 'remote',
      updatedAt: DateTime.utc(2026, 7, 21),
      deviceId: 'device-b',
    );

    final result = JournalSyncConflictResolver.merge(
      localEntries: [local],
      remoteEntries: [remote],
      localDeviceId: 'device-a',
    );

    expect(result.entries.single.transcript, 'remote');
    expect(result.entries.single.localAudioVaultRef, 'av1:local.m4a.enc');
  });

  test('manifest round trip preserves revision comparison metadata', () {
    final manifest = JournalSyncManifest.fromEntries(
      entries: [
        _entry(
          transcript: 'manifest',
          updatedAt: DateTime.utc(2026, 7, 25),
          deviceId: 'device-a',
          vectorClock: const {'device-a': 3},
        ),
      ],
      deviceId: 'device-a',
      generatedAt: DateTime.utc(2026, 7, 26),
      version: 4,
    );

    final decoded = JournalSyncManifest.fromJson(manifest.toJson());
    expect(decoded.version, 4);
    expect(decoded.entries['shared']?.sourceDeviceId, 'device-a');
    expect(decoded.entries['shared']?.vectorClock, const {'device-a': 3});
    expect(decoded.entries['shared']?.contentHash, isNotEmpty);
  });
}

JournalEntry _entry({
  required String transcript,
  required DateTime updatedAt,
  required String deviceId,
  DateTime? createdAt,
  Map<String, int> vectorClock = const <String, int>{},
  String? localAudioPath,
  String? localAudioVaultRef,
}) {
  return JournalEntry(
    id: 'shared',
    createdAt: createdAt ?? DateTime.utc(2026, 1),
    transcript: transcript,
    durationSeconds: 1,
    reflection: const Reflection(
      mood: 'steady',
      emotionalIntensity: 1,
      recurringThemes: <String>[],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.pendingUpload,
    localAudioPath: localAudioPath,
    localAudioVaultRef: localAudioVaultRef,
    syncMetadata: JournalSyncMetadata(
      updatedAt: updatedAt,
      sourceDeviceId: deviceId,
      vectorClock: vectorClock,
    ),
  );
}
