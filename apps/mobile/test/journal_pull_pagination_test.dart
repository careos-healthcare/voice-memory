// Objective 2 (real synchronization model) — covers SyncApiClient.listLegacyJournal()'s
// consumption of the server's deterministic keyset pull-pagination
// (`GET /api/journal?limit=&cursor=` / `nextCursor` in
// app/api/journal/route.ts and lib/server/journal-store.ts). Pagination is a
// transport-level detail: SyncService must still see one flattened list, and
// no entry may be skipped or duplicated across pages regardless of how the
// server chooses to chunk them.
import 'dart:convert';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/data/network/http_sync_api_client.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'a',
  concreteObservation: 'b',
  repeatedSignal: 'c',
);

Map<String, dynamic> _serverEntry(String id) => JournalEntry(
  id: id,
  createdAt: DateTime.utc(2026),
  transcript: 'entry $id',
  durationSeconds: 5,
  reflection: _reflection(),
).toJson();

void main() {
  setUpAll(() async {
    await AppConfig.initApiResolution();
  });

  test(
    'listLegacyJournal() follows nextCursor and assembles every entry across a server-chunked pull, without duplicates or gaps',
    () async {
      const perPage = 2;
      final allIds = ['e0', 'e1', 'e2', 'e3', 'e4'];
      final requestedLimits = <String?>[];
      final requestedCursors = <String?>[];

      final transport = HttpTransport(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/journal');
          requestedLimits.add(request.url.queryParameters['limit']);
          final cursor = request.url.queryParameters['cursor'];
          requestedCursors.add(cursor);
          final start = cursor == null ? 0 : int.parse(cursor);
          final end = (start + perPage).clamp(0, allIds.length);
          final page = allIds.sublist(start, end);
          final nextCursor = end < allIds.length ? '$end' : null;
          return http.Response(
            jsonEncode({
              'entries': page.map(_serverEntry).toList(),
              'nextCursor': ?nextCursor,
            }),
            200,
          );
        }),
        baseUrl: 'https://voice-memory-iota.vercel.app',
      );
      final api = HttpSyncApiClient(transport);

      final result = await api.listLegacyJournal();
      final entries = result.when(
        success: (value) => value,
        onFailure: (failure) => throw failure.toApiException(),
      );

      expect(entries.map((e) => e.id).toList(), allIds);
      // 5 entries at 2-per-page: pages [0,1] [2,3] [4] — 3 round trips.
      expect(requestedCursors, [null, '2', '4']);
      // Every request asks for the same server-side page size regardless of cursor.
      expect(requestedLimits.toSet(), hasLength(1));
      expect(int.parse(requestedLimits.first!), greaterThan(0));
    },
  );

  test(
    'listLegacyJournal() makes exactly one request when the server omits nextCursor (legacy/unbounded response shape)',
    () async {
      var callCount = 0;
      final transport = HttpTransport(
        client: MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'entries': ['solo'].map(_serverEntry).toList(),
            }),
            200,
          );
        }),
        baseUrl: 'https://voice-memory-iota.vercel.app',
      );
      final api = HttpSyncApiClient(transport);

      final result = await api.listLegacyJournal();
      final entries = result.when(
        success: (value) => value,
        onFailure: (failure) => throw failure.toApiException(),
      );

      expect(callCount, 1);
      expect(entries.map((e) => e.id).toList(), ['solo']);
    },
  );

  test(
    'listLegacyJournal() returns an empty list for an empty journal without looping',
    () async {
      var callCount = 0;
      final transport = HttpTransport(
        client: MockClient((request) async {
          callCount++;
          return http.Response(jsonEncode({'entries': []}), 200);
        }),
        baseUrl: 'https://voice-memory-iota.vercel.app',
      );
      final api = HttpSyncApiClient(transport);

      final result = await api.listLegacyJournal();
      final entries = result.when(
        success: (value) => value,
        onFailure: (failure) => throw failure.toApiException(),
      );

      expect(callCount, 1);
      expect(entries, isEmpty);
    },
  );
}