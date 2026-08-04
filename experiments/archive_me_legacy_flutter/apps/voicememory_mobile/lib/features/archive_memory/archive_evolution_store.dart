import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_evolution_model.dart';

/// Local store for the latest pattern evolution timeline.
class ArchiveEvolutionStore {
  ArchiveEvolutionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'patternEvolutionTimeline';

  static ArchiveEvolutionStore instance() =>
      ArchiveEvolutionStore(AppServices.instance.prefs);

  Future<void> saveLatest(ArchiveEvolutionTimeline timeline) async {
    await _prefs.writeMap(_key, timeline.toJson());
  }

  Future<ArchiveEvolutionTimeline?> loadLatest() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null || raw.isEmpty) return null;
    return ArchiveEvolutionTimeline.fromJson(raw);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }
}
