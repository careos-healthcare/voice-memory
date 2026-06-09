import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_explanations/belief_timeline_engine.dart';
import '../archive_explanations/explanation_models.dart';
import '../archive_state_object/archive_state_object.dart';
import '../archive_state_delta/archive_state_snapshot.dart';
import '../daily_discoveries/daily_discovery_models.dart';
import '../discover/theme_engine.dart';
import '../../design/warm_archive_copy.dart';
import 'living_archive_copy.dart';
import 'living_archive_models.dart';

/// Detects when recent evidence overturns prior archive assumptions.
class ArchiveWasWrongEngine {
  const ArchiveWasWrongEngine({
    this.timelineEngine = const BeliefTimelineEngine(),
  });

  final BeliefTimelineEngine timelineEngine;

  static int get minEligibleEntries => ArchiveEvidenceGuard.minimumEvidenceCount;
  static const int minConfidenceDrop = 15;
  static const int minEvidenceCount = 2;

  ArchiveWasWrongInsight? detect({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? discoveryBaseline,
  }) {
    if (!ArchiveEvidenceGuard.hasMinimumEvidence(entries)) {
      return null;
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final candidates = <ArchiveWasWrongInsight>[];

    _detectConfidenceDrop(entries, state, snapshotBaseline, candidates);
    _detectThemeDominanceShift(
      eligible,
      discoveryBaseline,
      candidates,
    );
    _detectNamedShifts(eligible, discoveryBaseline, candidates);

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.first;
  }

  void _detectConfidenceDrop(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    List<ArchiveWasWrongInsight> out,
  ) {
    final belief = state?.belief?.trim();
    if (belief == null || belief.isEmpty) return;

    final timeline = timelineEngine.build(entries: entries, beliefText: belief);
    if (timeline.points.length < 2) return;

    final prior = snapshotBaseline?.confidence ?? timeline.points.first.strengthPercent;
    final current = timeline.currentPercent;
    final drop = prior - current;
    if (drop < minConfidenceDrop) return;

    final evidence = eligibleIds(entries);
    if (evidence.length < minEvidenceCount) return;

    out.add(
      ArchiveWasWrongInsight(
        id: 'wrong:confidence:$prior->$current',
        headline: 'The archive changed its mind.',
        summary: WarmArchiveCopy.archiveChangedMindConfidenceSummary(
          beliefSnippet: _truncate(belief, 56),
        ),
        evidenceIds: evidence,
        confidence: (68 + drop).clamp(70, 92),
        insightRef: ArchiveInsightRef.belief(),
        shiftLabel: 'less certain',
      ),
    );
  }

  void _detectThemeDominanceShift(
    List<JournalEntry> eligible,
    DailyDiscoveryBaseline? discoveryBaseline,
    List<ArchiveWasWrongInsight> out,
  ) {
    if (discoveryBaseline == null) return;

    final prior = _dominantTheme(discoveryBaseline.themeCounts);
    final current = _dominantTheme(DiscoverLocalThemeCounts.count(eligible));
    if (prior == null || current == null || prior == current) return;

    final priorCount = discoveryBaseline.themeCounts[prior] ?? 0;
    final currentCount = DiscoverLocalThemeCounts.count(eligible)[current] ?? 0;
    if (priorCount < 2 || currentCount < 2) return;

    final evidence = _themeEvidenceIds(eligible, current);
    if (evidence.length < minEvidenceCount) return;

    final headline = LivingArchiveCopy.themeDominanceWrongHeadline(
      priorThemeKey: prior,
      currentThemeKey: current,
    );
    out.add(
      ArchiveWasWrongInsight(
        id: 'wrong:theme:$prior->$current',
        headline: headline,
        summary: prior == current
            ? headline
            : '${_label(prior)} weighed heavily before; '
                '${_label(current)} show up more often in your recent recordings.',
        evidenceIds: evidence,
        confidence: 74,
        insightRef: ArchiveInsightRef.theme(current),
        shiftLabel: '${_label(prior)} → ${_label(current)}',
      ),
    );
  }

  void _detectNamedShifts(
    List<JournalEntry> eligible,
    DailyDiscoveryBaseline? discoveryBaseline,
    List<ArchiveWasWrongInsight> out,
  ) {
    if (discoveryBaseline == null) return;

    final shifts = <(String prior, String current, String label)>[
      ('work', 'relationship', 'work → relationships'),
      ('career', 'relationship', 'work → relationships'),
      ('confidence', 'stress', 'confidence → uncertainty'),
      ('approval', 'confidence', 'approval → self-worth'),
    ];

    final priorCounts = discoveryBaseline.themeCounts;
    final currentCounts = DiscoverLocalThemeCounts.count(eligible);

    for (final shift in shifts) {
      final p = priorCounts[shift.$1] ?? 0;
      final c = currentCounts[shift.$2] ?? 0;
      if (p < 2 || c < 2 || c <= p) continue;

      final evidence = _themeEvidenceIds(eligible, shift.$2);
      if (evidence.length < minEvidenceCount) continue;

      final headline = LivingArchiveCopy.themeDominanceWrongHeadline(
        priorThemeKey: shift.$1,
        currentThemeKey: shift.$2,
      );
      out.add(
        ArchiveWasWrongInsight(
          id: 'wrong:shift:${shift.$1}:${shift.$2}',
          headline: headline,
          summary:
              'Earlier reflections centered on ${_label(shift.$1)}. '
              'Your last recordings lean toward ${_label(shift.$2)} instead.',
          evidenceIds: evidence,
          confidence: 72,
          insightRef: ArchiveInsightRef.theme(shift.$2),
          shiftLabel: shift.$3,
        ),
      );
      break;
    }
  }

  static String? _dominantTheme(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    var bestKey = '';
    var best = 0;
    for (final e in counts.entries) {
      if (e.value > best) {
        best = e.value;
        bestKey = e.key;
      }
    }
    return best > 0 ? bestKey : null;
  }

  static List<String> _themeEvidenceIds(
    List<JournalEntry> eligible,
    String themeKey,
  ) {
    final keywords = _keywordsFor(themeKey);
    final ids = <String>[];
    for (final e in eligible.reversed) {
      final t = e.transcript.toLowerCase();
      if (keywords.any(t.contains)) ids.add(e.id);
      if (ids.length >= 4) break;
    }
    return ids;
  }

  static List<String> _keywordsFor(String key) {
    const map = {
      'work': ['work', 'job', 'career', 'office'],
      'career': ['work', 'job', 'career'],
      'relationship': ['relationship', 'partner', 'family', 'friend'],
      'relationships': ['relationship', 'partner', 'family'],
      'confidence': ['confident', 'confidence', 'sure of myself'],
      'stress': ['stress', 'stressed', 'uncertain', 'unsure', 'anxious'],
      'approval': ['approval', 'validation', 'validate'],
    };
    return map[key] ?? [key];
  }

  static List<String> eligibleIds(List<JournalEntry> entries) {
    return archiveEligibleEvidenceEntries(entries)
        .reversed
        .take(4)
        .map((e) => e.id)
        .toList();
  }

  static String _label(String key) {
    const labels = {
      'work': 'work',
      'career': 'work',
      'relationship': 'relationships',
      'relationships': 'relationships',
      'confidence': 'confidence',
      'stress': 'uncertainty',
      'approval': 'approval',
    };
    return labels[key] ?? key;
  }

  static String _truncate(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}
