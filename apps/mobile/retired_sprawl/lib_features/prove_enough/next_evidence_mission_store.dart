import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists the latest prove_enough next-evidence mission for loop surfaces.
class NextEvidenceMissionStore {
  NextEvidenceMissionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'proveEnoughNextMission';

  static NextEvidenceMissionStore instance() =>
      NextEvidenceMissionStore(AppServices.instance.prefs);

  static NextEvidenceMissionStore forPrefs(MobilePrefsStore prefs) =>
      NextEvidenceMissionStore(prefs);

  Future<void> save(NextEvidenceMissionModel mission) async {
    await _prefs.writeMap(_key, mission.toJson());
  }

  Future<NextEvidenceMissionModel?> load() async {
    final raw = await _prefs.readMap(_key);
    return NextEvidenceMissionModel.fromJson(raw);
  }
}