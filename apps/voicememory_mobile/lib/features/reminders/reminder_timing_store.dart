import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../activation/activation_tracker.dart';
import 'reminder_timing_model.dart';

/// Stores reminder timing experiment state.
class ReminderTimingStore {
  ReminderTimingStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'reminderTimingExperiment';
  static const _ignoreKey = 'reminderTimingIgnoreCount';

  static ReminderTimingStore instance() =>
      ReminderTimingStore(AppServices.instance.prefs);

  Future<ReminderTimingOffer?> loadLatest() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null || raw.isEmpty) return null;
    final variants = (raw['offered'] as List?)
            ?.map((e) => ReminderTimingVariant.values.firstWhere(
                  (v) => v.id == e,
                  orElse: () => ReminderTimingVariant.tomorrowMorning,
                ))
            .toList() ??
        const [];
    final selectedId = raw['selected'] as String?;
    return ReminderTimingOffer(
      offeredVariants: variants,
      selectedVariant: selectedId == null
          ? null
          : ReminderTimingVariant.values.firstWhere(
              (v) => v.id == selectedId,
              orElse: () => ReminderTimingVariant.tomorrowMorning,
            ),
      offeredAt: DateTime.tryParse(raw['offeredAt'] as String? ?? ''),
      dismissed: raw['dismissed'] == true,
    );
  }

  Future<void> recordOffered(List<ReminderTimingVariant> variants) async {
    await _prefs.writeMap(_key, {
      'offered': variants.map((v) => v.id).toList(),
      'offeredAt': DateTime.now().toUtc().toIso8601String(),
    });
    ActivationTracker.trackReminderTimingOffered();
  }

  Future<void> recordSelected(ReminderTimingVariant variant) async {
    final raw = await _prefs.readMap(_key) ?? {};
    raw['selected'] = variant.id;
    raw['selectedAt'] = DateTime.now().toUtc().toIso8601String();
    await _prefs.writeMap(_key, raw);
    ActivationTracker.trackReminderTimingSelected();
  }

  Future<void> recordDismissed() async {
    final raw = await _prefs.readMap(_key) ?? {};
    raw['dismissed'] = true;
    raw['dismissedAt'] = DateTime.now().toUtc().toIso8601String();
    await _prefs.writeMap(_key, raw);
    await _incrementIgnore();
    ActivationTracker.trackReminderPrePromptDismissed();
  }

  Future<int> ignoreCount() async {
    final raw = await _prefs.readMap(_ignoreKey);
    return (raw?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> _incrementIgnore() async {
    final count = await ignoreCount();
    await _prefs.writeMap(_ignoreKey, {'count': count + 1});
  }

  /// Back off several days after two ignores.
  Future<bool> shouldBackoff() async {
    final count = await ignoreCount();
    if (count < 2) return false;
    final raw = await _prefs.readMap(_key);
    final dismissedAt =
        DateTime.tryParse(raw?['dismissedAt'] as String? ?? '');
    if (dismissedAt == null) return count >= 2;
    return DateTime.now().difference(dismissedAt).inDays < 3;
  }
}
