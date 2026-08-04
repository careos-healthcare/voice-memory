import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/core/sync/google_drive_graph_sync_transport.dart';
import 'package:voicememory_mobile/core/sync/icloud_drive_graph_sync_transport.dart';
import 'package:voicememory_mobile/core/sync/platform_encrypted_graph_sync_transport.dart';

const _envelope =
    '{"version":1,"algorithm":"AES-256-GCM","kdf":"PBKDF2-HMAC-SHA256",'
    '"mode":"portable","salt":"AAECAwQFBgcICQoLDA0ODw==",'
    '"iterations":210000,"nonce":"AAECAwQFBgcICQoL",'
    '"ciphertext":"c2VjcmV0","mac":"AAECAwQFBgcICQoLDA0ODw=="}';

void main() {
  const iCloudPath = 'Documents/ArchiveMe_Sync/graph.enc';

  test('routes iCloud only on iOS and Google Drive only on Android', () async {
    final iCloudInvoker = _ICloudInvoker();
    final driveClient = _DriveClient();
    final authorization = _Authorization(_authClient());

    final ios = PlatformEncryptedGraphSyncTransport(
      iCloudTransport: ICloudDriveGraphSyncTransport(
        methodInvoker: iCloudInvoker.call,
      ),
      googleDriveTransport: _google(authorization, driveClient),
      isIOS: () => true,
      isAndroid: () => false,
    );
    await ios.upload(
      target: EncryptedGraphSyncTarget.iCloudDrive,
      path: iCloudPath,
      encryptedEnvelope: 'ios-envelope',
    );
    expect(iCloudInvoker.lastMethod, 'upload');
    expect(authorization.nonInteractiveCalls, 0);

    final android = PlatformEncryptedGraphSyncTransport(
      iCloudTransport: ICloudDriveGraphSyncTransport(
        methodInvoker: iCloudInvoker.call,
      ),
      googleDriveTransport: _google(authorization, driveClient),
      isIOS: () => false,
      isAndroid: () => true,
    );
    await android.upload(
      target: EncryptedGraphSyncTarget.googleDrive,
      path: 'ArchiveMe_Sync/graph.enc',
      encryptedEnvelope: _envelope,
    );
    expect(driveClient.created, 1);
    expect(authorization.nonInteractiveCalls, 1);
    expect(authorization.interactiveCalls, 0);
  });

  test('unsupported platform-target combination is typed', () async {
    final transport = PlatformEncryptedGraphSyncTransport(
      iCloudTransport: ICloudDriveGraphSyncTransport(
        methodInvoker: _ICloudInvoker().call,
      ),
      googleDriveTransport: _google(_Authorization(null), _DriveClient()),
      isIOS: () => true,
      isAndroid: () => false,
    );

    await expectLater(
      transport.download(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: 'ArchiveMe_Sync/graph.enc',
      ),
      throwsA(
        isA<PlatformEncryptedGraphSyncTransportException>().having(
          (error) => error.code,
          'code',
          PlatformEncryptedGraphSyncErrorCode.unsupported,
        ),
      ),
    );
    expect(
      await transport.capability(EncryptedGraphSyncTarget.googleDrive),
      EncryptedGraphSyncCapabilityState.unsupported,
    );
  });

  test('capability probes map fallback states without prompting', () async {
    final authorization = _Authorization(null);
    final android = PlatformEncryptedGraphSyncTransport(
      iCloudTransport: ICloudDriveGraphSyncTransport(
        methodInvoker: _ICloudInvoker().call,
      ),
      googleDriveTransport: _google(authorization, _DriveClient()),
      isIOS: () => false,
      isAndroid: () => true,
    );

    expect(
      await android.capability(EncryptedGraphSyncTarget.googleDrive),
      EncryptedGraphSyncCapabilityState.authorizationRequired,
    );
    expect(authorization.nonInteractiveCalls, 1);
    expect(authorization.interactiveCalls, 0);

    final ios = PlatformEncryptedGraphSyncTransport(
      iCloudTransport: ICloudDriveGraphSyncTransport(
        methodInvoker: _ICloudInvoker(result: false).call,
      ),
      googleDriveTransport: _google(_Authorization(null), _DriveClient()),
      isIOS: () => true,
      isAndroid: () => false,
    );
    expect(
      await ios.capability(EncryptedGraphSyncTarget.iCloudDrive),
      EncryptedGraphSyncCapabilityState.authorizationRequired,
    );
  });
}

GoogleDriveGraphSyncTransport _google(
  _Authorization authorization,
  _DriveClient driveClient,
) => GoogleDriveGraphSyncTransport(
  serverClientId: 'test.apps.googleusercontent.com',
  authorization: authorization,
  driveClientFactory: (_) => driveClient,
  isAndroid: () => true,
);

AuthClient _authClient() => authenticatedClient(
  http.Client(),
  AccessCredentials(
    AccessToken(
      'Bearer',
      'test-token',
      DateTime.now().toUtc().add(const Duration(hours: 1)),
    ),
    null,
    const [drive.DriveApi.driveAppdataScope],
  ),
);

class _Authorization implements GoogleDriveAuthorization {
  _Authorization(this.client);

  final AuthClient? client;
  int nonInteractiveCalls = 0;
  int interactiveCalls = 0;

  @override
  Future<AuthClient?> authorizeNonInteractively() async {
    nonInteractiveCalls++;
    return client;
  }

  @override
  Future<AuthClient> authorizeInteractively() async {
    interactiveCalls++;
    return client ?? _authClient();
  }
}

class _DriveClient implements DriveAppDataClient {
  int created = 0;

  @override
  Future<void> createFile({
    required String name,
    required List<int> utf8Content,
  }) async {
    created++;
  }

  @override
  Future<DriveAppDataDownload> downloadFile(String fileId) =>
      throw UnimplementedError();

  @override
  Future<List<DriveAppDataFile>> findFilesByName(String name) async => const [];

  @override
  Future<void> updateFile({
    required String fileId,
    required List<int> utf8Content,
  }) async {}
}

class _ICloudInvoker {
  _ICloudInvoker({this.result});

  final Object? result;
  String? lastMethod;

  Future<T?> call<T>(String method, [Object? arguments]) async {
    lastMethod = method;
    return result as T?;
  }
}
