import 'package:flutter/services.dart';

import 'encrypted_graph_sync_engine.dart';

typedef ICloudGraphSyncMethodInvoker =
    Future<T?> Function<T>(String method, [Object? arguments]);

enum ICloudDriveGraphSyncAvailability {
  available,
  unavailable,
  bridgeUnavailable,
  platformError,
}

sealed class ICloudDriveGraphSyncTransportException
    extends EncryptedGraphSyncTransportException {
  const ICloudDriveGraphSyncTransportException(super.message);
}

final class ICloudDriveGraphSyncUnavailableException
    extends ICloudDriveGraphSyncTransportException {
  const ICloudDriveGraphSyncUnavailableException()
    : super('iCloud Drive graph sync is unavailable.');
}

final class ICloudDriveGraphSyncNotFoundException
    extends ICloudDriveGraphSyncTransportException {
  const ICloudDriveGraphSyncNotFoundException()
    : super('The encrypted iCloud Drive graph was not found.');
}

final class ICloudDriveGraphSyncBridgeException
    extends ICloudDriveGraphSyncTransportException {
  const ICloudDriveGraphSyncBridgeException()
    : super('The iCloud Drive graph sync bridge is unavailable.');
}

final class ICloudDriveGraphSyncOperationException
    extends ICloudDriveGraphSyncTransportException {
  const ICloudDriveGraphSyncOperationException()
    : super('The iCloud Drive graph sync operation failed.');
}

final class ICloudDriveGraphSyncTimeoutException
    extends ICloudDriveGraphSyncTransportException {
  const ICloudDriveGraphSyncTimeoutException()
    : super('The iCloud Drive graph sync operation timed out.');
}

final class ICloudDriveGraphSyncInvalidRequestException
    extends ICloudDriveGraphSyncTransportException {
  const ICloudDriveGraphSyncInvalidRequestException()
    : super('The iCloud Drive graph sync request is invalid.');
}

final class ICloudDriveGraphSyncEmptyDownloadException
    extends ICloudDriveGraphSyncTransportException {
  const ICloudDriveGraphSyncEmptyDownloadException()
    : super('The encrypted iCloud Drive graph is empty.');
}

final class ICloudDriveGraphSyncTransport
    implements EncryptedGraphSyncTransport {
  ICloudDriveGraphSyncTransport({ICloudGraphSyncMethodInvoker? methodInvoker})
    : _invoke = methodInvoker ?? const MethodChannel(channelName).invokeMethod;

  static const channelName = 'archive_me/icloud_graph_sync';
  static const _pathPrefix = 'Documents/ArchiveMe_Sync/';
  static final RegExp _safeFilename = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$',
  );

  final ICloudGraphSyncMethodInvoker _invoke;

  /// Probes bridge and account/container availability without throwing.
  Future<ICloudDriveGraphSyncAvailability> availability() async {
    try {
      final available = await _invoke<bool>('isAvailable');
      return available == true
          ? ICloudDriveGraphSyncAvailability.available
          : ICloudDriveGraphSyncAvailability.unavailable;
    } on MissingPluginException {
      return ICloudDriveGraphSyncAvailability.bridgeUnavailable;
    } on PlatformException {
      return ICloudDriveGraphSyncAvailability.platformError;
    } on Object {
      return ICloudDriveGraphSyncAvailability.platformError;
    }
  }

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) async {
    _validateRequest(target, path);
    try {
      await _invoke<void>('upload', <String, Object>{
        'path': path,
        'envelope': encryptedEnvelope,
      });
    } on MissingPluginException {
      throw const ICloudDriveGraphSyncBridgeException();
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) async {
    _validateRequest(target, path);
    try {
      final envelope = await _invoke<String>('download', <String, Object>{
        'path': path,
      });
      if (envelope == null || envelope.isEmpty) {
        throw const ICloudDriveGraphSyncEmptyDownloadException();
      }
      return envelope;
    } on MissingPluginException {
      throw const ICloudDriveGraphSyncBridgeException();
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  static void _validateRequest(EncryptedGraphSyncTarget target, String path) {
    final filename = path.startsWith(_pathPrefix)
        ? path.substring(_pathPrefix.length)
        : '';
    if (target != EncryptedGraphSyncTarget.iCloudDrive ||
        !_safeFilename.hasMatch(filename)) {
      throw const ICloudDriveGraphSyncInvalidRequestException();
    }
  }

  static ICloudDriveGraphSyncTransportException _mapPlatformException(
    PlatformException error,
  ) {
    return switch (error.code) {
      'unavailable' => const ICloudDriveGraphSyncUnavailableException(),
      'download_timeout' ||
      'operation_timeout' => const ICloudDriveGraphSyncTimeoutException(),
      'not_found' => const ICloudDriveGraphSyncNotFoundException(),
      'invalid_args' => const ICloudDriveGraphSyncInvalidRequestException(),
      _ => const ICloudDriveGraphSyncOperationException(),
    };
  }
}
