import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../come_back_tomorrow/come_back_tomorrow_v2_engine.dart';
import '../come_back_tomorrow/come_back_tomorrow_v2_model.dart';
import '../come_back_tomorrow/come_back_tomorrow_v2_store.dart';
import 'quiet_signal_copy.dart';
import 'quiet_signal_model.dart';

/// Visibility gates for quiet / not-seen-recently surfaces.
abstract final class QuietSignalGates {
  QuietSignalGates._();

  static bool archiveAllows(List<JournalEntry> entries) =>
      ComeBackTomorrowV2Gates.archiveAllows(entries);

  static bool shouldShowOnRecordReady({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required QuietSignal? signal,
    required bool showReturnDayFlow,
  }) =>
      isReady &&
      !isRecording &&
      !isPostSave &&
      signal != null &&
      !showReturnDayFlow;

  static bool shouldShowOnPatterns({
    required QuietSignal? signal,
    required bool viewingConfirmedRepeatOrTimeline,
  }) =>
      signal != null && viewingConfirmedRepeatOrTimeline;
}

/// Detects when an active watch target has not appeared in recent saves.
abstract final class QuietSignalEngine {
  QuietSignalEngine._();

  static QuietSignal? build({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    final target = ComeBackTomorrowV2Store.active;
    if (target == null || target.quietSignalDismissed) return null;
    if (!QuietSignalGates.archiveAllows(entries)) return null;

    final clock = now ?? DateTime.now();
    final daysSinceSet = ComeBackTomorrowV2Store.daysSinceDateKey(
      target.createdDateKey,
      now: clock,
    );
    if (daysSinceSet == 0) return null;

    final savesAfterSet = _savesAfterDateKey(
      entries: entries,
      dateKey: target.createdDateKey,
    );
    if (savesAfterSet.any((entry) => _entryMatchesWatchTarget(entry, target))) {
      return null;
    }

    final unrelatedCount = savesAfterSet.length;
    final shouldShow = unrelatedCount >= 2 || daysSinceSet >= 3;
    if (!shouldShow) return null;

    final lastSeenDateKey = _resolveLastSeenDateKey(entries: entries, target: target);
    final daysSinceSeen = lastSeenDateKey == null
        ? daysSinceSet
        : ComeBackTomorrowV2Store.daysSinceDateKey(lastSeenDateKey, now: clock);

    return QuietSignal(
      title: QuietSignalCopy.title,
      body: QuietSignalCopy.body,
      footer: QuietSignalCopy.footer,
      ctaKeepWatching: QuietSignalCopy.ctaKeepWatching,
      source: target.source,
      daysSinceSet: daysSinceSet,
      daysSinceSeen: daysSinceSeen,
      unrelatedSaveCount: unrelatedCount,
      lastSeenDateKey: lastSeenDateKey,
      patternDetailHeading: QuietSignalCopy.patternDetailHeading,
      patternDetailBody: QuietSignalCopy.patternDetailBody,
      weeklyReviewHeading: QuietSignalCopy.weeklyReviewHeading,
      weeklyReviewBody: QuietSignalCopy.weeklyReviewBody,
      privateReportLine: QuietSignalCopy.privateReportLine,
    );
  }

  static String? _resolveLastSeenDateKey({
    required List<JournalEntry> entries,
    required ActiveWatchTarget target,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    String? latest;
    for (final entry in eligible) {
      if (!_entryMatchesWatchTarget(entry, target)) continue;
      final key = _dateKeyForEntry(entry.createdAt);
      if (latest == null || key.compareTo(latest) > 0) {
        latest = key;
      }
    }
    return latest;
  }

  static List<JournalEntry> _savesAfterDateKey({
    required List<JournalEntry> entries,
    required String dateKey,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    return eligible.where((entry) {
      final key = _dateKeyForEntry(entry.createdAt);
      return key.compareTo(dateKey) > 0;
    }).toList();
  }

  static bool _entryMatchesWatchTarget(
    JournalEntry entry,
    ActiveWatchTarget target,
  ) {
    final haystack = ComparableEvidenceText.userText(entry).toLowerCase();
    if (haystack.trim().isEmpty) return false;
    final phrase = target.groundedPhrase.trim().toLowerCase();
    if (phrase.length >= 8 && haystack.contains(phrase)) return true;

    final tokens = phrase
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 4)
        .toList();
    if (tokens.isEmpty) return false;
    var hits = 0;
    for (final token in tokens) {
      if (haystack.contains(token)) hits++;
    }
    return hits >= 2 || (tokens.length == 1 && hits == 1);
  }

  static String _dateKeyForEntry(DateTime when) {
    final utc = when.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }
}
