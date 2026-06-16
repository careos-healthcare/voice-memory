import '../../design/warm_archive_copy.dart';
import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_explanations/belief_timeline_engine.dart';
import '../archive_explanations/explanation_models.dart';
import '../archive_state_delta/archive_state_snapshot.dart';
import '../archive_state_object/archive_state_object.dart';
import '../daily_discoveries/daily_discovery_models.dart';
import 'living_archive_models.dart';

/// One compact card summarizing today's archive movement.
class WhatChangedTodayEngine {
  const WhatChangedTodayEngine({
    this.timelineEngine = const BeliefTimelineEngine(),
  });

  final BeliefTimelineEngine timelineEngine;

  static int get minEligibleEntries =>
      ArchiveEvidenceGuard.minimumEvidenceCount;

  static const Map<String, List<String>> _keywordThemes = {
    'approval': ['approval', 'approve', 'validation', 'validate'],
    'work': ['work', 'job', 'career', 'office'],
  };

  WhatChangedToday? build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? discoveryBaseline,
  }) {
    if (!ArchiveEvidenceGuard.hasMinimumEvidence(entries)) {
      return null;
    }

    final lines = <WhatChangedTodayLine>[];
    final evidence = <String>[];

    _confidenceLine(entries, state, snapshotBaseline, lines);
    _keywordThemeLines(entries, discoveryBaseline, lines);

    if (lines.isEmpty) return null;

    for (final e in archiveEligibleEvidenceEntries(entries).reversed.take(4)) {
      evidence.add(e.id);
    }

    return WhatChangedToday(
      lines: lines.take(3).toList(),
      insightRef: ArchiveInsightRef.belief(),
      evidenceIds: evidence,
    );
  }

  void _confidenceLine(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    List<WhatChangedTodayLine> lines,
  ) {
    final belief = state?.belief?.trim();
    if (belief == null || belief.isEmpty) return;

    final timeline = timelineEngine.build(entries: entries, beliefText: belief);
    if (timeline.points.length < 2) return;

    final before =
        snapshotBaseline?.confidence ?? timeline.points.first.strengthPercent;
    final after = timeline.currentPercent;
    if (before == after) return;

    lines.add(
      WhatChangedTodayLine(
        label: WarmArchiveCopy.confidenceConcept,
        before: '$before%',
        after: '$after%',
        displayText: WarmArchiveCopy.confidenceShiftPhrase(
          prior: before,
          current: after,
        ),
      ),
    );
  }

  void _keywordThemeLines(
    List<JournalEntry> entries,
    DailyDiscoveryBaseline? discoveryBaseline,
    List<WhatChangedTodayLine> lines,
  ) {
    if (discoveryBaseline == null) return;

    final recent = _entriesInWindow(entries, const Duration(days: 7));
    final prior = _entriesInWindow(
      entries,
      const Duration(days: 30),
      excludeRecentDays: 7,
    );
    if (recent.length < 1 || prior.length < 2) return;

    for (final entry in _keywordThemes.entries) {
      final key = entry.key;
      final keywords = entry.value;
      final nowCount = _countMentions(recent, keywords);
      final beforeCount = _countMentions(prior, keywords);
      final delta = nowCount - beforeCount;
      if (delta == 0) continue;

      final label = key == 'approval'
          ? 'Approval mentions'
          : key == 'work'
          ? 'Work references'
          : '${key[0].toUpperCase()}${key.substring(1)} mentions';

      final themeName = key == 'approval' ? 'approval' : 'work';
      if (delta < 0 && beforeCount >= 3) {
        lines.add(
          WhatChangedTodayLine(
            label: label,
            before: '$beforeCount',
            after: '$nowCount',
            displayText: WarmArchiveCopy.themeReturningLessOften(themeName),
          ),
        );
      } else if (delta > 0) {
        lines.add(
          WhatChangedTodayLine(
            label: label,
            before: '$beforeCount',
            after: '$nowCount',
            displayText: WarmArchiveCopy.themeReturningMoreOften(themeName),
          ),
        );
      }
    }
  }

  static int _countMentions(List<JournalEntry> entries, List<String> keywords) {
    var n = 0;
    for (final e in entries) {
      final t = e.transcript.toLowerCase();
      if (keywords.any(t.contains)) n++;
    }
    return n;
  }

  static List<JournalEntry> _entriesInWindow(
    List<JournalEntry> entries,
    Duration window, {
    int excludeRecentDays = 0,
  }) {
    final now = DateTime.now();
    final end = now.subtract(Duration(days: excludeRecentDays));
    final start = end.subtract(window);
    return archiveEligibleEvidenceEntries(entries)
        .where((e) => !e.createdAt.isBefore(start) && e.createdAt.isBefore(end))
        .toList();
  }
}
