import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/journal_ownership_guard.dart';
import 'package:voicememory_mobile/services/sync_service.dart';
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

JournalEntry _entry({required String id, String? ownerKey}) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026, 1, 1),
  transcript: 'entry $id',
  durationSeconds: 5,
  reflection: _reflection(),
  syncStatus: SyncStatus.localOnly,
  ownerKey: ownerKey,
);

void main() {
  setUpAll(() async {
    await AppConfig.initApiResolution();
  });

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

      // user-a's entry was created and left pending before the device
      // switched accounts.
      await journal.save(_entry(id: 'a', ownerKey: 'user-a'));
      journal.setActiveOwnerKey('user-b');
      // user-b creates a new entry after signing in.
      await journal.save(_entry(id: 'b'));

      await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, 'user-b');
      await prefs.writeBool(
        JournalOwnershipGuard.migrationPendingPrefsKey,
        true,
      );

      final uploadedIds = <String>[];
      final api = ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/api/journal') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final entries = body['entries'] as List<dynamic>;
            final ids = entries.map((e) => (e as Map)['id'] as String).toList();
            uploadedIds.addAll(ids);
            return http.Response(
              jsonEncode({
                'ok': true,
                'accepted': ids,
                'rejected': [],
                'upserted': ids.length,
              }),
              200,
            );
          }
          if (request.method == 'GET' && request.url.path == '/api/journal') {
            return http.Response(jsonEncode({'entries': []}), 200);
          }
          return http.Response('not found', 404);
        }),
        baseUrl: 'https://voice-memory-iota.vercel.app',
      );
      api.setSessionCookie('session=user-b');

      final sync = SyncService(api, journal, prefs);
      final result = await sync.syncNow();

      expect(uploadedIds, ['b']);
      expect(uploadedIds, isNot(contains('a')));
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

    // Entry created before owner tagging existed — no ownerKey at all.
    await journal.save(_entry(id: 'legacy'));

    await prefs.writeString(JournalOwnershipGuard.ownerKeyPrefsKey, 'user-a');
    await prefs.writeBool(
      JournalOwnershipGuard.migrationPendingPrefsKey,
      false,
    );

    final uploadedIds = <String>[];
    final api = ApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/journal') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final entries = body['entries'] as List<dynamic>;
          final ids = entries.map((e) => (e as Map)['id'] as String).toList();
          uploadedIds.addAll(ids);
          return http.Response(
            jsonEncode({
              'ok': true,
              'accepted': ids,
              'rejected': [],
              'upserted': ids.length,
            }),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/api/journal') {
          return http.Response(jsonEncode({'entries': []}), 200);
        }
        return http.Response('not found', 404);
      }),
      baseUrl: 'https://voice-memory-iota.vercel.app',
    );
    api.setSessionCookie('session=user-a');

    final sync = SyncService(api, journal, prefs);
    final result = await sync.syncNow();

    expect(uploadedIds, ['legacy']);
    expect(result.syncNote, isNull);
  });
}
