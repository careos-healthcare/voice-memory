import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_belief_catalog.dart';
import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_confidence_engine.dart';
import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_copy.dart';
import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_theme_gap_engine.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/discover/contradiction_engine.dart';
import 'package:archiveme_mobile/features/theme_tracking/theme_tracker_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds evidence-backed deltas since [ArchiveStateSnapshot] review time.
class ArchiveChangeFeedEngine {
  const ArchiveChangeFeedEngine({
    this.confidenceEngine = const ArchiveAnalystConfidenceEngine(),
    this.catalog = const ArchiveAnalystBeliefCatalog(),
    this.contradictionEngine = const DiscoverContradictionEngine(),
    this.themeGapEngine = const ArchiveThemeGapEngine(),
    this.themeTracker = const ThemeTrackerService(),
    this.minBeliefDelta = 8,
    this.minContradictionConfidence = 60,
  });

  final ArchiveAnalystConfidenceEngine confidenceEngine;
  final ArchiveAnalystBeliefCatalog catalog;
  final DiscoverContradictionEngine contradictionEngine;
  final ArchiveThemeGapEngine themeGapEngine;
  final ThemeTrackerService themeTracker;
  final int minBeliefDelta;
  final int minContradictionConfidence;

  ArchiveChangeFeedView build({
    required List<JournalEntry> entries,
    ArchiveStateSnapshot? baseline,
    ArchiveStateObjectV3? state,
  }) {
    if (baseline == null) {
      return const ArchiveChangeFeedView(
        hasBaseline: false,
        reviewedAt: null,
        newReflectionCount: 0,
        beliefsStrengthened: [],
        beliefsWeakened: [],
        contradictionsAppeared: [],
        contradictionsResolved: [],
        themesIncreasing: [],
        themesDecreasing: [],
        emptyMessage: ArchiveChangeFeedCopy.noBaseline,
      );
    }

    final reviewedAt = DateTime.tryParse(baseline.timestamp);
    if (reviewedAt == null) {
      return const ArchiveChangeFeedView(
        hasBaseline: false,
        reviewedAt: null,
        newReflectionCount: 0,
        beliefsStrengthened: [],
        beliefsWeakened: [],
        contradictionsAppeared: [],
        contradictionsResolved: [],
        themesIncreasing: [],
        themesDecreasing: [],
        emptyMessage: ArchiveChangeFeedCopy.noBaseline,
      );
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final before = eligible
        .where((e) => !e.createdAt.isAfter(reviewedAt))
        .toList();
    final afterOnly = eligible
        .where((e) => e.createdAt.isAfter(reviewedAt))
        .toList();

    final beliefs = _beliefChanges(
      entries: entries,
      before: before,
      all: eligible,
      state: state,
    );

    final contradictions = _contradictionChanges(
      entries: entries,
      before: before,
      all: eligible,
      state: state,
    );

    final themes = _themeChanges(
      before: before,
      all: eligible,
      afterOnly: afterOnly,
      reviewedAt: reviewedAt,
    );

    final hasChanges =
        beliefs.strengthened.isNotEmpty ||
        beliefs.weakened.isNotEmpty ||
        contradictions.appeared.isNotEmpty ||
        contradictions.resolved.isNotEmpty ||
        themes.increasing.isNotEmpty ||
        themes.decreasing.isNotEmpty;

    return ArchiveChangeFeedView(
      hasBaseline: true,
      reviewedAt: reviewedAt,
      newReflectionCount: afterOnly.length,
      beliefsStrengthened: beliefs.strengthened,
      beliefsWeakened: beliefs.weakened,
      contradictionsAppeared: contradictions.appeared,
      contradictionsResolved: contradictions.resolved,
      themesIncreasing: themes.increasing,
      themesDecreasing: themes.decreasing,
      emptyMessage: hasChanges ? null : ArchiveChangeFeedCopy.noChanges,
    );
  }

  _BeliefChanges _beliefChanges({
    required List<JournalEntry> entries,
    required List<JournalEntry> before,
    required List<JournalEntry> all,
    ArchiveStateObjectV3? state,
  }) {
    final candidates = catalog.collect(entries: entries, state: state);
    final strengthened = <ArchiveChangeBeliefRow>[];
    final weakened = <ArchiveChangeBeliefRow>[];

    for (final c in candidates) {
      final text = c.statement.trim();
      if (text.length < 12 || _isPlaceholder(text)) continue;

      final confBefore = _confidenceFor(text, before);
      final confNow = _confidenceFor(text, all);
      final split = confidenceEngine.splitEntries(
        beliefText: text,
        eligible: all,
      );

      final row = ArchiveChangeBeliefRow(
        statement: text,
        confidenceBefore: confBefore,
        confidenceNow: confNow,
        evidenceCount: split.supporting.length,
        counterEvidenceCount: split.counter.length,
      );

      final delta = confNow - confBefore;
      if (delta >= minBeliefDelta) {
        strengthened.add(row);
      } else if (delta <= -minBeliefDelta) {
        weakened.add(row);
      }
    }

    strengthened.sort((a, b) => b.confidenceDelta.compareTo(a.confidenceDelta));
    weakened.sort((a, b) => a.confidenceDelta.compareTo(b.confidenceDelta));

    return _BeliefChanges(
      strengthened: strengthened.take(4).toList(),
      weakened: weakened.take(4).toList(),
    );
  }

  int _confidenceFor(String statement, List<JournalEntry> eligible) {
    if (eligible.isEmpty) return 0;
    final split = confidenceEngine.splitEntries(
      beliefText: statement,
      eligible: eligible,
    );
    return confidenceEngine.score(
      supportingCount: split.supporting.length,
      counterCount: split.counter.length,
      recencyRatio: split.recencyRatio,
      consistencyRatio: split.consistencyRatio,
      maxContradictionScore: 0,
      stale: split.stale,
    );
  }

  _ContradictionChanges _contradictionChanges({
    required List<JournalEntry> entries,
    required List<JournalEntry> before,
    required List<JournalEntry> all,
    ArchiveStateObjectV3? state,
  }) {
    final beforeSet = _contradictionKeys(
      _buildContradictions(entries, before, state),
    );
    final nowSet = _contradictionKeys(
      _buildContradictions(entries, all, state),
    );

    final appeared = <ArchiveChangeContradictionRow>[];
    final resolved = <ArchiveChangeContradictionRow>[];

    for (final entry in nowSet.entries) {
      if (!beforeSet.containsKey(entry.key)) {
        appeared.add(entry.value);
      }
    }
    for (final entry in beforeSet.entries) {
      if (!nowSet.containsKey(entry.key)) {
        resolved.add(entry.value);
      }
    }

    appeared.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    resolved.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

    return _ContradictionChanges(
      appeared: appeared.take(3).toList(),
      resolved: resolved.take(3).toList(),
    );
  }

  List<ArchiveV1Contradiction> _buildContradictions(
    List<JournalEntry> entries,
    List<JournalEntry> subset,
    ArchiveStateObjectV3? state,
  ) {
    if (subset.length < 3) return const [];

    final statement = contradictionEngine
        .build(entries: entries, state: state)
        .where((c) => c.confidenceScore >= minContradictionConfidence)
        .where((c) => _bothInSubset(c.entryIdA, c.entryIdB, subset))
        .map(
          (c) => ArchiveV1Contradiction(
            id: 'stmt:${c.entryIdA}:${c.entryIdB}',
            youSay: c.statementA,
            but: c.statementB,
            confidenceScore: c.confidenceScore,
            entryIds: [c.entryIdA, c.entryIdB],
          ),
        );

    final gaps = themeGapEngine
        .build(subset)
        .where((g) => g.confidenceScore >= minContradictionConfidence);

    return [...statement, ...gaps];
  }

  bool _bothInSubset(String a, String b, List<JournalEntry> subset) {
    final ids = subset.map((e) => e.id).toSet();
    return ids.contains(a) && ids.contains(b);
  }

  Map<String, ArchiveChangeContradictionRow> _contradictionKeys(
    Iterable<ArchiveV1Contradiction> list,
  ) {
    final out = <String, ArchiveChangeContradictionRow>{};
    for (final c in list) {
      final key = _normalize('${c.youSay}|${c.but}');
      out[key] = ArchiveChangeContradictionRow(
        youSay: c.youSay,
        but: c.but,
        confidenceScore: c.confidenceScore,
        evidenceCount: c.entryIds.length,
      );
    }
    return out;
  }

  _ThemeChanges _themeChanges({
    required List<JournalEntry> before,
    required List<JournalEntry> all,
    required List<JournalEntry> afterOnly,
    required DateTime reviewedAt,
  }) {
    final increasing = <ArchiveChangeThemeRow>[];
    final decreasing = <ArchiveChangeThemeRow>[];

    for (final id in ThemeTrackerService.canonicalThemeIds) {
      final label = ThemeTrackerService.displayNames[id] ?? id;
      final seriesAtReview = _monthlyMentionSeries(id, before, maxMonths: 3);
      final series = _monthlyMentionSeries(id, all, maxMonths: 3);
      final mentionsAtReview = seriesAtReview.isEmpty ? 0 : seriesAtReview.last;
      final mentionsNow = series.isEmpty ? 0 : series.last;
      final newSince = _themeMentionCount(id, afterOnly);

      if (mentionsNow < 2 && mentionsAtReview < 2) continue;

      final row = ArchiveChangeThemeRow(
        label: label,
        mentionSeries: series,
        mentionsAtReview: mentionsAtReview,
        mentionsNow: mentionsNow,
        newMentionsSinceReview: newSince,
      );

      final seriesRising = _seriesRising(series);
      final seriesFalling = _seriesFalling(series);

      if ((mentionsNow > mentionsAtReview && newSince >= 1) || seriesRising) {
        if (!seriesFalling || mentionsNow > mentionsAtReview) {
          increasing.add(row);
        }
      }
      if ((mentionsAtReview > mentionsNow && mentionsAtReview >= 2) ||
          seriesFalling) {
        if (!seriesRising || mentionsAtReview > mentionsNow) {
          decreasing.add(row);
        }
      }
    }

    increasing.sort(
      (a, b) => b.newMentionsSinceReview.compareTo(a.newMentionsSinceReview),
    );
    decreasing.sort(
      (a, b) => a.newMentionsSinceReview.compareTo(b.newMentionsSinceReview),
    );

    return _ThemeChanges(
      increasing: increasing.take(4).toList(),
      decreasing: decreasing.take(4).toList(),
    );
  }

  int _themeMentionCount(String themeId, List<JournalEntry> entries) {
    var n = 0;
    for (final e in entries) {
      if (ThemeTrackerService.themesForEntry(e).contains(themeId)) n++;
    }
    return n;
  }

  List<int> _monthlyMentionSeries(
    String themeId,
    List<JournalEntry> entries, {
    required int maxMonths,
  }) {
    final buckets = <String, int>{};
    for (final e in entries) {
      if (!ThemeTrackerService.themesForEntry(e).contains(themeId)) continue;
      final local = e.createdAt.toLocal();
      final key = '${local.year}-${local.month.toString().padLeft(2, '0')}';
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    if (buckets.isEmpty) return const [];
    final keys = buckets.keys.toList()..sort();
    final tail = keys.length <= maxMonths
        ? keys
        : keys.sublist(keys.length - maxMonths);
    return tail.map((k) => buckets[k]!).toList();
  }

  bool _seriesRising(List<int> series) {
    if (series.length < 2) return false;
    return series.last > series.first;
  }

  bool _seriesFalling(List<int> series) {
    if (series.length < 2) return false;
    return series.last < series.first;
  }

  bool _isPlaceholder(String text) {
    final lower = text.toLowerCase();
    return lower.contains('still gathering evidence') ||
        lower.contains('working belief is forming');
  }

  String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _BeliefChanges {
  const _BeliefChanges({required this.strengthened, required this.weakened});

  final List<ArchiveChangeBeliefRow> strengthened;
  final List<ArchiveChangeBeliefRow> weakened;
}

class _ContradictionChanges {
  const _ContradictionChanges({required this.appeared, required this.resolved});

  final List<ArchiveChangeContradictionRow> appeared;
  final List<ArchiveChangeContradictionRow> resolved;
}

class _ThemeChanges {
  const _ThemeChanges({required this.increasing, required this.decreasing});

  final List<ArchiveChangeThemeRow> increasing;
  final List<ArchiveChangeThemeRow> decreasing;
}