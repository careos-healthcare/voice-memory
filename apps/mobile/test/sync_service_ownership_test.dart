import 'dart:io';

import 'package:archiveme_mobile/features/encrypted_sync/sync_master_key_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/services/journal_ownership_guard.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/encrypted_sync_test_helpers.dart';
import 'helpers/test_sync_service.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

JournalEntry _entry({required String id, String? ownerKey}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026),
  transcript: 'entry $id',
  durationSeconds: 5,
  reflection: _reflection(),
  ownerKey: ownerKey,
);

void main() {
  test(
    'syncNow never uploads entries owned by a different account after an '
    'account switch is detected (P0 — cross-account archive leakage)',
    () async {
      final dir = Directory.systemTemp.createTempSync('vm_sync_ownership_');
      final journal = await JournalStore.open(
        '${dir.path}/journal.json',
        encryptAtRest: false,
      );
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');

      await journal.save(_entry(id: 'a', ownerKey: 'user-a'));
      journal.setActiveOwnerKey('user-b');
      await journal.save(_entry(id: 'b', ownerKey: 'user-b'));

      await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, 'user-b');
      await prefs.writeBool(
        JournalOwnershipGuard.migrationPendingPrefsKey,
        true,
      );

      final keyStore = InMemorySyncMasterKeyStore();
      final syncApi = RecordingSyncApiClient(
        keyStore: keyStore,
        accountNamespace: 'user-b',
      );

      final sync = await createTestSyncService(
        syncApi: syncApi,
        journal: journal,
        prefs: prefs,
        keyStore: keyStore,
      );
      final result = await sync.syncNow();

      expect(syncApi.lastPushedEntryIds, ['b']);
      expect(syncApi.lastPushedEntryIds, isNot(contains('a')));
      expect(result.pushed, 1);
      expect(result.syncNote, contains('1 entry'));

      final stillLocal = await journal.getById('a');
      expect(stillLocal?.syncStatus, SyncStatus.localOnly);
      final synced = await journal.getById('b');
      expect(synced?.syncStatus, SyncStatus.synced);
    },
  );

  test('syncNow uploads unowned legacy entries normally when no account switch '
      'has ever been detected on this device', () async {
    final dir = Directory.systemTemp.createTempSync('vm_sync_ownership_');
    final journal = await JournalStore.open(
      '${dir.path}/journal.json',
      encryptAtRest: false,
    );
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');

    await journal.save(_entry(id: 'legacy'));

    await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, 'user-a');
    await prefs.writeBool(
      JournalOwnershipGuard.migrationPendingPrefsKey,
      false,
    );

    final keyStore = InMemorySyncMasterKeyStore();
    final syncApi = RecordingSyncApiClient(
      keyStore: keyStore,
      accountNamespace: 'user-a',
    );

    final sync = await createTestSyncService(
      syncApi: syncApi,
      journal: journal,
      prefs: prefs,
      keyStore: keyStore,
    );
    final result = await sync.syncNow();

    expect(syncApi.lastPushedEntryIds, ['legacy']);
    expect(result.syncNote, isNull);
  });
}