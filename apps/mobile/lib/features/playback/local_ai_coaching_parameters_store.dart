import 'package:archiveme_mobile/features/playback/local_ai_coach.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Prefs-backed store for on-device coaching switches.
class LocalAiCoachingParametersStore {
  LocalAiCoachingParametersStore(this._prefs);

  static const prefsKey = 'local_ai_coaching_parameters_v1';

  final MobilePrefsStore _prefs;

  Future<LocalAiCoachingParameters> load() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    return LocalAiCoachingParameters.fromJson(raw);
  }

  Future<LocalAiCoachingParameters> save(
    LocalAiCoachingParameters parameters,
  ) async {
    await _prefs.writeJsonMap(prefsKey, parameters.toJson());
    return parameters;
  }
}
