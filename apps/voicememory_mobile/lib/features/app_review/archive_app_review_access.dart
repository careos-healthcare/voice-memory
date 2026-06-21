import 'package:flutter/foundation.dart';

import '../paywall/archive_loop_entitlements.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_app_review_access_gate.dart';

/// App Store review unlock — only when [ArchiveAppReviewAccessGate.isEnabled].
abstract class ArchiveAppReviewAccess {
  ArchiveAppReviewAccess._();

  static bool isValidCode(String raw) {
    return raw.trim().toUpperCase() == ArchiveAppReviewAccessGate.reviewCode;
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
    await ArchiveLoopEntitlementStore(prefs).setPro(true);
    debugPrint('ARCHIVEME_APP_REVIEW_ACCESS_UNLOCKED');
    ArchiveLoopEntitlementLog.logProActive(source: 'app_review');
    return true;
  }
}
