import '../../config/trial_mode.dart';
import '../../services/app_services.dart';
import '../activation/activation_tracker.dart';
import '../trial/hook_rescue_decision_engine.dart';
import '../trial/hook_rescue_decision_model.dart';
import '../trial/trial_summary_engine.dart';
import '../trial/trial_summary_model.dart';
import 'local_check_in_reminder_backend.dart';
import 'tomorrow_check_in_model.dart';

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
/// A real implementation (e.g. flutter_local_notifications) can be injected
/// without touching the rest of the loop. The default is a safe no-op so the
/// app builds and runs on platforms without notifications configured.
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

/// Optional capability for passive notifications that must not make sound or
/// vibrate. Backends without this capability use their normal one-shot path.
abstract interface class QuietReminderBackend {
  Future<void> scheduleQuiet({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  });
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
  static const String _pendingRemindersKey = 'pending_check_in_reminders_v1';

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
    if (_initStarted) return;
    _initStarted = true;
    if (backend is! NoOpReminderBackend) return;
    try {
      final local = LocalCheckInReminderBackend();
      local.onTapPayload = (payload) {
        _pendingTapPayload = payload;
        ActivationTracker.trackReminderTapped();
        ActivationTracker.trackRealReminderTapped();
      };
      await local.initialize();
      if (local.isAvailable) {
        backend = local;
        await reschedulePendingReminders();
      }
    } catch (_) {
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
    } catch (_) {
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

    final reminder = _PendingReminder(
      checkInId: checkIn.id,
      when: _reminderTime(checkIn),
      payload: checkIn.id,
    );
    await _upsertPendingReminder(reminder);
    await backend.schedule(
      checkInId: checkIn.id,
      title: reminderTitle,
      body: reminderBody,
      when: reminder.when,
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
    await _removePendingReminder(checkInId);
    if (backend.isAvailable) {
      await backend.cancel(checkInId);
    }
    ActivationTracker.trackReminderCancelled();
    ActivationTracker.trackRealReminderCancelled();
  }

  static Future<void> clearAll() async {
    await _writePendingReminders(const []);
    if (backend.isAvailable) {
      await backend.clearAll();
    }
  }

  /// Recreates future notification requests from secure preferences.
  ///
  /// Android normally performs this at boot through
  /// `CheckInReminderBootReceiver`. This reconciliation is also run at app
  /// startup and by iOS background refresh so app upgrades or OS cleanup
  /// cannot silently lose a pending tomorrow check-in.
  static Future<void> reschedulePendingReminders({DateTime? now}) async {
    if (!AppServices.isInitialized ||
        !await remindersEnabled() ||
        !backend.isAvailable) {
      return;
    }

    final cutoff = now ?? DateTime.now();
    final pending = await _readPendingReminders();
    final future = pending.where((item) => item.when.isAfter(cutoff)).toList();
    for (final reminder in future) {
      await backend.schedule(
        checkInId: reminder.checkInId,
        title: reminderTitle,
        body: reminderBody,
        when: reminder.when,
        payload: reminder.payload,
      );
    }
    if (future.length != pending.length) {
      await _writePendingReminders(future);
    }
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
    } catch (_) {
      return null;
    }
  }

  static Future<List<_PendingReminder>> _readPendingReminders() async {
    if (!AppServices.isInitialized) return const [];
    try {
      final raw = await AppServices.instance.prefs.readMap(
        _pendingRemindersKey,
      );
      final items = raw?['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map(
            (item) =>
                _PendingReminder.fromJson(Map<String, dynamic>.from(item)),
          )
          .whereType<_PendingReminder>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _writePendingReminders(
    List<_PendingReminder> reminders,
  ) async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(_pendingRemindersKey, {
      'items': reminders.map((item) => item.toJson()).toList(),
    });
  }

  static Future<void> _upsertPendingReminder(_PendingReminder reminder) async {
    final pending = List<_PendingReminder>.of(await _readPendingReminders());
    pending.removeWhere((item) => item.checkInId == reminder.checkInId);
    pending.add(reminder);
    await _writePendingReminders(pending);
  }

  static Future<void> _removePendingReminder(String checkInId) async {
    final pending = List<_PendingReminder>.of(await _readPendingReminders());
    pending.removeWhere((item) => item.checkInId == checkInId);
    await _writePendingReminders(pending);
  }
}

class _PendingReminder {
  const _PendingReminder({
    required this.checkInId,
    required this.when,
    required this.payload,
  });

  final String checkInId;
  final DateTime when;
  final String payload;

  Map<String, dynamic> toJson() => {
    'checkInId': checkInId,
    'when': when.toIso8601String(),
    'payload': payload,
  };

  static _PendingReminder? fromJson(Map<String, dynamic> json) {
    final checkInId = json['checkInId'] as String?;
    final when = DateTime.tryParse(json['when'] as String? ?? '');
    final payload = json['payload'] as String?;
    if (checkInId == null ||
        checkInId.isEmpty ||
        when == null ||
        payload == null ||
        payload.isEmpty) {
      return null;
    }
    return _PendingReminder(checkInId: checkInId, when: when, payload: payload);
  }
}
