import '../../storage/mobile_prefs_store.dart';
import 'archive_app_review_access.dart';

/// In-memory App Review unlock state — hydrated once from prefs at startup.
abstract final class ArchiveAppReviewSession {
  ArchiveAppReviewSession._();

  static bool _active = false;

  static bool get isActive => _active;

  static Future<void> hydrateFromPrefs(MobilePrefsStore prefs) async {
    _active = await ArchiveAppReviewAccess.isUnlocked(prefs);
  }

  static void markActive() {
    _active = true;
  }

  static void resetForTest() {
    _active = false;
  }
}
