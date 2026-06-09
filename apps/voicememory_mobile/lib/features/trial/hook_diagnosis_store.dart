import '../../storage/mobile_prefs_store.dart';
import '../../services/app_services.dart';
import '../activation/activation_events_store.dart';
import 'hook_diagnosis_model.dart';

class HookDiagnosisStore {
  HookDiagnosisStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _eventsKey = 'hook_diagnosis_events';
  static const _missedPromptedKey = 'hook_diagnosis_missed_prompted';
  static const _maxEvents = 200;

  static HookDiagnosisStore instance() =>
      HookDiagnosisStore(AppServices.instance.prefs);

  Future<void> append(HookDiagnosisEvent event) async {
    final all = await loadAll();
    final next = [event, ...all].take(_maxEvents).toList();
    await _prefs.writeMap(_eventsKey, {
      'items': next.map((e) => e.toJson()).toList(),
    });
  }

  Future<List<HookDiagnosisEvent>> loadAll() async {
    final raw = await _prefs.readMap(_eventsKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map((e) => HookDiagnosisEvent.fromJson(
              e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map),
            ))
        .whereType<HookDiagnosisEvent>()
        .toList();
  }

  Future<void> clear() async {
    await _prefs.writeMap(_eventsKey, {'items': []});
    await _prefs.writeMap(_missedPromptedKey, {'ids': []});
  }

  Future<HookDiagnosisSummary> summary() async {
    final events = await loadAll();
    final activation = await ActivationEventsStore(_prefs).read();
    return buildHookDiagnosisSummary(
      events: events,
      checkInsCreated: activation.tomorrowCheckInCreated,
      checkInsDueShown: activation.tomorrowCheckInDueShown,
      checkInsCompleted: activation.tomorrowCheckInCompleted,
      examplesOpenedCount: activation.checkInExamplesOpened,
      checkInClarityCardShownCount: activation.checkInClarityCardShown,
      checkInMomentRecordedCount: activation.checkInMomentRecorded,
    );
  }

  Future<bool> wasMissedReasonPromptShown(String checkInId) async {
    final ids = await _readMissedPromptedIds();
    return ids.contains(checkInId);
  }

  Future<void> markMissedReasonPromptShown(String checkInId) async {
    final ids = await _readMissedPromptedIds();
    if (ids.contains(checkInId)) return;
    ids.add(checkInId);
    await _prefs.writeMap(_missedPromptedKey, {'ids': ids.toList()});
  }

  Future<Set<String>> _readMissedPromptedIds() async {
    final raw = await _prefs.readMap(_missedPromptedKey);
    if (raw == null || raw.isEmpty) return {};
    final list = raw['ids'];
    if (list is! List) return {};
    return list.map((e) => '$e').toSet();
  }
}
