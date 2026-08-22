import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists acquisition cohort assignment and funnel milestones.
class AcquisitionCohortStore {
  AcquisitionCohortStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'acquisitionCohort';

  static AcquisitionCohortStore instance() =>
      AcquisitionCohortStore(AppServices.instance.prefs);

  Future<AcquisitionCohort?> load() async {
    final raw = await _prefs.readMap(_key);
    return AcquisitionCohort.fromJson(raw);
  }

  Future<void> save(AcquisitionCohort cohort) async {
    await _prefs.writeMap(_key, cohort.toJson());
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }
}