import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Tracks whether the one free monthly ambition pressure review was used.
class MonthlyAmbitionPressureReviewStore {
  MonthlyAmbitionPressureReviewStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'proveEnoughMonthlyReviewAccess';

  static MonthlyAmbitionPressureReviewStore instance() =>
      MonthlyAmbitionPressureReviewStore(AppServices.instance.prefs);

  static MonthlyAmbitionPressureReviewStore forPrefs(MobilePrefsStore prefs) =>
      MonthlyAmbitionPressureReviewStore(prefs);

  Future<bool> freeReviewConsumed() async {
    final raw = await _prefs.readMap(_key);
    return raw?['freeReviewUsed'] == true;
  }

  Future<void> markFreeReviewUsed() async {
    await _prefs.writeMap(_key, {
      'freeReviewUsed': true,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}