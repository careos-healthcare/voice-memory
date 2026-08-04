import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/sync_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

const _reflection = Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

void main() {
  setUpAll(AppConfig.initApiResolution);

  test('sync requires an authenticated encrypted archive boundary', () async {
    final fixture = await _fixture('auth');
    final result = await SyncService(
      _EncryptedSyncApiClient(),
      fixture.store,
      fixture.prefs,
    ).syncNow();

    expect(result.cloudSyncSucceeded, isFalse);
    expect(result.message, contains('Sign in'));
  });

  test('sync pushes ciphertext without plaintext journal fields', () async {
    final fixture = await _fixture('push');
    await fixture.store.replaceAll([
      JournalEntry(
        id: 'entry-1',
        ownerArchiveId: 'account-1',
        createdAt: DateTime.utc(2026, 8),
        transcript: 'private exact words',
        durationSeconds: 1,
        reflection: _reflection,
        syncStatus: SyncStatus.pendingUpload,
      ),
    ]);
    final api = _EncryptedSyncApiClient();
    final key = List<int>.generate(32, (index) => index);

    final result = await SyncService(
      api,
      fixture.store,
      fixture.prefs,
      archiveIdentityProvider: () => _identity,
      keyProvider: (_) async => [...key],
      deviceIdProvider: () async => 'device-1',
    ).syncNow();

    expect(result.cloudSyncSucceeded, isTrue);
    expect(result.pushed, 1);
    final encoded = jsonEncode(api.pushedBody);
    expect(encoded, isNot(contains('private exact words')));
    expect(encoded, isNot(contains('"transcript"')));
    expect(encoded, contains('"journal_snapshot"'));
  });

  test('offline encrypted pull remains retryable and local-only', () async {
    final fixture = await _fixture('offline');
    final result = await SyncService(
      _OfflineEncryptedSyncApiClient(),
      fixture.store,
      fixture.prefs,
      archiveIdentityProvider: () => _identity,
      keyProvider: (_) async => List<int>.filled(32, 7),
    ).syncNow();

    expect(result.cloudSyncSucceeded, isFalse);
    expect(result.pushed, 0);
    expect(result.pulled, 0);
  });
}

const _identity = LocalArchiveIdentity(
  archiveId: 'account-1',
  ownerKind: LocalArchiveOwnerKind.authenticated,
  authenticatedSubjectId: 'subject-1',
  ownershipState: LocalArchiveOwnershipState.active,
);

Future<({JournalStore store, MobilePrefsStore prefs})> _fixture(
  String label,
) async {
  final dir = Directory.systemTemp.createTempSync('vm_sync_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return (
    store: await JournalStore.open(
      '${dir.path}/journal.json',
      ownerArchiveId: 'account-1',
    ),
    prefs: await MobilePrefsStore.open('${dir.path}/prefs.json'),
  );
}

class _EncryptedSyncApiClient extends JournalSyncApiClient {
  _EncryptedSyncApiClient()
    : super(ApiTransport(baseUrl: 'https://voice-memory-iota.vercel.app'));

  Map<String, dynamic>? pushedBody;

  @override
  Future<SyncPullSnapshot> syncPull() async =>
      const SyncPullSnapshot(blobs: [], manifest: null, collisions: []);

  @override
  Future<SyncManifestSnapshot> syncPush(Map<String, dynamic> body) async {
    pushedBody = body;
    return SyncManifestSnapshot(
      version: 1,
      updatedAt: DateTime.utc(2026, 8),
      blobs: const [],
      collisions: const [],
    );
  }
}

class _OfflineEncryptedSyncApiClient extends _EncryptedSyncApiClient {
  @override
  Future<SyncPullSnapshot> syncPull() =>
      throw NetworkOfflineException('test offline');
}
