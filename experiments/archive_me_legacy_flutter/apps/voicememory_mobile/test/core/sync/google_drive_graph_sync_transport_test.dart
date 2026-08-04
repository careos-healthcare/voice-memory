import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/core/sync/google_drive_graph_sync_transport.dart';

const _envelope =
    '{"version":1,"algorithm":"AES-256-GCM","kdf":"PBKDF2-HMAC-SHA256",'
    '"mode":"portable","salt":"AAECAwQFBgcICQoLDA0ODw==",'
    '"iterations":210000,"nonce":"AAECAwQFBgcICQoL",'
    '"ciphertext":"c2VjcmV0","mac":"AAECAwQFBgcICQoLDA0ODw=="}';

void main() {
  group('safe deterministic name mapping', () {
    test('does not expose or preserve unsafe logical path characters', () {
      const path = r"ArchiveMe Sync/private user's\..\graph.enc";

      final first = GoogleDriveGraphSyncTransport.fileNameForPath(path);
      final second = GoogleDriveGraphSyncTransport.fileNameForPath(path);

      expect(first, second);
      expect(first, matches(RegExp(r'^archiveme-graph-v1-[0-9a-f]{64}\.enc$')));
      expect(first, isNot(contains('private')));
      expect(
        GoogleDriveGraphSyncTransport.fileNameForPath('$path-2'),
        isNot(first),
      );
    });
  });

  group('appDataFolder operations', () {
    test('creates a new file containing only UTF-8 envelope bytes', () async {
      final driveClient = _FakeDriveClient();
      final transport = _transport(driveClient: driveClient);

      await transport.upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'ArchiveMe_Sync/graph.enc',
        encryptedEnvelope: _envelope,
      );

      expect(driveClient.createdName, isNotNull);
      expect(driveClient.createdContent, orderedEquals(utf8.encode(_envelope)));
      expect(driveClient.updatedId, isNull);
    });

    test('updates the newest exact-name match deterministically', () async {
      final driveClient = _FakeDriveClient()
        ..files = [
          DriveAppDataFile(id: 'older', modifiedTime: DateTime.utc(2025, 1, 1)),
          DriveAppDataFile(
            id: 'newest',
            modifiedTime: DateTime.utc(2026, 1, 1),
          ),
        ];
      final transport = _transport(driveClient: driveClient);

      await transport.upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'graph.enc',
        encryptedEnvelope: _envelope,
      );

      expect(driveClient.createdName, isNull);
      expect(driveClient.updatedId, 'newest');
      expect(driveClient.updatedContent, orderedEquals(utf8.encode(_envelope)));
    });

    test('breaks duplicate modified-time ties by stable file ID', () async {
      final timestamp = DateTime.utc(2026, 1, 1);
      final driveClient = _FakeDriveClient()
        ..files = [
          DriveAppDataFile(id: 'z-file', modifiedTime: timestamp),
          DriveAppDataFile(id: 'a-file', modifiedTime: timestamp),
        ];

      await _transport(driveClient: driveClient).upload(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'graph.enc',
        encryptedEnvelope: _envelope,
      );

      expect(driveClient.updatedId, 'a-file');
    });

    test('downloads the complete streamed UTF-8 envelope', () async {
      final driveClient = _FakeDriveClient()
        ..files = const [DriveAppDataFile(id: 'remote')]
        ..download = DriveAppDataDownload(
          stream: Stream.fromIterable([
            utf8.encode(_envelope.substring(0, 50)),
            utf8.encode(_envelope.substring(50)),
          ]),
          length: utf8.encode(_envelope).length,
        );

      final result = await _transport(driveClient: driveClient).download(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'graph.enc',
      );

      expect(result, _envelope);
      expect(driveClient.downloadedId, 'remote');
    });

    test('rejects a streamed response over the strict size cap', () async {
      final driveClient = _FakeDriveClient()
        ..files = const [DriveAppDataFile(id: 'remote')]
        ..download = DriveAppDataDownload(
          stream: Stream.fromIterable([
            [1, 2, 3],
            [4, 5, 6],
          ]),
        );

      expect(
        () =>
            _transport(driveClient: driveClient, maxDownloadBytes: 5).download(
              target: EncryptedGraphSyncTarget.googleDrive,
              path: 'graph.enc',
            ),
        throwsCode(GoogleDriveGraphSyncErrorCode.payloadTooLarge),
      );
    });

    test('rejects an upload over the strict UTF-8 byte cap', () {
      final driveClient = _FakeDriveClient();
      expect(
        () => _transport(driveClient: driveClient, maxUploadBytes: 1).upload(
          target: EncryptedGraphSyncTarget.googleDrive,
          path: 'private/path.enc',
          encryptedEnvelope: _envelope,
        ),
        throwsCode(GoogleDriveGraphSyncErrorCode.payloadTooLarge),
      );
    });

    test('rejects malformed upload content before writing', () async {
      final driveClient = _FakeDriveClient();
      await expectLater(
        () => _transport(driveClient: driveClient).upload(
          target: EncryptedGraphSyncTarget.googleDrive,
          path: 'private/path.enc',
          encryptedEnvelope: '{"ciphertext":"private content"}',
        ),
        throwsCode(GoogleDriveGraphSyncErrorCode.invalidPayload),
      );
      expect(driveClient.createdName, isNull);
      expect(driveClient.updatedId, isNull);
    });

    test('rejects malformed and truncated envelopes before decode', () async {
      for (final payload in ['not-json', _envelope.substring(0, 80)]) {
        final driveClient = _FakeDriveClient()
          ..files = const [DriveAppDataFile(id: 'remote')]
          ..download = DriveAppDataDownload(
            stream: Stream.value(utf8.encode(payload)),
          );
        await expectLater(
          () => _transport(driveClient: driveClient).download(
            target: EncryptedGraphSyncTarget.googleDrive,
            path: 'private/path.enc',
          ),
          throwsCode(GoogleDriveGraphSyncErrorCode.invalidPayload),
        );
      }
    });

    test('rejects invalid UTF-8 before envelope decode', () {
      final driveClient = _FakeDriveClient()
        ..files = const [DriveAppDataFile(id: 'remote')]
        ..download = DriveAppDataDownload(stream: Stream.value([0xff]));
      expect(
        () => _transport(driveClient: driveClient).download(
          target: EncryptedGraphSyncTarget.googleDrive,
          path: 'private/path.enc',
        ),
        throwsCode(GoogleDriveGraphSyncErrorCode.invalidPayload),
      );
    });
  });

  group('configuration and authorization', () {
    test('rejects unsupported targets before authorization', () async {
      final authorization = _FakeAuthorization(_authClient());
      final transport = _transport(
        driveClient: _FakeDriveClient(),
        authorization: authorization,
      );

      expect(
        () => transport.download(
          target: EncryptedGraphSyncTarget.iCloudDrive,
          path: 'graph.enc',
        ),
        throwsCode(GoogleDriveGraphSyncErrorCode.unsupportedTarget),
      );
      expect(authorization.nonInteractiveCalls, 0);
    });

    test('reports missing OAuth client configuration', () {
      final transport = GoogleDriveGraphSyncTransport(
        serverClientId: '',
        authorization: _FakeAuthorization(_authClient()),
        driveClientFactory: (_) => _FakeDriveClient(),
        isAndroid: () => true,
      );

      expect(
        () => transport.upload(
          target: EncryptedGraphSyncTarget.googleDrive,
          path: 'graph.enc',
          encryptedEnvelope: _envelope,
        ),
        throwsCode(GoogleDriveGraphSyncErrorCode.notConfigured),
      );
    });

    test('automatic retry returns authorizationRequired without UI', () async {
      final authorization = _FakeAuthorization(null);
      final transport = _transport(
        driveClient: _FakeDriveClient(),
        authorization: authorization,
      );

      expect(
        () => transport.download(
          target: EncryptedGraphSyncTarget.googleDrive,
          path: 'graph.enc',
        ),
        throwsCode(GoogleDriveGraphSyncErrorCode.authorizationRequired),
      );
      expect(authorization.nonInteractiveCalls, 1);
      expect(authorization.interactiveCalls, 0);
    });

    test('explicit authorization invokes only the interactive flow', () async {
      final authorization = _FakeAuthorization(_authClient());
      await _transport(
        driveClient: _FakeDriveClient(),
        authorization: authorization,
      ).authorizeInteractively();

      expect(authorization.interactiveCalls, 1);
      expect(authorization.nonInteractiveCalls, 0);
    });

    test(
      'availability is nonthrowing and never invokes interactive auth',
      () async {
        final authorization = _FakeAuthorization(null);
        final transport = _transport(
          driveClient: _FakeDriveClient(),
          authorization: authorization,
        );

        expect(
          await transport.availability(),
          GoogleDriveGraphSyncAvailability.authorizationRequired,
        );
        expect(authorization.nonInteractiveCalls, 1);
        expect(authorization.interactiveCalls, 0);
      },
    );

    test(
      'availability reports missing configuration without auth calls',
      () async {
        final authorization = _FakeAuthorization(null);
        final transport = GoogleDriveGraphSyncTransport(
          serverClientId: '',
          authorization: authorization,
          driveClientFactory: (_) => _FakeDriveClient(),
          isAndroid: () => true,
        );

        expect(
          await transport.availability(),
          GoogleDriveGraphSyncAvailability.notConfigured,
        );
        expect(authorization.nonInteractiveCalls, 0);
        expect(authorization.interactiveCalls, 0);
      },
    );

    test('availability maps offline auth to retryable fallback', () async {
      final authorization = _FakeAuthorization(
        null,
        failure: http.ClientException('offline private details'),
      );
      final transport = _transport(
        driveClient: _FakeDriveClient(),
        authorization: authorization,
      );

      expect(
        await transport.availability(),
        GoogleDriveGraphSyncAvailability.retryableError,
      );
      expect(authorization.interactiveCalls, 0);
    });
  });

  group('API failure classification', () {
    for (final status in [401, 403]) {
      test('$status requires authorization', () {
        final driveClient = _FakeDriveClient()
          ..failure = drive.DetailedApiRequestError(status, 'redacted');
        expect(
          () => _transport(driveClient: driveClient).download(
            target: EncryptedGraphSyncTarget.googleDrive,
            path: 'graph.enc',
          ),
          throwsCode(GoogleDriveGraphSyncErrorCode.authorizationRequired),
        );
      });
    }

    test('404 is typed notFound', () {
      final driveClient = _FakeDriveClient()
        ..failure = drive.DetailedApiRequestError(404, 'redacted');
      expect(
        () => _transport(driveClient: driveClient).download(
          target: EncryptedGraphSyncTarget.googleDrive,
          path: 'graph.enc',
        ),
        throwsCode(GoogleDriveGraphSyncErrorCode.notFound),
      );
    });

    for (final status in [408, 429, 500, 503]) {
      test('$status is retryable', () {
        final driveClient = _FakeDriveClient()
          ..failure = drive.DetailedApiRequestError(status, 'redacted');
        expect(
          () => _transport(driveClient: driveClient).download(
            target: EncryptedGraphSyncTarget.googleDrive,
            path: 'graph.enc',
          ),
          throwsCode(GoogleDriveGraphSyncErrorCode.retryable),
        );
      });
    }

    test('other API failures are non-retryable apiFailure', () {
      final driveClient = _FakeDriveClient()
        ..failure = drive.DetailedApiRequestError(400, 'redacted');
      expect(
        () => _transport(driveClient: driveClient).download(
          target: EncryptedGraphSyncTarget.googleDrive,
          path: 'graph.enc',
        ),
        throwsCode(GoogleDriveGraphSyncErrorCode.apiFailure),
      );
    });

    test(
      'offline client failure is retryable and message is redacted',
      () async {
        final driveClient = _FakeDriveClient()
          ..failure = http.ClientException(
            'private/path and private envelope content',
          );
        try {
          await _transport(driveClient: driveClient).download(
            target: EncryptedGraphSyncTarget.googleDrive,
            path: 'private/path.enc',
          );
          fail('Expected retryable failure.');
        } on GoogleDriveGraphSyncException catch (error) {
          expect(error.code, GoogleDriveGraphSyncErrorCode.retryable);
          expect(error.message, isNot(contains('private')));
        }
      },
    );

    test('operation timeout is retryable', () {
      final driveClient = _FakeDriveClient()
        ..findDelay = const Duration(milliseconds: 50);
      expect(
        () =>
            _transport(
              driveClient: driveClient,
              operationTimeout: const Duration(milliseconds: 1),
            ).download(
              target: EncryptedGraphSyncTarget.googleDrive,
              path: 'graph.enc',
            ),
        throwsCode(GoogleDriveGraphSyncErrorCode.retryable),
      );
    });
  });
}

Matcher throwsCode(GoogleDriveGraphSyncErrorCode code) => throwsA(
  isA<GoogleDriveGraphSyncException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);

GoogleDriveGraphSyncTransport _transport({
  required _FakeDriveClient driveClient,
  _FakeAuthorization? authorization,
  int maxDownloadBytes = 16 * 1024 * 1024,
  int maxUploadBytes = 16 * 1024 * 1024,
  Duration operationTimeout = const Duration(seconds: 30),
}) {
  return GoogleDriveGraphSyncTransport(
    serverClientId: 'test-client.apps.googleusercontent.com',
    authorization: authorization ?? _FakeAuthorization(_authClient()),
    driveClientFactory: (_) => driveClient,
    isAndroid: () => true,
    maxDownloadBytes: maxDownloadBytes,
    maxUploadBytes: maxUploadBytes,
    operationTimeout: operationTimeout,
  );
}

AuthClient _authClient() {
  return authenticatedClient(
    http.Client(),
    AccessCredentials(
      AccessToken(
        'Bearer',
        'test-only-token',
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      const [drive.DriveApi.driveAppdataScope],
    ),
  );
}

class _FakeAuthorization implements GoogleDriveAuthorization {
  _FakeAuthorization(this.client, {this.failure});

  final AuthClient? client;
  final Object? failure;
  int nonInteractiveCalls = 0;
  int interactiveCalls = 0;

  @override
  Future<AuthClient> authorizeInteractively() async {
    interactiveCalls += 1;
    return client ?? _authClient();
  }

  @override
  Future<AuthClient?> authorizeNonInteractively() async {
    nonInteractiveCalls += 1;
    if (failure case final error?) throw error;
    return client;
  }
}

class _FakeDriveClient implements DriveAppDataClient {
  List<DriveAppDataFile> files = [];
  DriveAppDataDownload download = DriveAppDataDownload(
    stream: const Stream.empty(),
    length: 0,
  );
  Object? failure;
  Duration? findDelay;
  String? createdName;
  List<int>? createdContent;
  String? updatedId;
  List<int>? updatedContent;
  String? downloadedId;

  void _throwIfNeeded() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<void> createFile({
    required String name,
    required List<int> utf8Content,
  }) async {
    _throwIfNeeded();
    createdName = name;
    createdContent = List.of(utf8Content);
  }

  @override
  Future<DriveAppDataDownload> downloadFile(String fileId) async {
    _throwIfNeeded();
    downloadedId = fileId;
    return download;
  }

  @override
  Future<List<DriveAppDataFile>> findFilesByName(String name) async {
    if (findDelay case final delay?) await Future<void>.delayed(delay);
    _throwIfNeeded();
    return List.of(files);
  }

  @override
  Future<void> updateFile({
    required String fileId,
    required List<int> utf8Content,
  }) async {
    _throwIfNeeded();
    updatedId = fileId;
    updatedContent = List.of(utf8Content);
  }
}
