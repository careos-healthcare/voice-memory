import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/objective/current_objective_snapshot_store.dart';
import 'package:archiveme_mobile/features/objective/objective_widget_pending_route_store.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_shared_storage.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/services.dart';

/// Clears legacy widget and notification shared state excluded from V1 beta.
abstract final class ExcludedNativeCapabilityCleanup {
  ExcludedNativeCapabilityCleanup._();

  static const _cleanupChannel = MethodChannel(
    'archive_me/excluded_capability_cleanup',
  );

  static const _cleanupCompletedKey =
      'excluded_native_capability_cleanup_completed_v1';

  /// Flutter prefs keys that may hold widget title/body/check-question text.
  static const legacyWidgetSnapshotKeys = {
    CurrentObjectiveSnapshotStore.widgetSnapshotKey,
    'current_objective_snapshot',
    ObjectiveWidgetPendingRouteStore.pendingRouteKey,
    QuickCaptureSharedStorage.sharedQueueKey,
    QuickCaptureSharedStorage.pendingRouteKey,
  };

  /// Runs once per install to remove plaintext widget payload from prefs.
  static Future<void> runIfNeeded(MobilePrefsStore prefs) async {
    if (V1CapabilityRegistry.nativeExtensions &&
        V1CapabilityRegistry.notifications) {
      return;
    }
    final completed = await prefs.readBool(_cleanupCompletedKey);
    if (completed == true) return;

    await clearLegacyFlutterPrefs(prefs);
    await _clearLegacyNativeSharedData();
    await prefs.writeBool(_cleanupCompletedKey, true);
  }

  static Future<void> clearLegacyFlutterPrefs(MobilePrefsStore prefs) async {
    for (final key in legacyWidgetSnapshotKeys) {
      await prefs.writeMap(key, {});
    }
    await prefs.writeString(ObjectiveWidgetPendingRouteStore.pendingRouteKey, '');
    await prefs.writeString(QuickCaptureSharedStorage.sharedQueueKey, '[]');
    await prefs.writeString(QuickCaptureSharedStorage.pendingRouteKey, '');
  }

  static Future<void> _clearLegacyNativeSharedData() async {
    try {
      await _cleanupChannel.invokeMethod<void>('clearLegacyWidgetSharedData');
    } on MissingPluginException {
      // Desktop/web test environments.
    } on PlatformException {
      // Native cleanup is best-effort; Flutter prefs are already cleared.
    }
  }
}
