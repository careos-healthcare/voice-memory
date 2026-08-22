import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/router/capture_routine_route.dart';
import 'package:flutter/foundation.dart';

/// Routes notification taps that carry a routine payload to `/record?routine=…`.
abstract final class CaptureRoutineLaunchController {
  CaptureRoutineLaunchController._();

  static bool _initStarted = false;
  static JournalRoutineKind? _pendingRoutine;

  @visibleForTesting
  static bool Function(JournalRoutineKind routine)? navigateOverrideForTest;

  static JournalRoutineKind? get pendingRoutine => _pendingRoutine;

  static Future<void> ensureInitialized() async {
    if (_initStarted) return;
    _initStarted = true;

    try {
      handleNotificationPayload(CheckInReminderService.consumeTapPayload());
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Notification routing must never block startup.
    }
  }

  static void handleNotificationPayload(String? payload) {
    final routine = journalRoutineKindFromNotificationPayload(payload);
    if (routine == null) return;
    _queueNavigation(routine);
  }

  static JournalRoutineKind? takePendingRoutine() {
    final routine = _pendingRoutine;
    _pendingRoutine = null;
    return routine;
  }

  static void _queueNavigation(JournalRoutineKind routine) {
    _pendingRoutine = routine;
    final override = navigateOverrideForTest;
    if (override != null) {
      if (override(routine)) {
        _pendingRoutine = null;
      }
      return;
    }
    try {
      appRouter.go(captureRecordPath(routine: routine));
      _pendingRoutine = null;
    } catch (_, stackTrace) { // ignore: silent_catch_audit — deferred capture route navigation
      _pendingRoutine = routine;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _initStarted = false;
    _pendingRoutine = null;
    navigateOverrideForTest = null;
  }
}