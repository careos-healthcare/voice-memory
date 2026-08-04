import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../activation/activation_tracker.dart';
import 'acquisition_intent_model.dart';
import 'audience_wedge_model.dart';

/// Stores selected audience wedge for analytics and prompt tuning.
class AudienceWedgeStore {
  AudienceWedgeStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _wedgeKey = 'selectedAudienceWedge';
  static const _legacyKey = 'acquisitionIntent';

  static AudienceWedgeStore? _active() {
    if (!AppServices.isInitialized) return null;
    return AudienceWedgeStore(AppServices.instance.prefs);
  }

  static AudienceWedgeStore instance() {
    final active = _active();
    if (active == null) {
      throw StateError('AppServices not initialized');
    }
    return active;
  }

  Future<AudienceWedge?> load() async {
    final store = _active();
    if (store == null) return null;
    final raw = await store._prefs.readMap(_wedgeKey);
    final id = raw?['wedge'] as String?;
    if (id != null) {
      return AudienceWedge.values.firstWhere(
        (e) => e.id == id,
        orElse: () => AudienceWedge.notSureYet,
      );
    }
    final legacy = await store._prefs.readMap(_legacyKey);
    final legacyId = legacy?['intent'] as String?;
    return AudienceWedgeIds.fromLegacyIntentId(legacyId);
  }

  Future<DateTime?> selectedAt() async {
    final store = _active();
    if (store == null) return null;
    final raw = await store._prefs.readMap(_wedgeKey);
    final at = DateTime.tryParse(raw?['selectedAt'] as String? ?? '');
    if (at != null) return at;
    final legacy = await store._prefs.readMap(_legacyKey);
    return DateTime.tryParse(legacy?['selectedAt'] as String? ?? '');
  }

  Future<void> save(AudienceWedge wedge) async {
    final store = _active();
    if (store == null) return;
    await store._prefs.writeMap(_wedgeKey, {
      'wedge': wedge.id,
      'selectedAt': DateTime.now().toUtc().toIso8601String(),
    });
    ActivationTracker.trackOnboardingIntentSelected();
    ActivationTracker.trackAudienceWedgeSelected();
  }

  Future<String> firstRecordingPrompt() async {
    final wedge = await load();
    return wedge?.firstPrompt ?? AudienceWedge.notSureYet.firstPrompt;
  }

  /// Legacy bridge for code still using [AcquisitionIntent].
  Future<AcquisitionIntent?> legacyIntent() async {
    final wedge = await load();
    if (wedge == null) return null;
    switch (wedge) {
      case AudienceWedge.sayingYesNoCapacity:
      case AudienceWedge.sayingYesCapacity:
      case AudienceWedge.proveEnough:
      case AudienceWedge.doingMoreToFeelEnough:
      case AudienceWedge.feelingBehindWhenStop:
      case AudienceWedge.guiltAroundRest:
      case AudienceWedge.provingThroughWork:
        return AcquisitionIntent.workPressure;
      case AudienceWedge.relationshipReplay:
        return AcquisitionIntent.relationships;
      case AudienceWedge.avoidingDirectConversations:
        return AcquisitionIntent.decisionsRepeat;
      case AudienceWedge.repeatingHabit:
        return AcquisitionIntent.habitsRepeat;
      case AudienceWedge.notSureYet:
        return AcquisitionIntent.notSureYet;
    }
  }
}
