import '../../config/screenshot_mode.dart';
import '../../config/screenshot_sample_data.dart';
import '../../services/app_services.dart';
import '../activation/activation_tracker.dart';
import '../moments/key_moment_store.dart';
import 'archive_compression_engine.dart';
import 'archive_compression_model.dart';
import 'archive_compression_store.dart';

/// Loads similar-moment groups and persists keep / split / hide decisions.
abstract final class ArchiveCompressionCoordinator {
  ArchiveCompressionCoordinator._();

  static ArchiveCompressionStore _store() =>
      ArchiveCompressionStore.instance();

  static Future<List<ArchiveMomentGroup>> loadGroups() async {
    if (ScreenshotMode.archiveCompressionPreview) {
      return [ScreenshotSampleData.archiveCompressionGroupSample];
    }
    if (!AppServices.isInitialized) return const [];
    try {
      final moments = await KeyMomentStore.instance().loadAll();
      final built = buildArchiveMomentGroups(moments);
      final prefs = await _store().loadPrefs();
      return built
          .where(
            (g) =>
                !prefs.hiddenGroupIds.contains(g.id) &&
                !prefs.splitGroupIds.contains(g.id) &&
                !prefs.keptGroupIds.contains(g.id),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> markKept(ArchiveMomentGroup group) async {
    if (!AppServices.isInitialized) return;
    try {
      await _store().markKept(group.id);
      ActivationTracker.trackArchiveCompressionKept();
    } catch (_) {}
  }

  static Future<void> markSplit(ArchiveMomentGroup group) async {
    if (!AppServices.isInitialized) return;
    try {
      await _store().markSplit(group.id);
      ActivationTracker.trackArchiveCompressionSplit();
    } catch (_) {}
  }

  static Future<void> markHidden(ArchiveMomentGroup group) async {
    if (!AppServices.isInitialized) return;
    try {
      await _store().markHidden(group.id);
      ActivationTracker.trackArchiveCompressionHidden();
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (!AppServices.isInitialized) return;
    try {
      await _store().clear();
    } catch (_) {}
  }
}
