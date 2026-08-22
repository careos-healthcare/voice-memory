import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// What happened when the user accepted the day-2 reminder offer.
enum DayTwoReminderOutcome { scheduled, permissionDenied, notAvailable }

/// Day 2 Gentle Reminder — one optional reminder offered once, right after
/// the very first successful save.
///
/// Guardrails by construction:
/// - The offer exists only at entry count 1 (value already created); nothing
///   is ever asked before the first save.
/// - One ask, one reminder: any answer (accepted, declined, denied,
///   unavailable) resolves the offer permanently — it never re-asks and
///   never repeats.
/// - Notification permission is requested only after the user explicitly
///   taps "Remind me tomorrow", and a denial fails quietly.
abstract class DayTwoReminder {
  DayTwoReminder._();

  // Prompt copy.
  static const String promptTitle = 'Check this tomorrow?';
  static const String promptBody =
      'ArchiveMe can remind you once to check whether this returned, faded, '
      'or changed.';
  static const String acceptLabel = 'Remind me tomorrow';
  static const String declineLabel = 'Not now';

  // Notification copy.
  static const String notificationTitle = 'Check what changed';
  static const String notificationBody =
      'See whether yesterday\u2019s thread returned, faded, or changed.';

  // Quiet confirmations after an answer.
  static const String scheduledLine = 'One reminder set for tomorrow.';
  static const String unavailableLine =
      'Notifications are off, so no reminder was set. '
      'Checking tomorrow works without one.';

  /// Stable id — used as the notification id seed and tap payload.
  static const String reminderId = 'day_two_reminder';

  /// Prefs key holding the resolution status.
  static const String prefsKey = 'day_two_reminder';

  /// Pure gate: only the very first save, only while unresolved.
  static bool shouldOffer({
    required int entryCount,
    required bool alreadyResolved,
  }) => entryCount == 1 && !alreadyResolved;
}

/// Handles persistence and scheduling for the day-2 reminder offer.
/// Production resolves prefs/backend lazily; tests inject both.
class DayTwoReminderCoordinator {
  DayTwoReminderCoordinator({
    this._prefs,
    this._backend,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MobilePrefsStore? _prefs;
  final CheckInReminderBackend? _backend;
  final DateTime Function() _now;

  MobilePrefsStore? get _resolvedPrefs {
    if (_prefs != null) return _prefs;
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  /// True once the user has answered the offer in any way.
  Future<bool> alreadyResolved() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return true; // No persistence — never risk re-asking.
    try {
      final data = await prefs.readMap(DayTwoReminder.prefsKey);
      return data?['status'] is String;
    } catch (_, stackTrace) {
      return true;
    }
  }

  /// Whether the offer should render right now.
  Future<bool> shouldOffer({required int entryCount}) async =>
      DayTwoReminder.shouldOffer(
        entryCount: entryCount,
        alreadyResolved: await alreadyResolved(),
      );

  /// "Remind me tomorrow": request permission (only now), schedule exactly
  /// one reminder for tomorrow morning, and resolve the offer. Denied or
  /// unavailable notifications fail quietly — the offer still resolves so
  /// it never nags again.
  Future<DayTwoReminderOutcome> accept() async {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.day2ReminderAccepted,
      entryCount: 1,
    );

    final backend = await _readyBackend();
    if (backend == null || !backend.isAvailable) {
      await _markResolved('not_available');
      return DayTwoReminderOutcome.notAvailable;
    }

    final granted = await _safePermission(backend);
    if (!granted) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.day2ReminderPermissionDenied,
        entryCount: 1,
      );
      await _markResolved('permission_denied');
      return DayTwoReminderOutcome.permissionDenied;
    }

    try {
      await backend.schedule(
        checkInId: DayTwoReminder.reminderId,
        title: DayTwoReminder.notificationTitle,
        body: DayTwoReminder.notificationBody,
        when: _tomorrowMorning(),
        payload: DayTwoReminder.reminderId,
      );
    } catch (_, stackTrace) {
      await _markResolved('not_available');
      return DayTwoReminderOutcome.notAvailable;
    }
    await _markResolved('scheduled');
    return DayTwoReminderOutcome.scheduled;
  }

  /// "Not now": resolve quietly; nothing is scheduled, nothing re-asks.
  Future<void> decline() async {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.day2ReminderDeclined,
      entryCount: 1,
    );
    await _markResolved('declined');
  }

  Future<CheckInReminderBackend?> _readyBackend() async {
    if (_backend != null) return _backend;
    try {
      await CheckInReminderService.ensureInitialized();
      return CheckInReminderService.backend;
    } catch (_, stackTrace) {
      return null;
    }
  }

  Future<bool> _safePermission(CheckInReminderBackend backend) async {
    try {
      return await backend.requestPermission();
    } catch (_, stackTrace) {
      return false;
    }
  }

  Future<void> _markResolved(String status) async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return;
    try {
      await prefs.writeMap(DayTwoReminder.prefsKey, {
        'status': status,
        'resolved_at': _now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Persistence failures never surface; worst case the offer is gone
      // for this session anyway.
    }
  }

  /// Tomorrow at 9:00 local time — once, never recurring.
  DateTime _tomorrowMorning() {
    final now = _now();
    return DateTime(now.year, now.month, now.day + 1, 9);
  }
}