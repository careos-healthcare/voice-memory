import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Lightweight local flag for the "try one small interruption" experiment.
///
/// Stores only an accepted-at timestamp on-device — no backend, no
/// notifications. Used to remember that the user committed to the experiment.
class PressureMicroExperimentStore {
  PressureMicroExperimentStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'pressureMicroExperimentAcceptedAt';

  static PressureMicroExperimentStore instance() =>
      PressureMicroExperimentStore(AppServices.instance.prefs);

  static PressureMicroExperimentStore forPrefs(MobilePrefsStore prefs) =>
      PressureMicroExperimentStore(prefs);

  Future<void> markAccepted({DateTime? now}) async {
    await _prefs.writeString(_key, (now ?? DateTime.now()).toIso8601String());
  }

  Future<DateTime?> acceptedAt() async {
    final raw = await _prefs.readString(_key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> get accepted async => (await acceptedAt()) != null;
}
