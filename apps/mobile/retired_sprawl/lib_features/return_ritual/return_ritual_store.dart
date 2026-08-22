import 'package:archiveme_mobile/features/return_ritual/return_ritual_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local-only persistence for the personal return ritual choice.
class ReturnRitualStore {
  ReturnRitualStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const stateKey = 'returnRitualChoice';

  Future<ReturnRitualChoice?> load() async {
    final raw = await _prefs.readJsonMap(stateKey);
    if (raw == null || raw.isEmpty) return null;
    final choice = ReturnRitualChoice.fromJson(raw);
    return choice.isValid ? choice : null;
  }

  Future<void> save(ReturnRitualChoice choice) async {
    if (!choice.isValid) {
      await clear();
      return;
    }
    await _prefs.writeJsonMap(stateKey, choice.toJson());
  }

  Future<void> clear() async {
    await _prefs.writeJsonMap(stateKey, {});
  }
}