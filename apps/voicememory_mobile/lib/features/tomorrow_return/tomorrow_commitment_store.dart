import '../../storage/mobile_prefs_store.dart';
import 'tomorrow_commitment_model.dart';

/// Persists the user's tomorrow return commitment locally.
class TomorrowCommitmentStore {
  TomorrowCommitmentStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'tomorrowCommitment';

  Future<TomorrowCommitment?> read() async {
    final raw = await _prefs.readMap(_key);
    return TomorrowCommitment.fromJson(raw);
  }

  Future<void> write(TomorrowCommitment? commitment) async {
    if (commitment == null) {
      await _prefs.writeMap(_key, {});
      return;
    }
    await _prefs.writeMap(_key, commitment.toJson());
  }
}
