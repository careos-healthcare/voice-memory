import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_compression_model.dart';

/// Persists user decisions about archive moment groups.
///
/// Hiding a group only hides the suggestion — underlying moments stay saved.
class ArchiveCompressionStore {
  ArchiveCompressionStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archiveCompressionPrefs';

  static ArchiveCompressionStore instance() =>
      ArchiveCompressionStore(AppServices.instance.prefs);

  Future<ArchiveCompressionPrefs> loadPrefs() async {
    try {
      final raw = await _prefs.readMap(_key);
      if (raw == null || raw.isEmpty) return const ArchiveCompressionPrefs();
      return ArchiveCompressionPrefs.fromJson(raw);
    } catch (_) {
      return const ArchiveCompressionPrefs();
    }
  }

  Future<void> markKept(String id) async {
    final prefs = await loadPrefs();
    await _save(
      prefs.copyWith(
        keptGroupIds: {...prefs.keptGroupIds, id},
      ),
    );
  }

  Future<void> markSplit(String id) async {
    final prefs = await loadPrefs();
    await _save(
      prefs.copyWith(
        splitGroupIds: {...prefs.splitGroupIds, id},
      ),
    );
  }

  Future<void> markHidden(String id) async {
    final prefs = await loadPrefs();
    await _save(
      prefs.copyWith(
        hiddenGroupIds: {...prefs.hiddenGroupIds, id},
      ),
    );
  }

  Future<bool> isKept(String id) async =>
      (await loadPrefs()).keptGroupIds.contains(id);

  Future<bool> isSplit(String id) async =>
      (await loadPrefs()).splitGroupIds.contains(id);

  Future<bool> isHidden(String id) async =>
      (await loadPrefs()).hiddenGroupIds.contains(id);

  Future<void> clear() async {
    await _prefs.writeMap(_key, const ArchiveCompressionPrefs().toJson());
  }

  Future<void> _save(ArchiveCompressionPrefs prefs) async {
    await _prefs.writeMap(_key, prefs.toJson());
  }
}
