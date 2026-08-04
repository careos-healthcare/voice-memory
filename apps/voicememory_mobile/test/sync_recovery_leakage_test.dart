import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_transport.dart';
import 'package:voicememory_mobile/api/journal_sync_api_client.dart';
import 'package:voicememory_mobile/features/archive_ownership/local_archive_identity.dart';
import 'package:voicememory_mobile/features/journal/sync/saved_moment_sync_key_store.dart';
import 'package:voicememory_mobile/features/sync_recovery/sync_recovery_service.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';

final class _LeakageApi extends JournalSyncApiClient {
  _LeakageApi() : super(ApiTransport(baseUrl: 'https://example.test'));

  Map<String, dynamic>? uploadedEnvelope;

  @override
  Future<Map<String, dynamic>> syncRecoveryFetch() async => {
    'envelope': uploadedEnvelope,
  };

  @override
  Future<Map<String, dynamic>> syncRecoveryUpsert(
    Map<String, dynamic> envelope,
  ) async {
    uploadedEnvelope = envelope;
    return {'ok': true};
  }
}

final class _InspectingStorage extends InMemorySecureStorageService {
  final Map<String, String> writes = {};

  @override
  Future<void> write(String key, String value) async {
    writes[key] = value;
    await super.write(key, value);
  }
}

void main() {
  tearDown(ProductAnalytics.resetForTest);

  test(
    'recovery code enters no server envelope, secure storage, analytics, logs, or ordinary export',
    () async {
      final api = _LeakageApi();
      final storage = _InspectingStorage();
      final identity = LocalArchiveIdentity(
        archiveId: 'archive-a',
        ownerKind: LocalArchiveOwnerKind.authenticated,
        authenticatedSubjectId: 'account-a',
        ownershipState: LocalArchiveOwnershipState.active,
      );
      final service = SyncRecoveryService(
        api: api,
        keyStore: SavedMomentSyncKeyStore(storage),
        identityProvider: () => identity,
      );
      final logs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };

      late String code;
      try {
        code = (await service.enableOrReplace()).secret;
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(jsonEncode(api.uploadedEnvelope), isNot(contains(code)));
      expect(jsonEncode(storage.writes), isNot(contains(code)));
      final analytics = ProductAnalytics.eventsForTest
          .map((event) => '${event.event} ${event.parameters}')
          .join(' ');
      expect(analytics, contains('recovery_started'));
      expect(analytics, contains('recovery_completed'));
      expect(analytics, isNot(contains(code)));
      expect(logs.join('\n'), isNot(contains(code)));

      // Audit the ordinary export input boundary without importing or changing
      // export implementation. It accepts journal data and Changes only, and
      // has no dependency on recovery state or recovery code material.
      final exportSource = await File(
        'lib/security/private_data_service.dart',
      ).readAsString();
      expect(exportSource, contains('buildCompleteExport({'));
      expect(exportSource, contains('ChangeThreadProjection changes'));
      expect(exportSource, isNot(contains('sync_recovery')));
      expect(exportSource, isNot(contains('recoverySecret')));
      expect(exportSource, isNot(contains('recoveryCode')));
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
