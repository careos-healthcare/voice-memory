import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../tomorrow_return/active_pattern_thread_model.dart';
import '../tomorrow_return/active_pattern_thread_store.dart';
import 'legacy_pattern_copy_guard.dart';
import 'pattern_display_copy_gate.dart';

/// One-time cleanup for cached pattern/belief copy that fails display quality.
abstract class PatternDisplayCacheCleanup {
  PatternDisplayCacheCleanup._();

  static const _cleanupFlagKey = 'pattern_display_cache_cleanup_v4';

  static Future<void> runOnceIfNeeded() async {
    if (!AppServices.isInitialized) return;
    final prefs = AppServices.instance.prefs;
    if (await prefs.readBool(_cleanupFlagKey) == true) return;

    final store = ActivePatternThreadStore(prefs);
    var cleared = false;

    final current = await store.readCurrentIncludingPaused();
    if (current != null && _threadHasBadCopy(current)) {
      await store.writeCurrent(null);
      cleared = true;
    }

    final inactive = await store.readLatestInactive();
    if (inactive != null && _threadHasBadCopy(inactive)) {
      await store.writeLatestInactive(null);
      cleared = true;
    }

    final history = await store.readHistory();
    if (history.isNotEmpty) {
      final kept = history.where((t) => !_threadHasBadCopy(t)).toList();
      if (kept.length != history.length) {
        cleared = true;
        await prefs.writeMap('activePatternThreadHistory', {
          'items': kept.map((t) => t.toJson()).toList(),
        });
      }
    }

    if (cleared) {
      debugPrint('ARCHIVEME_PATTERN_CACHE_CLEARED reason=bad_copy_quality_v4');
    }

    await prefs.writeBool(_cleanupFlagKey, true);
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeBool(_cleanupFlagKey, false);
  }

  @visibleForTesting
  static bool threadJsonHasBadCopy(Map<String, dynamic> json) {
    final thread = ActivePatternThread.fromJson(json);
    if (thread == null) return false;
    return _threadHasBadCopy(thread);
  }

  static bool _threadHasBadCopy(ActivePatternThread thread) {
    if (!PatternDisplayCopyGate.threadCopyIsDisplayable(thread)) return true;
    final fields = [thread.title, thread.nextPrompt, thread.watchForText];
    return fields.any(LegacyPatternCopyGuard.containsLegacyCopy);
  }
}
