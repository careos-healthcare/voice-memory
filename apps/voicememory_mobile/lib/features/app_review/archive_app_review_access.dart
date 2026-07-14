import 'package:flutter/foundation.dart';

import '../../config/archive_me_demo_state.dart';
import '../paywall/archive_loop_entitlements.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_app_review_access_gate.dart';

/// App Store review unlock — only when [ArchiveAppReviewAccessGate.isEnabled].
abstract class ArchiveAppReviewAccess {
  ArchiveAppReviewAccess._();

  static const unlockedPrefsKey = 'archiveAppReviewAccessUnlocked';

  static bool isValidCode(String raw) {
    return raw.trim().toUpperCase() == ArchiveAppReviewAccessGate.reviewCode;
  }

  static Future<bool> isUnlocked(MobilePrefsStore prefs) async {
    return await prefs.readBool(unlockedPrefsKey) ?? false;
  }

  static Future<bool> tryUnlock({
    required String code,
    required MobilePrefsStore prefs,
  }) async {
    if (!ArchiveAppReviewAccessGate.isEnabled) {
      return false;
    }
    if (!isValidCode(code)) {
      debugPrint('ARCHIVEME_APP_REVIEW_ACCESS_FAILED');
      return false;
    }

    final entitlementStore = ArchiveLoopEntitlementStore(prefs);
    await entitlementStore.setPro(true);
    var state = await entitlementStore.load();
    if (!state.hasCompletedFirstLoop) {
      state = await entitlementStore.markFirstLoopCompleted();
    }
    await ArchiveMeDemoState.enableReviewDemo(prefs);
    await prefs.writeBool(unlockedPrefsKey, true);

    debugPrint('ARCHIVEME_APP_REVIEW_ACCESS_UNLOCKED');
    ArchiveLoopEntitlementLog.logProActive(source: 'app_review');
    return true;
  }
}
