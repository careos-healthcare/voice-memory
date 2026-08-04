import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../router/app_router.dart';
import '../../../services/app_services.dart';
import '../models/curiosity_hook.dart';
import '../repositories/curiosity_hook_repository.dart';
import '../yesterdays_snapshot_copy.dart';
import 'curiosity_notification_scheduler.dart';

/// Routes curiosity notification taps to Yesterday's Snapshot.
abstract final class CuriosityNotificationLaunchController {
  CuriosityNotificationLaunchController._();

  static bool _initStarted = false;
  static CuriosityHook? _pendingHook;

  @visibleForTesting
  static bool Function(CuriosityHook hook)? navigateOverrideForTest;

  static bool get hasPendingHook => _pendingHook != null;

  /// Initializes tap handling and processes cold-start notification launches.
  ///
  /// Never throws — notification routing must not block app startup.
  static Future<void> ensureInitialized({
    CuriosityNotificationScheduler? scheduler,
    CuriosityHookRepository? repository,
  }) async {
    if (_initStarted) return;
    _initStarted = true;

    try {
      final resolvedScheduler =
          scheduler ?? CuriosityNotificationScheduler.instance();
      resolvedScheduler.onTapHookId = (hookId) {
        unawaited(handleHookIdTap(hookId, repository: repository));
      };
      await resolvedScheduler.initialize();
      if (!resolvedScheduler.isAvailable) return;

      final coldStartHookId = await resolvedScheduler.readColdStartHookId();
      if (coldStartHookId != null) {
        await handleHookIdTap(coldStartHookId, repository: repository);
      }
    } catch (_) {
      // Notification routing is optional; never crash startup.
    }
  }

  /// Resolves [hookId] and queues navigation when the hook is still valid.
  static Future<void> handleHookIdTap(
    String hookId, {
    CuriosityHookRepository? repository,
  }) async {
    try {
      final hook = await _resolveHook(hookId, repository: repository);
      if (hook == null) return;
      _pendingHook = hook;
      if (_navigateToSnapshot(hook)) {
        _pendingHook = null;
      }
    } catch (_) {
      // Ignore tap handling failures.
    }
  }

  /// Consumes a hook queued during cold start for router redirect handling.
  static CuriosityHook? takePendingHook() {
    final hook = _pendingHook;
    _pendingHook = null;
    return hook;
  }

  static Future<CuriosityHook?> _resolveHook(
    String hookId, {
    CuriosityHookRepository? repository,
  }) async {
    if (!AppServices.isInitialized) return null;
    await LocalCuriosityHookRepository.ensureLoaded();
    final repo = repository ?? LocalCuriosityHookRepository.instance();
    final hook = await repo.fetchById(hookId);
    if (hook == null || hook.isConsumed) return null;
    return hook;
  }

  static bool _navigateToSnapshot(CuriosityHook hook) {
    final override = navigateOverrideForTest;
    if (override != null) {
      final navigated = override(hook);
      if (!navigated) {
        _pendingHook = hook;
      }
      return navigated;
    }
    try {
      appRouter.push(YesterdaysSnapshotCopy.route, extra: hook);
      return true;
    } catch (_) {
      _pendingHook = hook;
      return false;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _initStarted = false;
    _pendingHook = null;
    navigateOverrideForTest = null;
  }
}
