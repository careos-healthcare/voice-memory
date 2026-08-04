import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/app_config.dart';

void main() {
  setUpAll(AppConfig.initApiResolution);

  test('domain clients share session cookie through one transport', () async {
    final requests = <http.Request>[];
    final transport = ApiTransport(
      baseUrl: 'https://voice-memory-iota.vercel.app',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/auth/verify') {
          return http.Response(
            jsonEncode({
              'session': {
                'user': {'id': 'user-1', 'email': 'person@example.com'},
              },
            }),
            200,
            headers: {
              'content-type': 'application/json',
              'set-cookie': 'vm_session=shared-cookie; Path=/; HttpOnly',
            },
          );
        }
        return http.Response(
          jsonEncode({'blobs': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final auth = AuthApiClient(transport);
    final journal = JournalSyncApiClient(transport);

    await auth.verifyAuthCode(email: 'person@example.com', code: '123456');
    await journal.syncPull();

    expect(auth.sessionCookie, 'vm_session=shared-cookie');
    expect(requests.last.headers['cookie'], 'vm_session=shared-cookie');
  });

  test(
    'domain clients preserve endpoint-specific empty-state statuses',
    () async {
      final transport = ApiTransport(
        baseUrl: 'https://voice-memory-iota.vercel.app',
        sessionCookie: 'vm_session=expired',
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/auth/session' ||
              request.url.path == '/api/auth/signout') {
            return http.Response('', 401);
          }
          return http.Response('{"error":"unexpected"}', 500);
        }),
      );
      final auth = AuthApiClient(transport);
      expect(await auth.getSession(), isNull);
      await auth.signOut();
      expect(auth.sessionCookie, isNull);
    },
  );

  test('sync manifest parses optional collision metadata', () async {
    final transport = ApiTransport(
      baseUrl: 'https://voice-memory-iota.vercel.app',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'manifest': {
              'version': 3,
              'updatedAt': '2026-07-26T12:00:00Z',
              'blobs': [
                {
                  'id': 'journal',
                  'type': 'journal_snapshot',
                  'updatedAt': '2026-07-26T11:00:00Z',
                  'byteLength': 42,
                },
              ],
            },
            'collisions': [
              {
                'entryId': 'entry-1',
                'localUpdatedAt': '2026-07-26T10:00:00Z',
                'remoteUpdatedAt': '2026-07-26T11:00:00Z',
                'localVectorClock': {'device-a': 2},
                'remoteVectorClock': {'device-b': 2},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final manifest = await JournalSyncApiClient(transport).syncManifest();

    expect(manifest.version, 3);
    expect(manifest.blobs.single.id, 'journal');
    expect(manifest.hasCollisions, isTrue);
    expect(manifest.collisions.single.recordId, 'entry-1');
    expect(manifest.collisions.single.remoteVectorClock, const {'device-b': 2});
  });
}
