import '../../storage/mobile_prefs_store.dart';
import 'tomorrow_return_loop_models.dart';

/// Persists the latest return loop for the Patterns tab.
class TomorrowReturnLoopStore {
  TomorrowReturnLoopStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'tomorrowReturnLoop';

  Future<TomorrowReturnLoop?> read() async {
    final raw = await _prefs.readMap(_key);
    return TomorrowReturnLoop.fromJson(raw);
  }

  Future<void> write(TomorrowReturnLoop? loop) async {
    if (loop == null) {
      await _prefs.writeMap(_key, {});
      return;
    }
    await _prefs.writeMap(_key, loop.toJson());
  }
}
