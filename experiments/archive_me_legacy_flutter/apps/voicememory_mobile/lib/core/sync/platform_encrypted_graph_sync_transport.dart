import 'dart:io';

import 'encrypted_graph_sync_engine.dart';
import 'google_drive_graph_sync_transport.dart';
import 'icloud_drive_graph_sync_transport.dart';

enum EncryptedGraphSyncCapabilityState {
  available,
  notConfigured,
  authorizationRequired,
  unavailable,
  unsupported,
  retryableError,
}

abstract interface class EncryptedGraphSyncCapabilityProbe {
  Future<EncryptedGraphSyncCapabilityState> capability(
    EncryptedGraphSyncTarget target,
  );
}

enum PlatformEncryptedGraphSyncErrorCode { notConfigured, unsupported }

class PlatformEncryptedGraphSyncTransportException
    extends EncryptedGraphSyncTransportException {
  const PlatformEncryptedGraphSyncTransportException(this.code, super.message);

  final PlatformEncryptedGraphSyncErrorCode code;
}

/// Plugin-free fallback for provider containers without initialized services.
class UnavailableEncryptedGraphSyncCapabilityProbe
    implements EncryptedGraphSyncCapabilityProbe {
  const UnavailableEncryptedGraphSyncCapabilityProbe();

  @override
  Future<EncryptedGraphSyncCapabilityState> capability(
    EncryptedGraphSyncTarget target,
  ) async => EncryptedGraphSyncCapabilityState.unavailable;
}

/// Routes each production target only to its supported host platform.
///
/// Capability checks and background operations never present authorization UI.
/// Google authorization is available only through the explicit foreground
/// [authorizeGoogleDriveInteractively] API.
class PlatformEncryptedGraphSyncTransport
    implements EncryptedGraphSyncTransport, EncryptedGraphSyncCapabilityProbe {
  PlatformEncryptedGraphSyncTransport({
    ICloudDriveGraphSyncTransport? iCloudTransport,
    GoogleDriveGraphSyncTransport? googleDriveTransport,
    bool Function()? isIOS,
    bool Function()? isAndroid,
  }) : _iCloudTransport = iCloudTransport ?? ICloudDriveGraphSyncTransport(),
       _googleDriveTransport =
           googleDriveTransport ?? GoogleDriveGraphSyncTransport(),
       _isIOS = isIOS ?? _platformIsIOS,
       _isAndroid = isAndroid ?? _platformIsAndroid;

  final ICloudDriveGraphSyncTransport _iCloudTransport;
  final GoogleDriveGraphSyncTransport _googleDriveTransport;
  final bool Function() _isIOS;
  final bool Function() _isAndroid;

  static bool _platformIsIOS() => Platform.isIOS;
  static bool _platformIsAndroid() => Platform.isAndroid;

  @override
  Future<EncryptedGraphSyncCapabilityState> capability(
    EncryptedGraphSyncTarget target,
  ) async {
    if (target == EncryptedGraphSyncTarget.iCloudDrive && _isIOS()) {
      return switch (await _iCloudTransport.availability()) {
        ICloudDriveGraphSyncAvailability.available =>
          EncryptedGraphSyncCapabilityState.available,
        ICloudDriveGraphSyncAvailability.unavailable =>
          EncryptedGraphSyncCapabilityState.authorizationRequired,
        ICloudDriveGraphSyncAvailability.bridgeUnavailable =>
          EncryptedGraphSyncCapabilityState.notConfigured,
        ICloudDriveGraphSyncAvailability.platformError =>
          EncryptedGraphSyncCapabilityState.retryableError,
      };
    }
    if (target == EncryptedGraphSyncTarget.googleDrive && _isAndroid()) {
      return switch (await _googleDriveTransport.availability()) {
        GoogleDriveGraphSyncAvailability.available =>
          EncryptedGraphSyncCapabilityState.available,
        GoogleDriveGraphSyncAvailability.notConfigured =>
          EncryptedGraphSyncCapabilityState.notConfigured,
        GoogleDriveGraphSyncAvailability.authorizationRequired =>
          EncryptedGraphSyncCapabilityState.authorizationRequired,
        GoogleDriveGraphSyncAvailability.unavailable =>
          EncryptedGraphSyncCapabilityState.unavailable,
        GoogleDriveGraphSyncAvailability.unsupported =>
          EncryptedGraphSyncCapabilityState.unsupported,
        GoogleDriveGraphSyncAvailability.retryableError =>
          EncryptedGraphSyncCapabilityState.retryableError,
      };
    }
    return EncryptedGraphSyncCapabilityState.unsupported;
  }

  Future<void> authorizeGoogleDriveInteractively() {
    if (!_isAndroid()) {
      throw const PlatformEncryptedGraphSyncTransportException(
        PlatformEncryptedGraphSyncErrorCode.unsupported,
        'Google Drive graph sync is unsupported on this platform.',
      );
    }
    return _googleDriveTransport.authorizeInteractively();
  }

  @override
  Future<void> upload({
    required EncryptedGraphSyncTarget target,
    required String path,
    required String encryptedEnvelope,
  }) async {
    final transport = _transportFor(target);
    await transport.upload(
      target: target,
      path: path,
      encryptedEnvelope: encryptedEnvelope,
    );
  }

  @override
  Future<String> download({
    required EncryptedGraphSyncTarget target,
    required String path,
  }) async => _transportFor(target).download(target: target, path: path);

  EncryptedGraphSyncTransport _transportFor(EncryptedGraphSyncTarget target) {
    if (target == EncryptedGraphSyncTarget.iCloudDrive && _isIOS()) {
      return _iCloudTransport;
    }
    if (target == EncryptedGraphSyncTarget.googleDrive && _isAndroid()) {
      return _googleDriveTransport;
    }
    throw const PlatformEncryptedGraphSyncTransportException(
      PlatformEncryptedGraphSyncErrorCode.unsupported,
      'The graph sync target is unsupported on this platform.',
    );
  }
}
