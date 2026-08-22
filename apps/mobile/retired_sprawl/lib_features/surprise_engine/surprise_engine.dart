import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_explanations/belief_timeline_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_engine.dart';
import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:archiveme_mobile/features/living_archive/archive_was_wrong_engine.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_copy.dart';
import 'package:archiveme_mobile/features/surprise_engine/surprise_copy.dart';
import 'package:archiveme_mobile/features/surprise_engine/surprise_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Answers “What surprised the archive?” — one surprise by strict priority.
class SurpriseEngine {
  const SurpriseEngine({
    this.wasWrongEngine = const ArchiveWasWrongEngine(),
    this.dailyEngine = const DailyDiscoveryEngine(),
    this.timelineEngine = const BeliefTimelineEngine(),
  });

  final ArchiveWasWrongEngine wasWrongEngine;
  final DailyDiscoveryEngine dailyEngine;
  final BeliefTimelineEngine timelineEngine;

  static int get minEligibleEntries =>
      ArchiveEvidenceGuard.minimumEvidenceCount;

  /// Compare [baseline] (or pre-latest entry) to the current archive.
  ArchiveSurprise? detect({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? discoveryBaseline,
    DailyDiscoveryBaseline? immediateBaseline,
    Set<String> viewedDiscoveryIds = const {},
  }) {
    if (!ArchiveEvidenceGuard.hasMinimumEvidence(entries)) return null;

    final compareBaseline = immediateBaseline ?? discoveryBaseline;
    final candidates = <ArchiveSurprise>[];

    _detectArchiveChangedMind(
      entries,
      state,
      snapshotBaseline,
      discoveryBaseline,
      compareBaseline,
      candidates,
    );
    _detectConfidenceSharp(
      entries,
      state,
      snapshotBaseline,
      compareBaseline,
      candidates,
    );
    _detectFromDailyDiscoveries(
      entries,
      state,
      compareBaseline,
      viewedDiscoveryIds,
      candidates,
    );

    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => SurpriseCopy.priorityIndex(
        a.type,
      ).compareTo(SurpriseCopy.priorityIndex(b.type)),
    );
    return candidates.first;
  }

  /// Post-save: baseline is archive before the newest recording.
  ArchiveSurprise? detectAfterNewRecording({
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
      immediateBaseline: immediate,
      viewedDiscoveryIds: viewedDiscoveryIds,
    );
  }

  void _detectArchiveChangedMind(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? discoveryBaseline,
    DailyDiscoveryBaseline? compareBaseline,
    List<ArchiveSurprise> out,
  ) {
    if (compareBaseline == null) return;

    final wrong = wasWrongEngine.detect(
      entries: entries,
      state: state,
      snapshotBaseline: snapshotBaseline,
      discoveryBaseline: discoveryBaseline,
    );
    if (wrong == null) return;

    final priorTheme = _dominantThemeKey(compareBaseline.themeCounts);
    final headline = priorTheme == 'work' || priorTheme == 'career'
        ? SurpriseCopy.workDominanceHeadline()
        : wrong.summary;

    out.add(
      ArchiveSurprise(
        id: 'surprise:wrong:${wrong.id}',
        type: SurpriseType.archiveChangedMind,
        headline: headline,
        why: SurpriseCopy.whyFor(SurpriseType.archiveChangedMind),
        evidenceIds: wrong.evidenceIds,
        insightRef: wrong.insightRef,
        createdAt: DateTime.now(),
        themeKey: priorTheme,
      ),
    );
  }

  void _detectConfidenceSharp(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? snapshotBaseline,
    DailyDiscoveryBaseline? compareBaseline,
    List<ArchiveSurprise> out,
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

    final evidence = archiveEligibleEvidenceEntries(
      entries,
    ).reversed.take(4).map((e) => e.id).toList();
    if (evidence.length < 2) return;

    final headline = delta < 0
        ? 'This belief is weakening.'
        : 'This belief is strengthening.';

    out.add(
      ArchiveSurprise(
        id: 'surprise:confidence:$prior->$current',
        type: SurpriseType.confidenceChangedSharply,
        headline: headline,
        why: SurpriseCopy.whyFor(SurpriseType.confidenceChangedSharply),
        evidenceIds: evidence,
        insightRef: ArchiveInsightRef.belief(),
        createdAt: entries.last.createdAt,
      ),
    );
  }

  void _detectFromDailyDiscoveries(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DailyDiscoveryBaseline? compareBaseline,
    Set<String> viewedDiscoveryIds,
    List<ArchiveSurprise> out,
  ) {
    final discoveries = dailyEngine.detectAllDiscoveries(
      entries: entries,
      state: state,
      baseline: compareBaseline,
      viewedIds: viewedDiscoveryIds,
    );

    ArchiveSurprise? best;
    var bestPriority = 999;

    for (final d in discoveries) {
      final type = SurpriseCopy.fromDailyDiscoveryType(d.type.name);
      if (type == null) continue;
      final priority = SurpriseCopy.priorityIndex(type);
      if (priority >= bestPriority) continue;

      final surprise = _surpriseFromDiscovery(d, type);
      if (surprise == null) continue;
      best = surprise;
      bestPriority = priority;
    }

    if (best != null) out.add(best);
  }

  ArchiveSurprise? _surpriseFromDiscovery(
    DailyDiscovery discovery,
    SurpriseType type,
  ) {
    String? themeKey;
    String? themeLabel;
    String? chapterTitle;
    String? priorThemeLabel;

    if (type == SurpriseType.unexpectedThemeRise ||
        type == SurpriseType.themeDisappearance) {
      themeKey = discovery.insightRef.themeKey;
      if (themeKey != null) {
        themeLabel = SurpriseCopy.themeLabelFromKey(themeKey);
      }
    }

    if (type == SurpriseType.newLifeChapter) {
      chapterTitle = _chapterTitleFromSummary(discovery.summary);
    }

    final headline = SurpriseCopy.headlineFor(
      type: type,
      themeLabel: themeLabel,
      priorThemeLabel: priorThemeLabel,
      chapterTitle: chapterTitle,
      beliefSnippet: discovery.summary,
    );

    final displayHeadline =
        discovery.summary.trim().isNotEmpty &&
            (type == SurpriseType.unexpectedThemeRise ||
                type == SurpriseType.themeDisappearance)
        ? discovery.summary
        : headline;

    return ArchiveSurprise(
      id: 'surprise:${type.name}:${discovery.id}',
      type: type,
      headline: displayHeadline,
      why: discovery.whyItMatters.isNotEmpty
          ? discovery.whyItMatters
          : SurpriseCopy.whyFor(type),
      evidenceIds: discovery.evidenceIds,
      insightRef: discovery.insightRef,
      createdAt: discovery.createdAt,
      chapterId: discovery.insightRef.chapterId,
      themeKey: themeKey,
    );
  }

  static String? _dominantThemeKey(Map<String, int> counts) {
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

  static String? _chapterTitleFromSummary(String summary) {
    final match = RegExp('“([^”]+)”').firstMatch(summary);
    return match?.group(1);
  }
}