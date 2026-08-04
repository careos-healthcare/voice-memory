import '../../storage/mobile_prefs_store.dart';
import 'return_reason_models.dart';

/// Persists return-reason state between Discover exit and Archive visit.
class ReturnReasonStore {
  ReturnReasonStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _stateKey = 'returnReasonState';

  Future<ReturnReasonState?> read() async {
    final raw = await _prefs.readJsonMap(_stateKey);
    return ReturnReasonState.fromJson(raw);
  }

  Future<void> write(ReturnReasonState? state) async {
    if (state == null || !state.hasContent) {
      await _prefs.writeJsonMap(_stateKey, {});
      return;
    }
    await _prefs.writeJsonMap(_stateKey, state.toJson());
  }

  Future<void> clear() => write(null);
}
