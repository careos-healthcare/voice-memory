import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../open_capture/open_capture_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';

/// Local dismiss state for skip-today — day only, no network.
class LowFrictionReturnStore {
  LowFrictionReturnStore(this._prefs);

  static const dismissPrefsKey = 'lowFrictionReturnDismiss_v1';

  final MobilePrefsStore _prefs;

  static String? _dismissedUntilDay;
  static bool _loaded = false;

  static bool get isDismissedToday {
    final day = _dismissedUntilDay;
    return day != null && day.isNotEmpty && day == _todayUtc();
  }

  static LowFrictionReturnStore instance() =>
      LowFrictionReturnStore(AppServices.instance.prefs);

  static LowFrictionReturnStore forPrefs(MobilePrefsStore prefs) =>
      LowFrictionReturnStore(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    _dismissedUntilDay = await instance()._loadDismissDay();
    _loaded = true;
  }

  Future<String?> _loadDismissDay() async {
    final raw = await _prefs.readMap(dismissPrefsKey);
    final day = raw?['dismissedUntilDay'];
    return day is String && day.isNotEmpty ? day : null;
  }

  Future<void> dismissForDay() async {
    final day = _todayUtc();
    _dismissedUntilDay = day;
    _loaded = true;
    await _prefs.writeMap(dismissPrefsKey, {
      'dismissedUntilDay': day,
      'dismissedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static String _todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _dismissedUntilDay = null;
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(dismissPrefsKey, {});
  }
}

/// Visibility and date helpers for low-friction return prompts.
abstract final class LowFrictionReturnEngine {
  LowFrictionReturnEngine._();

  static const maxEarlyEntryCount = OpenCaptureEngine.maxEarlyEntryCount;
  static const lowProofEntryMax = 2;

  static bool hasRecordedToday({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    if (entries.isEmpty) return false;
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    for (final entry in entries) {
      final entryDay = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      if (entryDay == today) return true;
    }
    return false;
  }

  static bool qualifiesForAudience({
    required int entryCount,
    required bool recordedToday,
    required bool dismissedForToday,
  }) {
    if (dismissedForToday) return false;
    if (entryCount == 0) return true;
    if (entryCount <= lowProofEntryMax) return true;
    if (entryCount <= maxEarlyEntryCount) return true;
    if (!recordedToday) return true;
    return false;
  }

  static bool shouldShow({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool isPermissionBlocked,
    required int entryCount,
    required List<JournalEntry> entries,
    required bool dismissedForToday,
    DateTime? now,
  }) {
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (isPermissionBlocked) return false;
    return qualifiesForAudience(
      entryCount: entryCount,
      recordedToday: hasRecordedToday(entries: entries, now: now),
      dismissedForToday: dismissedForToday,
    );
  }

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => OpenCaptureEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );
}
