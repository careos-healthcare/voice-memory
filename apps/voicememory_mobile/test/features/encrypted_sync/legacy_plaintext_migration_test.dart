import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/data/network/api_client_sync_adapter.dart';
import 'package:voicememory_mobile/features/encrypted_sync/legacy_plaintext_migration_service.dart';
import 'package:voicememory_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

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
    late _MigrationApi api;
    late LegacyPlaintextMigrationService migration;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('legacy_migration_');
      journal = await JournalStore.open('${tempDir.path}/journal.json');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      api = _MigrationApi();
      migration = LegacyPlaintextMigrationService(
        api: api,
        syncApi: ApiClientSyncAdapter(api),
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
        api.legacyEntries = [
          JournalEntry(
            id: 'legacy-1',
            createdAt: DateTime.utc(2026, 1, 1),
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
        expect(api.listJournalCalls, 1);
        expect(api.syncPushCalls, greaterThanOrEqualTo(1));
        expect(
          await prefs.readJsonMap(
            LegacyPlaintextMigrationService.eligibleDeletionKey,
          ),
          isNotNull,
        );

        await migration.runMigrationIfNeeded();
        expect(
          api.listJournalCalls,
          1,
          reason: 'must not re-read legacy plaintext',
        );
      },
    );

    test(
      'does not delete server plaintext — only marks eligible for audit',
      () async {
        api.legacyEntries = [
          JournalEntry(
            id: 'legacy-2',
            createdAt: DateTime.utc(2026, 1, 2),
            transcript: 'keep on server until audit',
            durationSeconds: 1,
            reflection: _reflection(),
          ),
        ];

        await migration.runMigrationIfNeeded();

        expect(api.deleteJournalCalls, 0);
        final eligible = await prefs.readJsonMap(
          LegacyPlaintextMigrationService.eligibleDeletionKey,
        );
        expect(eligible?['legacyRowCount'], 1);
      },
    );

    test(
      'pending_retry when validated legacy rows cannot be merged locally',
      () async {
        api.legacyEntries = [
          JournalEntry(
            id: 'future-entry',
            createdAt: DateTime.now().add(const Duration(days: 400)),
            transcript: 'future dated',
            durationSeconds: 1,
            reflection: _reflection(),
          ),
        ];

        await migration.runMigrationIfNeeded();

        final state = await prefs.readJsonMap(
          LegacyPlaintextMigrationService.stateKey,
        );
        expect(state?['status'], 'pending_retry');
        expect(
          await prefs.readJsonMap(
            LegacyPlaintextMigrationService.eligibleDeletionKey,
          ),
          isNull,
        );
      },
    );
  });
}

class _MigrationApi extends ApiClient {
  _MigrationApi() : super(baseUrl: 'http://test.invalid');

  List<JournalEntry> legacyEntries = [];
  var listJournalCalls = 0;
  var syncPushCalls = 0;
  var deleteJournalCalls = 0;

  @override
  Future<List<JournalEntry>> listJournal() async {
    listJournalCalls++;
    return List<JournalEntry>.from(legacyEntries);
  }

  @override
  Future<Map<String, dynamic>> syncPush(Map<String, dynamic> body) async {
    syncPushCalls++;
    return {
      'ok': true,
      'manifest': {'blobs': []},
    };
  }

  @override
  Future<Map<String, dynamic>> syncPull() async => {'blobs': []};
}

class _FakeDeviceIds extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}
