import 'dart:convert';

import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/features/sync/services/e2ee_journal_sync.dart';
import 'package:archiveme_mobile/features/sync/services/sync_conflict_resolver.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const passphrase = 'thoughtprint-sync-passphrase';

  JournalEntry entry({
    required String id,
    required DateTime updatedAt,
    required String transcript,
    SyncStatus syncStatus = SyncStatus.localOnly,
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 3, 8),
      transcript: transcript,
      durationSeconds: 4,
      reflection: const Reflection(
        mood: 'quiet',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      updatedAt: updatedAt,
      syncStatus: syncStatus,
    );
  }

  test(
    'encryptPayload hides the journal text and decrypts with the nonce',
    () async {
      final cipher = await E2eeJournalCipher.open(
        passphrase: passphrase,
        store: SaltStore(),
      );
      final row = entry(
        id: 'river',
        updatedAt: DateTime.utc(2026, 3, 8, 12),
        transcript: 'the river was high',
      );
      final sealed = await cipher.encryptEntry(row);

      expect(sealed.ciphertext.contains('the river was high'), isFalse);
      expect(sealed.ciphertext.contains(passphrase), isFalse);
      expect(sealed.nonce, isNotEmpty);

      final restored = await cipher.decryptEntry(
        sealed.ciphertext,
        sealed.nonce,
      );
      expect(restored.transcript, 'the river was high');
      expect(sealed.ciphertext.contains(passphrase), isFalse);
    },
  );

  test(
    'a newer server row replaces the local row and an older one is pushed',
    () async {
      final cipher = await E2eeJournalCipher.open(
        passphrase: passphrase,
        store: SaltStore(),
      );
      final local = entry(
        id: 'river',
        updatedAt: DateTime.utc(2026, 3, 8, 12),
        transcript: 'the river was high',
      );
      final remoteNewer = entry(
        id: 'river',
        updatedAt: DateTime.utc(2026, 3, 9, 12),
        transcript: 'the river fell overnight',
      );
      final pending = entry(
        id: 'market',
        updatedAt: DateTime.utc(2026, 3, 1),
        transcript: 'the market was loud',
        syncStatus: SyncStatus.pendingUpload,
      );
      final sealed = await cipher.encryptPayload(
        jsonEncode(remoteNewer.toJson()),
      );
      final saved = <JournalEntry>[];
      final pushed = <EncryptedJournalPush>[];

      final result = await E2eeDeltaSync.run(
        cloudSyncEnabled: true,
        lastSyncTime: DateTime.utc(2026, 3, 7),
        localEntries: [local, pending],
        remote: [
          RemoteEncryptedEntry(
            id: 'river',
            ciphertext: sealed.ciphertext,
            nonce: sealed.nonce,
            updatedAt: remoteNewer.updatedAt,
          ),
        ],
        encryptEntry: cipher.encryptEntry,
        decryptEntry: cipher.decryptEntry,
        saveLocal: (row) async => saved.add(row),
        push: (records) async => pushed.addAll(records),
      );

      expect(result.completed, isTrue);
      expect(saved.single.transcript, 'the river fell overnight');
      expect(pushed.map((row) => row.id), ['market']);
      expect(pushed.single.ciphertext.contains('the market was loud'), isFalse);
      expect(
        SyncConflictResolver.resolve(
          localUpdatedAt: local.updatedAt,
          remoteUpdatedAt: remoteNewer.updatedAt,
        ),
        SyncConflictAction.keepRemote,
      );
    },
  );

  test('the sync queue runs one job after another', () async {
    final queue = E2eeSyncQueue();
    final order = <int>[];
    final first = queue.enqueue(() async {
      order.add(1);
    });
    final second = queue.enqueue(() async {
      order.add(2);
    });
    await Future.wait([first, second]);
    expect(order, [1, 2]);
  });

  test('delta sync stays idle while cloud features are off', () async {
    var pushed = false;
    final result = await E2eeDeltaSync.run(
      cloudSyncEnabled: false,
      lastSyncTime: null,
      localEntries: [
        entry(
          id: 'river',
          updatedAt: DateTime.utc(2026, 3, 8),
          transcript: 'the river was high',
        ),
      ],
      remote: const [],
      encryptEntry: (_) async =>
          const E2eeCipherPayload(ciphertext: '', nonce: ''),
      decryptEntry: (_, _) async => entry(
        id: 'unused',
        updatedAt: DateTime.utc(2026, 3, 8),
        transcript: 'unused',
      ),
      saveLocal: (_) async {},
      push: (_) async => pushed = true,
    );
    expect(result.completed, isFalse);
    expect(pushed, isFalse);
  });
}
