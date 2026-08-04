import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/sync/encrypted_graph_sync_engine.dart';
import 'package:voicememory_mobile/core/sync/icloud_drive_graph_sync_transport.dart';

void main() {
  const safePath = 'Documents/ArchiveMe_Sync/graph-2026_07.enc';

  test('upload invokes the native channel with path and envelope', () async {
    final invoker = _RecordingInvoker();
    final transport = ICloudDriveGraphSyncTransport(
      methodInvoker: invoker.call,
    );

    await transport.upload(
      target: EncryptedGraphSyncTarget.iCloudDrive,
      path: safePath,
      encryptedEnvelope: 'encrypted-envelope',
    );

    expect(invoker.method, 'upload');
    expect(invoker.arguments, <String, Object>{
      'path': safePath,
      'envelope': 'encrypted-envelope',
    });
  });

  test('download invokes the native channel and returns envelope', () async {
    final invoker = _RecordingInvoker(result: 'downloaded-envelope');
    final transport = ICloudDriveGraphSyncTransport(
      methodInvoker: invoker.call,
    );

    final result = await transport.download(
      target: EncryptedGraphSyncTarget.iCloudDrive,
      path: safePath,
    );

    expect(result, 'downloaded-envelope');
    expect(invoker.method, 'download');
    expect(invoker.arguments, <String, Object>{'path': safePath});
  });

  group('availability', () {
    test('reports available and unavailable results', () async {
      final available = ICloudDriveGraphSyncTransport(
        methodInvoker: _RecordingInvoker(result: true).call,
      );
      final unavailable = ICloudDriveGraphSyncTransport(
        methodInvoker: _RecordingInvoker(result: false).call,
      );

      expect(
        await available.availability(),
        ICloudDriveGraphSyncAvailability.available,
      );
      expect(
        await unavailable.availability(),
        ICloudDriveGraphSyncAvailability.unavailable,
      );
    });

    test('never throws for missing plugin or platform errors', () async {
      final missing = ICloudDriveGraphSyncTransport(
        methodInvoker: _ThrowingInvoker(MissingPluginException()).call,
      );
      final platform = ICloudDriveGraphSyncTransport(
        methodInvoker: _ThrowingInvoker(
          PlatformException(code: 'private', message: safePath),
        ).call,
      );

      expect(
        await missing.availability(),
        ICloudDriveGraphSyncAvailability.bridgeUnavailable,
      );
      expect(
        await platform.availability(),
        ICloudDriveGraphSyncAvailability.platformError,
      );
    });
  });

  test('rejects the wrong target before invoking native code', () async {
    final invoker = _RecordingInvoker();
    final transport = ICloudDriveGraphSyncTransport(
      methodInvoker: invoker.call,
    );

    await expectLater(
      transport.download(
        target: EncryptedGraphSyncTarget.googleDrive,
        path: safePath,
      ),
      throwsA(isA<ICloudDriveGraphSyncInvalidRequestException>()),
    );
    expect(invoker.method, isNull);
  });

  for (final unsafePath in <String>[
    'ArchiveMe_Sync/graph.enc',
    '/Documents/ArchiveMe_Sync/graph.enc',
    'Documents/ArchiveMe_Sync/',
    'Documents/ArchiveMe_Sync/../graph.enc',
    r'Documents/ArchiveMe_Sync/folder\graph.enc',
    'Documents/ArchiveMe_Sync/folder/graph.enc',
    'Documents/ArchiveMe_Sync/.hidden',
    'Documents/ArchiveMe_Sync/graph name.enc',
  ]) {
    test('rejects unsafe path "$unsafePath"', () async {
      final transport = ICloudDriveGraphSyncTransport(
        methodInvoker: _RecordingInvoker().call,
      );

      await expectLater(
        transport.download(
          target: EncryptedGraphSyncTarget.iCloudDrive,
          path: unsafePath,
        ),
        throwsA(isA<ICloudDriveGraphSyncInvalidRequestException>()),
      );
    });
  }

  test('maps missing plugin without exposing request details', () async {
    final transport = ICloudDriveGraphSyncTransport(
      methodInvoker: _ThrowingInvoker(MissingPluginException()).call,
    );

    await expectLater(
      transport.upload(
        target: EncryptedGraphSyncTarget.iCloudDrive,
        path: safePath,
        encryptedEnvelope: 'highly-secret-envelope',
      ),
      throwsA(
        isA<ICloudDriveGraphSyncBridgeException>()
            .having(
              (error) => error.message,
              'message',
              isNot(contains(safePath)),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('highly-secret-envelope')),
            ),
      ),
    );
  });

  for (final entry in <(String, Type)>[
    ('unavailable', ICloudDriveGraphSyncUnavailableException),
    ('download_timeout', ICloudDriveGraphSyncTimeoutException),
    ('operation_timeout', ICloudDriveGraphSyncTimeoutException),
    ('not_found', ICloudDriveGraphSyncNotFoundException),
    ('invalid_args', ICloudDriveGraphSyncInvalidRequestException),
    ('io_error', ICloudDriveGraphSyncOperationException),
  ]) {
    test('maps platform error ${entry.$1} to ${entry.$2}', () async {
      final transport = ICloudDriveGraphSyncTransport(
        methodInvoker: _ThrowingInvoker(
          PlatformException(
            code: entry.$1,
            message: 'secret message',
            details: <String, Object>{'path': safePath},
          ),
        ).call,
      );

      await expectLater(
        transport.download(
          target: EncryptedGraphSyncTarget.iCloudDrive,
          path: safePath,
        ),
        throwsA(
          isA<EncryptedGraphSyncTransportException>()
              .having((error) => error.runtimeType, 'type', entry.$2)
              .having(
                (error) => error.message,
                'message',
                isNot(contains('secret')),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains(safePath)),
              ),
        ),
      );
    });
  }

  test('rejects null and empty native downloads', () async {
    for (final result in <Object?>[null, '']) {
      final transport = ICloudDriveGraphSyncTransport(
        methodInvoker: _RecordingInvoker(result: result).call,
      );

      await expectLater(
        transport.download(
          target: EncryptedGraphSyncTarget.iCloudDrive,
          path: safePath,
        ),
        throwsA(isA<ICloudDriveGraphSyncEmptyDownloadException>()),
      );
    }
  });
}

final class _RecordingInvoker {
  _RecordingInvoker({this.result});

  final Object? result;
  String? method;
  Object? arguments;

  Future<T?> call<T>(String method, [Object? arguments]) async {
    this.method = method;
    this.arguments = arguments;
    return result as T?;
  }
}

final class _ThrowingInvoker {
  const _ThrowingInvoker(this.error);

  final Object error;

  Future<T?> call<T>(String method, [Object? arguments]) async {
    throw error;
  }
}
