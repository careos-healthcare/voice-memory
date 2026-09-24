import 'package:archiveme_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Local store for the latest "What Thoughtprint remembers" summary.
///
/// Only the most recent summary is kept, in its own prefs key, so the rest of
/// the schema is untouched.
class ThoughtprintmorySummaryStore {
  ThoughtprintmorySummaryStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'archiveMemorySummary';

  static ThoughtprintmorySummaryStore instance() =>
      ThoughtprintmorySummaryStore(AppServices.instance.prefs);

  Future<void> saveLatest(ThoughtprintmorySummary summary) async {
    await _prefs.writeMap(_key, summary.toJson());
  }

  Future<ThoughtprintmorySummary?> loadLatest() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null || raw.isEmpty) return null;
    return ThoughtprintmorySummary.fromJson(raw);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_key, {});
  }
}