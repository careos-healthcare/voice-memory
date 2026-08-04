import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_transport.dart';
import 'package:voicememory_mobile/api/journal_sync_api_client.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/features/journal/sync/saved_moment_sync_key_store.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_crypto.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_service.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';

final class _FakeRecoveryApi extends JournalSyncApiClient {
  _FakeRecoveryApi() : super(ApiTransport(baseUrl: 'https://example.test'));

  Map<String, dynamic>? envelope;
  Object? failure;
  void Function()? beforeReturn;

  void _check() {
    if (failure != null) throw failure!;
    beforeReturn?.call();
  }

  @override
  Future<Map<String, dynamic>> syncRecoveryFetch() async {
    _check();
    return {'envelope': envelope};
  }

  @override
  Future<Map<String, dynamic>> syncRecoveryStatus() async {
    _check();
    return {'enabled': envelope != null};
  }

  @override
  Future<Map<String, dynamic>> syncRecoveryUpsert(
    Map<String, dynamic> value,
  ) async {
    _check();
    envelope = value;
    return {'ok': true};
  }

  @override
  Future<void> syncRecoveryDelete() async {
    _check();
    envelope = null;
  }
}

LocalArchiveIdentity _identity(String account, String archive) =>
    LocalArchiveIdentity(
      archiveId: archive,
      ownerKind: LocalArchiveOwnerKind.authenticated,
      authenticatedSubjectId: account,
      ownershipState: LocalArchiveOwnershipState.active,
    );

void main() {
  late _FakeRecoveryApi api;
  late InMemorySecureStorageService storage;
  late SavedMomentSyncKeyStore keys;
  late LocalArchiveIdentity identity;
  late SyncRecoveryService service;

  setUp(() {
    api = _FakeRecoveryApi();
    storage = InMemorySecureStorageService();
    keys = SavedMomentSyncKeyStore(storage);
    identity = _identity('account-a', 'archive-a');
    service = SyncRecoveryService(
      api: api,
      keyStore: keys,
      identityProvider: () => identity,
    );
  });

  test('storage loss can recover the same key only with the code', () async {
    final original = await keys.requireKey('archive-a');
    final setup = await service.enableOrReplace();
    await keys.deleteKey('archive-a');
    expect(await keys.readKey('archive-a'), isNull);

    await service.recover(setup.secret);
    expect(await keys.readKey('archive-a'), original);
  });

  test('new device adopts the authenticated envelope archive', () async {
    final original = await keys.requireKey('archive-a');
    final setup = await service.enableOrReplace();
    final newKeys = SavedMomentSyncKeyStore(InMemorySecureStorageService());
    identity = _identity('account-a', 'archive-new-device');
    await newKeys.requireKey('archive-new-device');
    final newDevice = SyncRecoveryService(
      api: api,
      keyStore: newKeys,
      identityProvider: () => identity,
      adoptRecoveredArchive: (accountId, archiveId) async {
        identity = _identity(accountId, archiveId);
      },
    );

    await newDevice.recover(setup.secret);
    expect(identity.archiveId, 'archive-a');
    expect(await newKeys.readKey('archive-a'), original);
    expect(await newKeys.readKey('archive-new-device'), isNull);
  });

  test(
    'replace rewraps the current key and advances envelope revision',
    () async {
      final original = await keys.requireKey('archive-a');
      final first = await service.enableOrReplace();
      final second = await service.enableOrReplace();
      expect(second.secret, isNot(first.secret));
      expect(second.envelope.envelopeRevision, 2);
      expect(await keys.readKey('archive-a'), original);
    },
  );

  test('rotation invalidates the previous recovery code', () async {
    final first = await service.enableOrReplace();
    final second = await service.enableOrReplace();

    await expectLater(
      service.recover(first.secret),
      throwsA(
        isA<SyncRecoveryException>().having(
          (error) => error.code,
          'code',
          'authentication_failed',
        ),
      ),
    );
    await keys.deleteKey('archive-a');
    await service.recover(second.secret);
    expect(await keys.readKey('archive-a'), isNotNull);
  });

  test('previously observed recovery envelope cannot be replayed', () async {
    final first = await service.enableOrReplace();
    await service.enableOrReplace();
    api.envelope = first.envelope.toJson();
    await expectLater(
      service.recover(first.secret),
      throwsA(
        isA<SyncRecoveryException>().having(
          (error) => error.code,
          'code',
          'replayed_envelope',
        ),
      ),
    );
  });

  test('offline or unavailable server does not alter the local key', () async {
    final original = await keys.requireKey('archive-a');
    api.failure = StateError('offline');
    await expectLater(service.enableOrReplace(), throwsStateError);
    expect(await keys.readKey('archive-a'), original);
  });

  test(
    'account switch during request fails before local key installation',
    () async {
      final setup = await service.enableOrReplace();
      await keys.deleteKey('archive-a');
      api.beforeReturn = () {
        identity = _identity('account-b', 'archive-b');
        api.beforeReturn = null;
      };
      await expectLater(
        service.recover(setup.secret),
        throwsA(
          isA<SyncRecoveryException>().having(
            (error) => error.code,
            'code',
            'account_scope_changed',
          ),
        ),
      );
      expect(await keys.readKey('archive-a'), isNull);
    },
  );

  test('disable removes only the server envelope', () async {
    final original = await keys.requireKey('archive-a');
    await service.enableOrReplace();
    await service.disable();
    expect(api.envelope, isNull);
    expect(await keys.readKey('archive-a'), original);
  });

  test('disabled recovery cannot be used with its former code', () async {
    final setup = await service.enableOrReplace();
    await service.disable();
    await expectLater(
      service.recover(setup.secret),
      throwsA(
        isA<SyncRecoveryException>().having(
          (error) => error.code,
          'code',
          'recovery_not_enabled',
        ),
      ),
    );
  });
}
