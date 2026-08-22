import 'package:archiveme_mobile/features/early_archive/early_archive_return_reminder_session.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Persists "Not now" backoff — hides the card for 24 hours.
class EarlyArchiveReturnReminderStore {
  EarlyArchiveReturnReminderStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _dismissedAtKey = 'earlyArchiveReturnReminderDismissedAt';
  static const _reminderSetKey = 'earlyArchiveReturnReminderSet';

  static EarlyArchiveReturnReminderStore instance() =>
      EarlyArchiveReturnReminderStore(AppServices.instance.prefs);

  static EarlyArchiveReturnReminderStore forPrefs(MobilePrefsStore prefs) =>
      EarlyArchiveReturnReminderStore(prefs);

  Future<bool> dismissedWithinDay() async {
    final raw = await _prefs.readMap(_dismissedAtKey);
    final dismissedAt = DateTime.tryParse(raw?['at'] as String? ?? '');
    if (dismissedAt == null) return false;
    return DateTime.now().difference(dismissedAt).inHours < 24;
  }

  Future<bool> reminderAlreadySet() async =>
      (await _prefs.readMap(_reminderSetKey))?['set'] == true;

  Future<bool> shouldOffer() async {
    if (EarlyArchiveReturnReminderSession.dismissedThisSession) return false;
    if (await dismissedWithinDay()) return false;
    if (await reminderAlreadySet()) return false;
    return true;
  }

  Future<void> markNotNow() async {
    EarlyArchiveReturnReminderSession.dismiss();
    await _prefs.writeMap(_dismissedAtKey, {
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> markReminderSet() async {
    EarlyArchiveReturnReminderSession.dismiss();
    await _prefs.writeMap(_reminderSetKey, {'set': true});
  }

  static Future<void> resetPersistedState(MobilePrefsStore prefs) async {
    EarlyArchiveReturnReminderSession.resetSessionState();
    await prefs.writeMap(_dismissedAtKey, {});
    await prefs.writeMap(_reminderSetKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore prefs) =>
      resetPersistedState(prefs);
}