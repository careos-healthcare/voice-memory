import 'package:archiveme_mobile/features/pressure_retention/pressure_micro_experiment_store.dart' show PressureMicroExperimentStore;

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local-only accepted/dismissed state for the return trigger.
///
/// Mirrors [PressureMicroExperimentStore]: timestamps in the on-device prefs
/// file, no backend, no notifications.
class PressureReturnTriggerStore {
  PressureReturnTriggerStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _acceptedKey = 'pressureReturnTriggerAcceptedAt';
  static const _dismissedKey = 'pressureReturnTriggerDismissedAt';

  static PressureReturnTriggerStore instance() =>
      PressureReturnTriggerStore(AppServices.instance.prefs);

  static PressureReturnTriggerStore forPrefs(MobilePrefsStore prefs) =>
      PressureReturnTriggerStore(prefs);

  Future<void> markAccepted({DateTime? now}) async {
    await _prefs.writeString(
      _acceptedKey,
      (now ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<void> markDismissed({DateTime? now}) async {
    await _prefs.writeString(
      _dismissedKey,
      (now ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<DateTime?> acceptedAt() async => _readTime(_acceptedKey);

  Future<DateTime?> dismissedAt() async => _readTime(_dismissedKey);

  Future<bool> get accepted async => (await acceptedAt()) != null;

  Future<bool> get dismissed async => (await dismissedAt()) != null;

  Future<DateTime?> _readTime(String key) async {
    final raw = await _prefs.readString(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}