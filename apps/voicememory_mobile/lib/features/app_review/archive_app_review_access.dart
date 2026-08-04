import 'package:flutter/foundation.dart';

import '../../config/archive_me_demo_state.dart';
import '../paywall/archive_loop_entitlements.dart';
import '../pro_bridge_visibility/delayed_paywall_proof_store.dart';
import '../demo/archive_me_demo_archive.dart';
import '../tomorrow_return/watch_for_store.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_app_review_access_gate.dart';
import 'archive_app_review_session.dart';

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
    var state = await entitlementStore.load();
    if (!state.hasCompletedFirstLoop) {
      state = await entitlementStore.markFirstLoopCompleted();
    }
    await ArchiveMeDemoState.enableReviewDemo(prefs);
    await WatchForStore(
      prefs,
    ).writePending(ArchiveMeDemoArchive.reviewerWatchTarget());
    await DelayedPaywallProofStore.seedReviewerMilestones(prefs: prefs);
    await prefs.writeBool(unlockedPrefsKey, true);
    ArchiveAppReviewSession.markActive();

    debugPrint('ARCHIVEME_APP_REVIEW_ACCESS_UNLOCKED');
    return true;
  }
}
