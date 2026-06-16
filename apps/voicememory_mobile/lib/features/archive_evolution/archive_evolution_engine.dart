import '../../design/warm_archive_copy.dart';
import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_explanations/belief_timeline_engine.dart';
import '../archive_explanations/explanation_models.dart';
import '../archive_state_delta/archive_state_snapshot.dart';
import '../archive_state_object/archive_state_object.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../daily_discoveries/daily_discovery_engine.dart';
import '../daily_discoveries/daily_discovery_models.dart';
import '../living_archive/archive_was_wrong_engine.dart';
import '../living_archive/living_archive_copy.dart';
import 'archive_evolution_copy.dart';
import 'archive_evolution_models.dart';

/// Detects how the archive is still learning — one event, highest confidence wins.
class ArchiveEvolutionEngine {
  const ArchiveEvolutionEngine({
    this.wasWrongEngine = const ArchiveWasWrongEngine(),
    this.dailyEngine = const DailyDiscoveryEngine(),
    this.timelineEngine = const BeliefTimelineEngine(),
  });

  final ArchiveWasWrongEngine wasWrongEngine;
  final DailyDiscoveryEngine dailyEngine;
  final BeliefTimelineEngine timelineEngine;

  static int get minEligibleEntries =>
      ArchiveEvidenceGuard.minimumEvidenceCount;

  ArchiveEvolution? detect({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? discoveryBaseline,
    DailyDiscoveryBaseline? compareBaseline,
    Set<String> viewedDiscoveryIds = const {},
  }) {
    if (!ArchiveEvidenceGuard.hasMinimumEvidence(entries)) return null;

    final baseline = compareBaseline ?? discoveryBaseline;
    final candidates = <ArchiveEvolution>[];

    _detectChangedMind(
      entries,
      state,
      snapshotBaseline,
      discoveryBaseline,
      baseline,
      candidates,
    );
    _detectConfidence(entries, state, snapshotBaseline, baseline, candidates);
    _detectBeliefUnderReview(entries, state, candidates);
    _detectPatterns(entries, state, baseline, viewedDiscoveryIds, candidates);

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.first;
  }

  ArchiveEvolution? detectAfterNewRecording({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? discoveryBaseline,
    Set<String> viewedDiscoveryIds = const {},
  }) {
    final immediate = dailyEngine.baselineBeforeLatestEntry(entries);
    return detect(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      discoveryBaseline: discoveryBaseline,
      compareBaseline: immediate,
      viewedDiscoveryIds: viewedDiscoveryIds,
    );
  }

  void _detectChangedMind(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? discoveryBaseline,
    DailyDiscoveryBaseline? compareBaseline,
    List<ArchiveEvolution> out,
  ) {
    if (compareBaseline == null) return;

    final wrong = wasWrongEngine.detect(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      discoveryBaseline: discoveryBaseline,
    );
    if (wrong == null) return;

    final priorTheme = _dominantTheme(compareBaseline.themeCounts);
    final headline = priorTheme == 'work' || priorTheme == 'career'
        ? 'The archive no longer believes work is your biggest source of stress.'
        : wrong.summary;

    out.add(
      ArchiveEvolution(
        id: 'evo:changed-mind:${wrong.id}',
        kind: ArchiveEvolutionKind.archiveChangedMind,
        sectionHeadline: ArchiveEvolutionCopy.sectionHeadlineFor(
          ArchiveEvolutionKind.archiveChangedMind,
        ),
        headline: headline,
        summary: wrong.summary,
        confidence: wrong.confidence,
        evidenceIds: wrong.evidenceIds,
        insightRef: wrong.insightRef,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _detectConfidence(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? compareBaseline,
    List<ArchiveEvolution> out,
  ) {
    final belief = state?.belief?.trim();
    if (belief == null || belief.isEmpty) return;

    final timeline = timelineEngine.build(entries: entries, beliefText: belief);
    if (timeline.points.length < 2) return;

    final prior =
        compareBaseline?.beliefStrengthPercent ??
        snapshotBaseline?.confidence ??
        timeline.points.first.strengthPercent;
    final current = timeline.currentPercent;
    final delta = current - prior;
    if (delta.abs() < LivingArchiveCopy.minConfidenceChangePercent) return;

    final drop = prior - current;
    if (drop >= ArchiveWasWrongEngine.minConfidenceDrop) return;

    final evidence = _recentEvidenceIds(entries);
    if (evidence.length < 2) return;

    if (delta > 0) {
      out.add(
        ArchiveEvolution(
          id: 'evo:confidence-up:$prior->$current',
          kind: ArchiveEvolutionKind.confidenceIncreased,
          sectionHeadline: ArchiveEvolutionCopy.sectionHeadlineFor(
            ArchiveEvolutionKind.confidenceIncreased,
          ),
          headline: 'The archive feels more certain about this than before.',
          summary:
              'Language tied to “${_truncate(belief, 56)}” may be strengthening in recent recordings.',
          confidence: (68 + delta).clamp(65, 90),
          evidenceIds: evidence,
          insightRef: ArchiveInsightRef.belief(),
          createdAt: entries.last.createdAt,
        ),
      );
    } else {
      out.add(
        ArchiveEvolution(
          id: 'evo:confidence-down:$prior->$current',
          kind: ArchiveEvolutionKind.confidenceDecreased,
          sectionHeadline: ArchiveEvolutionCopy.sectionHeadlineFor(
            ArchiveEvolutionKind.confidenceDecreased,
          ),
          headline: 'The archive is becoming less certain about this.',
          summary: WarmArchiveCopy.confidenceShiftPhrase(
            prior: prior,
            current: current,
          ),
          confidence: (68 + drop).clamp(65, 88),
          evidenceIds: evidence,
          insightRef: ArchiveInsightRef.belief(),
          createdAt: entries.last.createdAt,
        ),
      );
    }
  }

  void _detectBeliefUnderReview(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    List<ArchiveEvolution> out,
  ) {
    final belief = state?.belief?.trim();
    if (belief == null || belief.isEmpty) return;

    final result = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: belief,
    );
    if (result.reports.isEmpty) return;

    final top = result.reports.first;
    if (top.originalEntryId.isEmpty || top.conflictingEntryId.isEmpty) return;

    out.add(
      ArchiveEvolution(
        id: 'evo:belief-review:${top.id}',
        kind: ArchiveEvolutionKind.beliefUnderReview,
        sectionHeadline: ArchiveEvolutionCopy.sectionHeadlineFor(
          ArchiveEvolutionKind.beliefUnderReview,
        ),
        headline: 'The archive has conflicting evidence about this belief.',
        summary:
            'Two reflections pull apart while both remain linked to “${_truncate(belief, 48)}”.',
        confidence: top.confidenceScore.clamp(62, 88),
        evidenceIds: top.recordingIds.take(4).toList(),
        insightRef: ArchiveInsightRef.contradiction(
          entryIdA: top.originalEntryId,
          entryIdB: top.conflictingEntryId,
        ),
        createdAt: DateTime.now(),
      ),
    );
  }

  void _detectPatterns(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DailyDiscoveryBaseline? compareBaseline,
    Set<String> viewedDiscoveryIds,
    List<ArchiveEvolution> out,
  ) {
    if (compareBaseline == null) return;

    final discoveries = dailyEngine.detectAllDiscoveries(
      entries: entries,
      state: state,
      baseline: compareBaseline,
      viewedIds: viewedDiscoveryIds,
    );

    ArchiveEvolution? bestNew;
    ArchiveEvolution? bestFade;
    var bestNewConf = 0;
    var bestFadeConf = 0;

    for (final d in discoveries) {
      final conf = d.confidence.round();
      switch (d.type) {
        case DailyDiscoveryType.newBelief:
        case DailyDiscoveryType.themeSpike:
        case DailyDiscoveryType.contradictionEmerging:
        case DailyDiscoveryType.unexpectedCorrelation:
          if (conf > bestNewConf) {
            bestNewConf = conf;
            bestNew = _evolutionFromDiscovery(d, true);
          }
        case DailyDiscoveryType.themeDecline:
        case DailyDiscoveryType.beliefWeakening:
          if (conf > bestFadeConf) {
            bestFadeConf = conf;
            bestFade = _evolutionFromDiscovery(d, false);
          }
        default:
          break;
      }
    }

    if (bestNew != null) out.add(bestNew);
    if (bestFade != null) out.add(bestFade);
  }

  ArchiveEvolution _evolutionFromDiscovery(DailyDiscovery d, bool emerging) {
    final kind = emerging
        ? ArchiveEvolutionKind.newPatternEmerging
        : ArchiveEvolutionKind.oldPatternFading;
    final headline = emerging
        ? 'A new pattern may be appearing.'
        : 'This pattern appears less often than before.';

    return ArchiveEvolution(
      id: 'evo:${kind.name}:${d.id}',
      kind: kind,
      sectionHeadline: ArchiveEvolutionCopy.sectionHeadlineFor(kind),
      headline: headline,
      summary: d.summary,
      confidence: d.confidence.round().clamp(58, 88),
      evidenceIds: d.evidenceIds,
      insightRef: d.insightRef,
      createdAt: d.createdAt,
    );
  }

  static List<String> _recentEvidenceIds(List<JournalEntry> entries) {
    return archiveEligibleEvidenceEntries(
      entries,
    ).reversed.take(4).map((e) => e.id).toList();
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

  static String _truncate(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}
