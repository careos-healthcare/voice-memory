import 'package:archiveme_mobile/features/belief_changes/belief_evolution_models.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

class BeliefEvolutionStore {
  BeliefEvolutionStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'beliefEvolution';

  Future<BeliefEvolutionState> load() async {
    final raw = await _prefs.readJsonMap(_key);
    return BeliefEvolutionState.fromJson(raw);
  }

  Future<void> save(BeliefEvolutionState state) async {
    await _prefs.writeJsonMap(_key, state.toJson());
  }

  Future<void> markPendingSync() async {
    final state = await load();
    await save(state);
  }

  Future<void> markSynced(DateTime at) async {
    final state = await load();
    await save(state.copyWith(lastSyncedAt: at.toUtc().toIso8601String()));
  }
}