import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/archive_compression/archive_compression_engine.dart';
import 'package:archiveme_mobile/features/archive_compression/archive_compression_model.dart';
import 'package:archiveme_mobile/features/archive_compression/archive_compression_store.dart';
import 'package:archiveme_mobile/features/moments/key_moment_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Loads similar-moment groups and persists keep / split / hide decisions.
abstract class ArchiveCompressionCoordinator {
  ArchiveCompressionCoordinator._();

  static ArchiveCompressionStore _store() => ArchiveCompressionStore.instance();

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
    } catch (_, stackTrace) {
      return const [];
    }
  }

  static Future<void> markKept(ArchiveMomentGroup group) async {
    if (!AppServices.isInitialized) return;
    try {
      await _store().markKept(group.id);
      ActivationTracker.trackArchiveCompressionKept();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
  }

  static Future<void> markSplit(ArchiveMomentGroup group) async {
    if (!AppServices.isInitialized) return;
    try {
      await _store().markSplit(group.id);
      ActivationTracker.trackArchiveCompressionSplit();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
  }

  static Future<void> markHidden(ArchiveMomentGroup group) async {
    if (!AppServices.isInitialized) return;
    try {
      await _store().markHidden(group.id);
      ActivationTracker.trackArchiveCompressionHidden();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
  }

  static Future<void> clear() async {
    if (!AppServices.isInitialized) return;
    try {
      await _store().clear();
    } catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      }
  }
}