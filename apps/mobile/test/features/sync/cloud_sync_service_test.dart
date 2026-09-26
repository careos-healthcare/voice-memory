import 'package:archiveme_mobile/features/sync/journal_cloud_ledger_interceptor.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  JournalEntry entry(String transcript) {
    return JournalEntry(
      id: 'entry-1',
      createdAt: DateTime.utc(2026, 1, 2),
      transcript: transcript,
      durationSeconds: 8,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
  }

  test('upload stays on the device while cloud features are off', () async {
    final uploaded = <String>[];
    final service = CloudSyncService(
      isCloudSyncEnabled: () async => false,
      upload: (entryId, transcript, createdAt) async {
        uploaded.add('$entryId:$transcript');
      },
    );

    await service.uploadEntryToLedger(entry('I mentioned the river again.'));

    expect(uploaded, isEmpty);
  });

  test('upload posts the transcript when cloud features are on', () async {
    final uploaded = <String>[];
    final service = CloudSyncService(
      isCloudSyncEnabled: () async => true,
      upload: (entryId, transcript, createdAt) async {
        uploaded.add('$entryId:$transcript');
      },
    );

    await service.uploadEntryToLedger(entry('I mentioned the river again.'));

    expect(uploaded, ['entry-1:I mentioned the river again.']);
  });

  test('backfill sends each saved entry once cloud features are on', () async {
    final uploaded = <String>[];
    final service = CloudSyncService(
      isCloudSyncEnabled: () async => true,
      loadEntries: () async => [
        entry('First morning by the river.'),
        entry('Second morning by the river.'),
      ],
      upload: (entryId, transcript, createdAt) async {
        uploaded.add(transcript);
      },
    );

    await service.backfill();

    expect(uploaded, [
      'First morning by the river.',
      'Second morning by the river.',
    ]);
  });

  test('a forgotten label is left out of the cloud copy', () async {
    final uploaded = <String>[];
    final service = CloudSyncService(
      isCloudSyncEnabled: () async => true,
      forgottenLabels: () async => {'river'},
      upload: (entryId, transcript, createdAt) async {
        uploaded.add(transcript);
      },
    );

    await service.uploadEntryToLedger(entry('I mentioned the river again.'));

    expect(uploaded, ['I mentioned the again.']);
  });

  test('delete calls the server only when cloud features are on', () async {
    final removed = <String>[];
    final enabled = CloudSyncService(
      isCloudSyncEnabled: () async => true,
      remove: (entryId) async {
        removed.add(entryId);
      },
    );
    await enabled.deleteEntryFromLedger('entry-1');

    final disabled = CloudSyncService(
      isCloudSyncEnabled: () async => false,
      remove: (entryId) async {
        removed.add('off-$entryId');
      },
    );
    await disabled.deleteEntryFromLedger('entry-1');

    expect(removed, ['entry-1']);
  });

  test('a local deletion deletes the server copy when cloud is on', () async {
    final removed = <String>[];
    final service = CloudSyncService(
      isCloudSyncEnabled: () async => true,
      remove: (entryId) async {
        removed.add(entryId);
      },
    );
    await JournalCloudLedgerInterceptor(service: service).onEntrySaved(
      entry('I mentioned the river again.').markDeleted(),
    );
    expect(removed, ['entry-1']);
  });
}
