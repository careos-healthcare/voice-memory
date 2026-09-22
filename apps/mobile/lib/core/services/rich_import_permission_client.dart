import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permissions a rich import may ask for after the in-app soft prompt.
enum SoftPermissionKind { photos, location }

/// Result of a system permission request that already passed the soft prompt.
enum PermissionOutcome { granted, denied, unavailable }

/// Asks the OS for a permission. Must run only after the soft prompt.
abstract class SystemPermissionClient {
  const SystemPermissionClient();

  Future<PermissionOutcome> request(SoftPermissionKind kind);
}

/// Confirms the in-app explanation before any system dialog.
typedef SoftConsent = Future<bool> Function(SoftPermissionKind kind);

/// Skips the OS dialog while the matching V1 capability is disabled.
///
/// Camera, photos, and location stay off in the V1 build. Calling the system
/// sheet without a usage description crashes iOS, so a disabled capability
/// returns [PermissionOutcome.unavailable] and never touches the OS.
class V1GuardedPermissionClient implements SystemPermissionClient {
  V1GuardedPermissionClient({
    bool? photosEnabled,
    bool? locationEnabled,
    SystemPermissionClient? delegate,
  }) : _photosEnabled = photosEnabled ?? V1CapabilityRegistry.cameraAndPhotos,
       _locationEnabled = locationEnabled ?? V1CapabilityRegistry.location,
       _delegate = delegate ?? const PermissionHandlerSystemPermissions();

  final bool _photosEnabled;
  final bool _locationEnabled;
  final SystemPermissionClient _delegate;

  @override
  Future<PermissionOutcome> request(SoftPermissionKind kind) async {
    final enabled = switch (kind) {
      SoftPermissionKind.photos => _photosEnabled,
      SoftPermissionKind.location => _locationEnabled,
    };
    if (!enabled) return PermissionOutcome.unavailable;
    return _delegate.request(kind);
  }
}

/// System permission sheet used only when the V1 capability flag is on.
class PermissionHandlerSystemPermissions implements SystemPermissionClient {
  const PermissionHandlerSystemPermissions();

  @override
  Future<PermissionOutcome> request(SoftPermissionKind kind) async {
    final permission = switch (kind) {
      SoftPermissionKind.photos => Permission.photos,
      SoftPermissionKind.location => Permission.locationWhenInUse,
    };
    try {
      final status = await permission.request();
      if (status.isGranted || status.isLimited) {
        return PermissionOutcome.granted;
      }
      return PermissionOutcome.denied;
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'rich_import_permission_failed',
        name: 'RichImportPermission',
        error: error,
        stackTrace: stackTrace,
      );
      return PermissionOutcome.denied;
    }
  }
}

final systemPermissionClientProvider = Provider<SystemPermissionClient>(
  (ref) => V1GuardedPermissionClient(),
);
