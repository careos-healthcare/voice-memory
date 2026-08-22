import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart';

/// Session-scoped seen/dismiss for the first-aha card — one per session.
class AhaMomentSession {
  AhaMomentSession._();

  static var _shown = false;
  static var _dismissed = false;

  static bool get hidden => _shown || _dismissed;

  static void markShown() => _shown = true;

  static void dismiss() {
    _dismissed = true;
    _shown = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _shown = false;
    _dismissed = false;
  }
}

/// Persistent first-aha completion — after feedback or dismiss, do not repeat.
class AhaMomentStore {
  AhaMomentStore._();

  static const _prefsKey = 'ahaMoment';

  static var _firstCompleted = false;
  static var _loaded = false;

  static bool get firstAhaCompleted => _firstCompleted;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (!AppServices.isInitialized) {
      _loaded = true;
      return;
    }
    try {
      final raw = await AppServices.instance.prefs.readMap(_prefsKey);
      if (raw != null) {
        _firstCompleted = raw['firstCompleted'] == true;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Fail closed — treat as incomplete so the card can still appear.
    }
    _loaded = true;
  }

  static Future<void> markFirstAhaCompleted() async {
    _firstCompleted = true;
    _loaded = true;
    if (!AppServices.isInitialized) return;
    try {
      await AppServices.instance.prefs.writeMap(_prefsKey, {
        'firstCompleted': true,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // In-memory completion still applies this session.
    }
  }

  @visibleForTesting
  static void applyLoaded({required bool firstCompleted}) {
    _firstCompleted = firstCompleted;
    _loaded = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _firstCompleted = false;
    _loaded = false;
    AhaMomentSession.resetForTest();
  }
}