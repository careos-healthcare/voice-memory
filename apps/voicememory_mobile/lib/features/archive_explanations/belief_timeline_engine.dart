import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../timeline/timeline_models.dart';
import 'explanation_models.dart';

/// Month-by-month belief strength from transcript overlap (local only).
class BeliefTimelineEngine {
  const BeliefTimelineEngine();

  BeliefTimeline build({
    required List<JournalEntry> entries,
    required String? beliefText,
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.isEmpty || beliefText == null || beliefText.trim().isEmpty) {
      return BeliefTimeline.empty;
    }

    final keywords = _keywordsFrom(beliefText);
    if (keywords.isEmpty) return BeliefTimeline.empty;

    final byMonth = <String, List<JournalEntry>>{};
    for (final e in eligible) {
      final local = e.createdAt.toLocal();
      final key = '${local.year}-${local.month}';
      byMonth.putIfAbsent(key, () => []).add(e);
    }

    final keys = byMonth.keys.toList()..sort();
    final points = <BeliefTimelinePoint>[];
    for (final key in keys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final group = byMonth[key]!;
      final strength = _strengthForGroup(group, keywords);
      points.add(
        BeliefTimelinePoint(
          label: timelineMonthLabel(month),
          year: year,
          month: month,
          strengthPercent: strength,
        ),
      );
    }

    if (points.isEmpty) return BeliefTimeline.empty;

    final firstSeen = eligible.first.createdAt;
    BeliefTimelinePoint peak = points.first;
    for (final p in points) {
      if (p.strengthPercent > peak.strengthPercent) peak = p;
    }
    final current = points.last;

    final trend = _trend(points);
    return BeliefTimeline(
      points: points,
      firstSeen: firstSeen,
      peakLabel: '${peak.label} ${peak.year}',
      peakPercent: peak.strengthPercent,
      currentPercent: current.strengthPercent,
      currentLabel: _strengthLabel(current.strengthPercent),
      trend: trend,
    );
  }

  static BeliefTimelineTrend _trend(List<BeliefTimelinePoint> points) {
    if (points.length < 2) return BeliefTimelineTrend.stable;
    final recent = points.length >= 3
        ? points.sublist(points.length - 3)
        : points.sublist(points.length - 2);
    final early = points.length >= 3
        ? points.sublist(0, 3)
        : points.sublist(0, 1);
    final recentAvg =
        recent.map((p) => p.strengthPercent).reduce((a, b) => a + b) /
            recent.length;
    final earlyAvg = early.map((p) => p.strengthPercent).reduce((a, b) => a + b) /
        early.length;
    if (recentAvg > earlyAvg + 12) return BeliefTimelineTrend.strengthening;
    if (recentAvg < earlyAvg - 12) return BeliefTimelineTrend.weakening;
    return BeliefTimelineTrend.stable;
  }

  static String _strengthLabel(int percent) {
    if (percent >= 70) return 'Strong';
    if (percent >= 45) return 'Moderate';
    if (percent >= 25) return 'Emerging';
    return 'Low';
  }

  int _strengthForGroup(List<JournalEntry> group, Set<String> keywords) {
    if (group.isEmpty) return 0;
    var hits = 0;
    for (final e in group) {
      final t = e.transcript.toLowerCase();
      if (keywords.any(t.contains)) hits++;
    }
    return ((hits / group.length) * 100).round().clamp(0, 100);
  }

  Set<String> _keywordsFrom(String belief) {
    final words = belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
    return words;
  }
}
