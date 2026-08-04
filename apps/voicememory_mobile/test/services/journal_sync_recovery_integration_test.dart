import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/sync_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

import '../support/scripted_sync_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initApiResolution);

  test('failed encrypted batch push preserves all pending work', () async {
    final root = await Directory.systemTemp.createTemp('journal_batch_e2e_');
    addTearDown(() => root.delete(recursive: true));
    final journal = await JournalStore.open(
      '${root.path}/journal.json',
      ownerArchiveId: 'account-1',
    );
    final prefs = await MobilePrefsStore.open('${root.path}/prefs.json');
    await journal.save(_entry('older', DateTime.utc(2026, 7, 26, 10)));
    await journal.save(_entry('newer', DateTime.utc(2026, 7, 26, 11)));
    final pushes = ScriptedTransport<Map<String, dynamic>, void>([
      ScriptedFailure<void>(NetworkOfflineException('drop one')),
      ScriptedFailure<void>(NetworkOfflineException('drop two')),
    ]);
    final api = _ScriptedEncryptedApi(pushes);
    final clock = FakeSyncClock(DateTime.utc(2026, 7, 26, 12));
    final delay = FakeDelay(clock);

    final result = await SyncService(
      api,
      journal,
      prefs,
      retryCoordinator: SyncRetryCoordinator(
        maxAttempts: 2,
        baseDelay: const Duration(seconds: 2),
        maxDelay: const Duration(seconds: 2),
        delay: delay.call,
        randomDouble: () => 0.5,
      ),
      clock: clock.call,
      archiveIdentityProvider: () => const LocalArchiveIdentity(
        archiveId: 'account-1',
        ownerKind: LocalArchiveOwnerKind.authenticated,
        authenticatedSubjectId: 'subject-1',
        ownershipState: LocalArchiveOwnershipState.active,
      ),
      keyProvider: (_) async => List<int>.filled(32, 7),
      deviceIdProvider: () async => 'device-1',
    ).syncNow();

    expect(result.cloudSyncSucceeded, isFalse);
    expect(result.pushed, 0);
    expect(pushes.requests, hasLength(2));
    expect((await journal.pendingSyncQueue()).map((entry) => entry.id), [
      'newer',
      'older',
    ]);
    expect(delay.calls, [const Duration(seconds: 1)]);
  });
}

JournalEntry _entry(String id, DateTime createdAt) => JournalEntry(
  id: id,
  ownerArchiveId: 'account-1',
  createdAt: createdAt,
  transcript: 'transcript $id',
  durationSeconds: 1,
  reflection: const Reflection(
    mood: 'steady',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

final class _ScriptedEncryptedApi extends JournalSyncApiClient {
  _ScriptedEncryptedApi(this.pushes)
    : super(ApiTransport(baseUrl: 'https://example.test'));

  final ScriptedTransport<Map<String, dynamic>, void> pushes;

  @override
  Future<SyncPullSnapshot> syncPull() async =>
      const SyncPullSnapshot(blobs: [], manifest: null, collisions: []);

  @override
  Future<SyncManifestSnapshot> syncPush(Map<String, dynamic> body) async {
    await pushes.send(body);
    return const SyncManifestSnapshot(
      version: 1,
      updatedAt: null,
      blobs: [],
      collisions: [],
    );
  }
}
