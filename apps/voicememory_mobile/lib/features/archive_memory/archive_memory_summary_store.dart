import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_memory_summary_model.dart';

/// Local store for the latest "What ArchiveMe remembers" summary.
///
/// Only the most recent summary is kept, in its own prefs key, so the rest of
/// the schema is untouched.
class ArchiveMemorySummaryStore {
  ArchiveMemorySummaryStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archiveMemorySummary';

  static ArchiveMemorySummaryStore instance() =>
      ArchiveMemorySummaryStore(AppServices.instance.prefs);

  Future<void> saveLatest(ArchiveMemorySummary summary) async {
    await _prefs.writeMap(_key, summary.toJson());
  }

  Future<ArchiveMemorySummary?> loadLatest() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null || raw.isEmpty) return null;
    return ArchiveMemorySummary.fromJson(raw);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }
}
