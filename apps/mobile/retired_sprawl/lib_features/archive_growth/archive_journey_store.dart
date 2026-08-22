import 'package:archiveme_mobile/features/archive_growth/archive_journey_engine.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Persists archive journey step acknowledgements.
class ArchiveJourneyStore {
  ArchiveJourneyStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _key = 'archiveJourneyComplete';

  Future<Set<ArchiveJourneyStepId>> readCompleted() async {
    final raw = await _prefs.readJsonMap(_key);
    if (raw == null) return {};
    final list = raw['steps'];
    if (list is! List) return {};
    return list
        .map((e) => e.toString())
        .map(_parseId)
        .whereType<ArchiveJourneyStepId>()
        .toSet();
  }

  Future<void> markComplete(ArchiveJourneyStepId id) async {
    final set = await readCompleted();
    set.add(id);
    await _prefs.writeJsonMap(_key, {'steps': set.map((s) => s.name).toList()});
  }

  static ArchiveJourneyStepId? _parseId(String name) {
    for (final id in ArchiveJourneyStepId.values) {
      if (id.name == name) return id;
    }
    return null;
  }
}