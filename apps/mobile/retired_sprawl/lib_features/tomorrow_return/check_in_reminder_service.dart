import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/config/trial_mode.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/notifications/reminder_backend_provider.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:archiveme_mobile/features/trial/hook_rescue_decision_engine.dart';
import 'package:archiveme_mobile/features/trial/hook_rescue_decision_model.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_engine.dart';
import 'package:archiveme_mobile/features/trial/trial_summary_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Result of an attempt to schedule a tomorrow check-in reminder.
enum ReminderScheduleOutcome {
  notGated,
  notAvailable,
  permissionDenied,
  disabled,
  scheduled,
}

/// Pluggable local-notification backend.
///
/// V1 beta uses stub backends only — see `experiments/archive/local_notifications/`.
/// Tests may inject a fake backend.
abstract interface class CheckInReminderBackend {
  bool get isAvailable;

  /// Prepares the backend (plugin init, channels). Safe to call more than once.
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  });
  Future<void> cancel(String checkInId);
  Future<void> clearAll();
}

/// Default backend: no plugin wired, everything is a no-op.
class NoOpReminderBackend implements CheckInReminderBackend {
  const NoOpReminderBackend();

  @override
  bool get isAvailable => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {}

  @override
  Future<void> cancel(String checkInId) async {}

  @override
  Future<void> clearAll() async {}
}

/// Safe, diagnosis-gated local reminder for the tomorrow check-in.
abstract class CheckInReminderService {
  CheckInReminderService._();

  /// Consumer-visible reminder copy.
  static const String reminderTitle = 'Your check is ready';
  static const String reminderBody = 'Answer the check you chose yesterday.';

  /// Backend abstraction. Defaults to a safe no-op until [ensureInitialized]
  /// swaps in the real local-notification backend (when the plugin works).
  /// Tests may inject a fake backend.
  static CheckInReminderBackend backend = const NoOpReminderBackend();

  static bool _initStarted = false;
  static String? _pendingTapPayload;

  /// User preference key — reminders only fire when the user turns them on.
  static const String _remindersEnabledKey = 'check_in_reminders_enabled';

  static void setBackendForTest(CheckInReminderBackend value) {
    backend = value;
    _initStarted = true;
  }

  static void resetBackendForTest() {
    backend = const NoOpReminderBackend();
    _initStarted = false;
    _pendingTapPayload = null;
  }

  static bool get pluginAvailable => backend.isAvailable;

  /// Initializes the real backend once. Never throws; falls back to no-op when
  /// the plugin is unavailable or initialization fails. Does NOT request
  /// permission (that happens only after the user chooses tomorrow's check).
  static Future<void> ensureInitialized() async {
    if (!V1CapabilityRegistry.notifications) return;
    if (_initStarted) return;
    _initStarted = true;
    if (backend is! NoOpReminderBackend) return;
    try {
      final local = createLocalCheckInReminderBackend();
      local.onTapPayload = (payload) {
        _pendingTapPayload = payload;
        ActivationTracker.trackReminderTapped();
        ActivationTracker.trackRealReminderTapped();
      };
      await local.initialize();
      if (local.isAvailable) backend = local;
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Stay on the safe no-op backend.
    }
  }

  /// A notification the user tapped to open the app, consumed once.
  static String? consumeTapPayload() {
    final payload = _pendingTapPayload;
    _pendingTapPayload = null;
    return payload;
  }

  /// Whether the user has turned check-in reminders on. Defaults to off.
  static Future<bool> remindersEnabled() async {
    if (!AppServices.isInitialized) return false;
    try {
      return await AppServices.instance.prefs.readBool(_remindersEnabledKey) ==
          true;
    } catch (_, stackTrace) {
      return false;
    }
  }

  static Future<void> setRemindersEnabled(bool value) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeBool(_remindersEnabledKey, value);
    if (!value) {
      await clearAll();
    }
  }

  /// Requests permission (at accept time, not launch) and schedules one
  /// reminder. Records metrics for every branch.
  static Future<ReminderScheduleOutcome> scheduleTomorrowCheckInReminder(
    TomorrowCheckIn checkIn,
  ) async {
    if (!await remindersEnabled()) {
      return ReminderScheduleOutcome.disabled;
    }
    if (!backend.isAvailable) {
      ActivationTracker.trackReminderNotAvailable();
      ActivationTracker.trackRealReminderUnavailable();
      return ReminderScheduleOutcome.notAvailable;
    }

    ActivationTracker.trackReminderPermissionRequested();
    ActivationTracker.trackRealReminderPermissionRequested();
    final granted = await backend.requestPermission();
    if (!granted) {
      ActivationTracker.trackReminderPermissionDenied();
      ActivationTracker.trackRealReminderPermissionDenied();
      return ReminderScheduleOutcome.permissionDenied;
    }
    ActivationTracker.trackReminderPermissionGranted();
    ActivationTracker.trackRealReminderPermissionGranted();

    await backend.schedule(
      checkInId: checkIn.id,
      title: reminderTitle,
      body: reminderBody,
      when: _reminderTime(checkIn),
      payload: checkIn.id,
    );
    ActivationTracker.trackReminderScheduled();
    ActivationTracker.trackRealReminderScheduled();
    return ReminderScheduleOutcome.scheduled;
  }

  /// Requests OS notification permission without scheduling. Used by the
  /// settings toggle when there is no active check-in to schedule yet.
  static Future<bool> requestPermissionOnly() async {
    if (!backend.isAvailable) {
      ActivationTracker.trackReminderNotAvailable();
      ActivationTracker.trackRealReminderUnavailable();
      return false;
    }
    ActivationTracker.trackReminderPermissionRequested();
    ActivationTracker.trackRealReminderPermissionRequested();
    final granted = await backend.requestPermission();
    if (granted) {
      ActivationTracker.trackReminderPermissionGranted();
      ActivationTracker.trackRealReminderPermissionGranted();
    } else {
      ActivationTracker.trackReminderPermissionDenied();
      ActivationTracker.trackRealReminderPermissionDenied();
    }
    return granted;
  }

  static Future<void> cancelCheckInReminder(String checkInId) async {
    if (!backend.isAvailable) return;
    await backend.cancel(checkInId);
    ActivationTracker.trackReminderCancelled();
    ActivationTracker.trackRealReminderCancelled();
  }

  static Future<void> clearAll() async {
    if (!backend.isAvailable) return;
    await backend.clearAll();
  }

  /// Schedules only when diagnosis says reminders are worth testing.
  ///
  /// Gate: the rescue decision includes reminder AND readiness is ready, OR
  /// trial mode is on and readiness is ready.
  static Future<ReminderScheduleOutcome> maybeScheduleForCheckIn(
    TomorrowCheckIn checkIn, {
    TrialSummaryModel? summary,
  }) async {
    final s = summary ?? await _safeSummary();
    if (s == null) return ReminderScheduleOutcome.notGated;

    final ready = s.reminderReadiness == ReminderReadiness.ready;
    final decision = const HookRescueDecisionEngine().decide(s);
    final gated =
        (decision.includes(HookRescueAction.reminder) && ready) ||
        (TrialMode.enabled && ready);
    if (!gated) return ReminderScheduleOutcome.notGated;

    return scheduleTomorrowCheckInReminder(checkIn);
  }

  static DateTime _reminderTime(TomorrowCheckIn checkIn) {
    final parts = checkIn.targetDate.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d, 9);
      }
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  static Future<TrialSummaryModel?> _safeSummary() async {
    try {
      return await const TrialSummaryEngine().build();
    } catch (_, stackTrace) {
      return null;
    }
  }
}