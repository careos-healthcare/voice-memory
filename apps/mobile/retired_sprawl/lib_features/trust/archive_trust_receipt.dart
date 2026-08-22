import 'package:archiveme_mobile/features/memory/not_about_me_policy.dart';
import 'package:archiveme_mobile/features/memory/sensitive_surfacing_policy.dart';
import 'package:archiveme_mobile/features/trust/pro_trust_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';

/// Decides when the private trust receipt may appear after an important save.
///
/// Session-scoped — at most one receipt per app session. Never blocks saving
/// or recording.
abstract class ArchiveTrustReceipt {
  ArchiveTrustReceipt._();

  static var _pending = false;
  static var _shownThisSession = false;
  static var _dismissedThisSession = false;
  static String? _pendingStage;

  static String? get pendingStage => _pendingStage;

  static void noteSave({required JournalEntry entry, required int entryCount}) {
    if (entryCount < 1) return;
    if (_shownThisSession || _dismissedThisSession) return;

    final stage = _stageFor(entry: entry, entryCount: entryCount);
    if (stage == null) return;
    _pending = true;
    _pendingStage = stage;
  }

  static void noteActionItemCreated({required int entryCount}) {
    if (entryCount < 1) return;
    if (_shownThisSession || _dismissedThisSession) return;
    _pending = true;
    _pendingStage = ProTrustStage.actionItem;
  }

  static String? _stageFor({
    required JournalEntry entry,
    required int entryCount,
  }) {
    if (entry.keepExactDetails) return ProTrustStage.keepExact;
    if (entry.isPinned) return ProTrustStage.pinned;
    if (entry.archivePackId != null && entry.archivePackId!.isNotEmpty) {
      return ProTrustStage.pack;
    }
    if (entry.archiveThreadId != null && entry.archiveThreadId!.isNotEmpty) {
      return ProTrustStage.thread;
    }
    if (_isSeriousArchiveUse(entry: entry, entryCount: entryCount)) {
      return ProTrustStage.seriousUse;
    }
    return null;
  }

  static bool _isSeriousArchiveUse({
    required JournalEntry entry,
    required int entryCount,
  }) {
    if (entryCount < 2) return false;
    if (entry.treatAsNew || entry.keepSeparate) return false;
    if (NotAboutMePolicy.excludesFromProTrustReceipt(entry)) return false;
    if (SensitiveSurfacingPolicy.excludesFromProTrustReceipt(entry)) {
      return false;
    }
    return true;
  }

  /// Visible after a qualifying save — never before the first save lands.
  static bool shouldShow({required int entryCount}) =>
      entryCount >= 1 &&
      _pending &&
      !_shownThisSession &&
      !_dismissedThisSession;

  static void markShown() {
    _shownThisSession = true;
    _pending = false;
  }

  static void dismiss() {
    _dismissedThisSession = true;
    _pending = false;
    _shownThisSession = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _pending = false;
    _shownThisSession = false;
    _dismissedThisSession = false;
    _pendingStage = null;
  }
}