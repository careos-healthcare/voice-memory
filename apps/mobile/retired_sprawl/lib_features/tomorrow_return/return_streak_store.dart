import 'package:archiveme_mobile/features/tomorrow_return/return_streak_model.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

class ReturnStreakStore {
  ReturnStreakStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'returnStreak';

  Future<ReturnStreak?> read() async {
    final raw = await _prefs.readMap(_key);
    return ReturnStreak.fromJson(raw);
  }

  Future<void> write(ReturnStreak? streak) async {
    if (streak == null) {
      await _prefs.writeMap(_key, {});
      return;
    }
    await _prefs.writeMap(_key, streak.toJson());
  }
}