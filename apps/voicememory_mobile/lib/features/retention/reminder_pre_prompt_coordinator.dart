import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../reminders/reminder_timing_store.dart';

/// Stores reminder pre-prompt dismissal so we do not nag repeatedly.
class ReminderPrePromptStore {
  ReminderPrePromptStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _dismissedAtKey = 'reminderPrePromptDismissedAt';
  static const _dismissCountKey = 'reminderPrePromptDismissCount';
  static const _sessionShownKey = 'reminderPrePromptSessionShown';

  static ReminderPrePromptStore instance() =>
      ReminderPrePromptStore(AppServices.instance.prefs);

  Future<bool> shownThisSession() async {
    final raw = await _prefs.readMap(_sessionShownKey);
    return raw?['shown'] == true;
  }

  Future<void> markShownThisSession() async {
    await _prefs.writeMap(_sessionShownKey, {'shown': true});
  }

  static void resetSessionForTest() {
    // Session flag lives in prefs — tests use fresh prefs paths.
  }

  Future<void> markDismissed() async {
    final countRaw = await _prefs.readMap(_dismissCountKey);
    final count = (countRaw?['count'] as num?)?.toInt() ?? 0;
    await _prefs.writeMap(_dismissCountKey, {'count': count + 1});
    await _prefs.writeMap(_dismissedAtKey, {
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<bool> shouldOffer({required bool hasValueMoment}) async {
    if (!hasValueMoment) return false;
    if (await shownThisSession()) return false;
    final countRaw = await _prefs.readMap(_dismissCountKey);
    final count = (countRaw?['count'] as num?)?.toInt() ?? 0;
    if (count >= 3) return false;
    final dismissedRaw = await _prefs.readMap(_dismissedAtKey);
    final dismissedAt = DateTime.tryParse(dismissedRaw?['at'] as String? ?? '');
    if (dismissedAt != null) {
      final hours = DateTime.now().difference(dismissedAt).inHours;
      if (hours < 24) return false;
    }
    return true;
  }
}

enum ReminderPrePromptTrigger {
  signalAccepted,
  nextEvidenceSaved,
  signalJourneyCreated,
  secondRecordingComparison,
  signalReviewConfirmed,
}

/// When to show the pre-permission reminder explanation.
abstract class ReminderPrePromptCoordinator {
  ReminderPrePromptCoordinator._();

  static ReminderPrePromptStore _store() => ReminderPrePromptStore.instance();

  static Future<bool> shouldShow(ReminderPrePromptTrigger trigger) async {
    if (!AppServices.isInitialized) return false;
    if (await ReminderTimingStore.instance().shouldBackoff()) return false;
    return _store().shouldOffer(hasValueMoment: true);
  }

  static Future<void> markShown() => _store().markShownThisSession();

  static Future<void> markDismissed() => _store().markDismissed();
}
