import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/features/encrypted_sync/legacy_plaintext_migration_service.dart';
import 'package:archiveme_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_sync_api_client.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

void main() {
  group('LegacyPlaintextMigrationService', () {
    late Directory tempDir;
    late JournalStore journal;
    late MobilePrefsStore prefs;
    late FakeSyncApiClient syncApi;
    late LegacyPlaintextMigrationService migration;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('legacy_migration_');
      journal = await JournalStore.open('${tempDir.path}/journal.json');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      syncApi = FakeSyncApiClient();
      migration = LegacyPlaintextMigrationService(
        syncApi: syncApi,
        journal: journal,
        prefs: prefs,
        deviceIds: _FakeDeviceIds(),
        keyStore: InMemorySyncMasterKeyStore(),
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'is resumable and idempotent — completed migration is not re-run',
      () async {
        syncApi.legacyEntries = [
          JournalEntry(
            id: 'legacy-1',
            createdAt: DateTime.utc(2026),
            transcript: 'legacy plaintext',
            durationSeconds: 2,
            reflection: _reflection(),
          ),
        ];

        expect(await migration.isMigrationPending(), isTrue);
        await migration.runMigrationIfNeeded();

        final state = await prefs.readJsonMap(
          LegacyPlaintextMigrationService.stateKey,
        );
        expect(state?['status'], 'completed');
        expect(syncApi.listLegacyJournalCalls, 1);
        expect(syncApi.syncPushCalls, greaterThanOrEqualTo(1));
        expect(
          await prefs.readJsonMap(
            LegacyPlaintextMigrationService.eligibleDeletionKey,
          ),
          isNotNull,
        );

        syncApi.listLegacyJournalCalls = 0;
        syncApi.syncPushCalls = 0;
        await migration.runMigrationIfNeeded();
        expect(syncApi.listLegacyJournalCalls, 0);
        expect(syncApi.syncPushCalls, 0);
      },
    );

    test('throws when encrypted sync fails', () async {
      syncApi.legacyEntries = [
        JournalEntry(
          id: 'legacy-1',
          createdAt: DateTime.utc(2026),
          transcript: 'legacy plaintext',
          durationSeconds: 2,
          reflection: _reflection(),
        ),
      ];
      syncApi.onSyncPush = (_) async =>
          const ApiFailureResult(ApiFailureOffline());

      await expectLater(
        migration.runMigrationIfNeeded(),
        throwsA(isA<NetworkOfflineException>()),
      );
    });
  });
}

class _FakeDeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}