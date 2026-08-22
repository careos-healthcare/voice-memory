import 'package:archiveme_mobile/design/warm_archive_copy.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_explanations/archive_explanation_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/belief_timeline_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/contradiction_detection/contradiction_detection_service.dart';
import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_models.dart';
import 'package:archiveme_mobile/features/daily_discoveries/daily_discovery_store.dart';
import 'package:archiveme_mobile/features/discover/chapter_engine.dart';
import 'package:archiveme_mobile/features/discover/discover_models.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Generates one evidence-backed discovery when the journal grows.
class DailyDiscoveryEngine {
  const DailyDiscoveryEngine({
    this.beliefTimelineEngine = const BeliefTimelineEngine(),
    this.explanationEngine = const ArchiveExplanationEngine(),
  });

  final BeliefTimelineEngine beliefTimelineEngine;
  final ArchiveExplanationEngine explanationEngine;

  static int get minEligibleEntries =>
      ArchiveEvidenceGuard.minimumEvidenceCount;
  static const int minThemeDelta = 2;
  static const int minKeywordMentions = 3;

  static const Map<String, List<String>> _themeKeywords = {
    'approval': ['approval', 'approve', 'validation', 'validate'],
    'confidence': ['confident', 'confidence', 'sure of myself'],
    'work': ['work', 'job', 'career', 'office'],
    'relationships': ['relationship', 'partner', 'family', 'friend'],
    'stress': ['stress', 'stressed', 'overwhelmed', 'anxious'],
    'time': ['no time', 'not enough time', 'too busy'],
  };

  static const Map<String, String> _themeLabels = {
    'approval': 'approval',
    'confidence': 'confidence',
    'work': 'work',
    'relationships': 'relationships',
    'stress': 'stress',
    'time': 'time',
  };

  /// Loads or computes today's discovery after new entries arrive.
  Future<DailyDiscovery?> loadTodayDiscovery({
    required DailyDiscoveryStore store,
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) async {
    if (!ArchiveEvidenceGuard.canSurfaceDiscovery(entries)) return null;

    final viewed = await store.readViewedIds();
    final pending = await store.readPending();
    final baseline = await store.readBaseline();
    final sorted = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final last = sorted.last;

    final journalGrew =
        baseline == null ||
        baseline.lastEntryId != last.id ||
        baseline.entryCount != entries.length;

    if (!journalGrew) {
      if (pending != null && !viewed.contains(pending.id)) {
        return pending;
      }
      return null;
    }

    final discovery = detectDiscovery(
      entries: entries,
      state: state,
      baseline: baseline,
      viewedIds: viewed,
    );

    if (discovery != null) {
      await store.writePending(discovery);
      return discovery;
    }

    if (pending != null && !viewed.contains(pending.id)) {
      return pending;
    }
    return null;
  }

  /// Marks discovery viewed and advances baseline to current archive state.
  Future<void> acknowledgeDiscovery({
    required DailyDiscoveryStore store,
    required DailyDiscovery discovery,
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) async {
    await store.markViewed(discovery.id);
    await store.writePending(null);
    await store.writeBaseline(_snapshot(entries, state));
  }

  static const int minPriorEntriesForImmediateBaseline = 2;

  /// Post-save discovery — compares archive before the latest entry to now.
  Future<DailyDiscovery?> detectImmediateDiscovery({
    required DailyDiscoveryStore store,
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) async {
    if (archiveEvidenceReflectionCount(entries) < minEligibleEntries) {
      return null;
    }

    final viewed = await store.readViewedIds();
    final baseline =
        _baselineBeforeLatestEntry(entries) ?? await store.readBaseline();

    return detectDiscovery(
      entries: entries,
      state: state,
      baseline: baseline,
      viewedIds: viewed,
    );
  }

  /// All evidence-backed discoveries for priority picking (e.g. surprise pipeline).
  List<DailyDiscovery> detectAllDiscoveries({
    required List<JournalEntry> entries,
    required Set<String> viewedIds, ArchiveStateObjectV3? state,
    DailyDiscoveryBaseline? baseline,
  }) {
    if (archiveEvidenceReflectionCount(entries) < minEligibleEntries) {
      return const [];
    }

    final current = _snapshot(entries, state);
    final candidates = <DailyDiscovery>[];

    _detectNewBelief(entries, state, baseline, current, candidates);
    _detectBeliefTrend(entries, state, baseline, current, candidates);
    _detectContradictions(entries, state, baseline, current, candidates);
    _detectThemeShifts(entries, baseline, current, candidates);
    _detectChapterTransition(entries, baseline, current, candidates);
    _detectEmotionalShift(entries, baseline, current, candidates);
    _detectUnexpectedCorrelation(entries, baseline, candidates);

    return candidates.where((c) => !viewedIds.contains(c.id)).toList();
  }

  /// Baseline snapshot excluding the newest journal entry (post-save compare).
  DailyDiscoveryBaseline? baselineBeforeLatestEntry(
    List<JournalEntry> entries,
  ) => _baselineBeforeLatestEntry(entries);

  /// Pure detection — compare [baseline] to current archive; skip [viewedIds].
  DailyDiscovery? detectDiscovery({
    required List<JournalEntry> entries,
    required Set<String> viewedIds, ArchiveStateObjectV3? state,
    DailyDiscoveryBaseline? baseline,
  }) {
    if (archiveEvidenceReflectionCount(entries) < minEligibleEntries) {
      return null;
    }

    final fresh = detectAllDiscoveries(
      entries: entries,
      state: state,
      baseline: baseline,
      viewedIds: viewedIds,
    );
    if (fresh.isEmpty) return null;

    fresh.sort((a, b) => b.confidence.compareTo(a.confidence));
    return fresh.first;
  }

  DailyDiscoveryBaseline? _baselineBeforeLatestEntry(
    List<JournalEntry> entries,
  ) {
    final sorted = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.length < 2) return null;
    final prior = sorted.sublist(0, sorted.length - 1);
    if (archiveEvidenceReflectionCount(prior) <
        minPriorEntriesForImmediateBaseline) {
      return null;
    }
    final priorState = buildArchiveStateObjectV3(entries: prior);
    return _snapshot(prior, priorState);
  }

  DailyDiscoveryBaseline _snapshot(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  ) {
    final sorted = [...entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final belief =
        state?.belief?.trim() ?? archiveBeliefFromReflections(entries);
    final contradictions = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: belief,
    );
    final chapters = const DiscoverChapterEngine().build(entries);
    final timeline = beliefTimelineEngine.build(
      entries: entries,
      beliefText: belief,
    );

    return DailyDiscoveryBaseline(
      lastEntryId: sorted.isNotEmpty ? sorted.last.id : '',
      entryCount: entries.length,
      belief: belief,
      themeCounts: _keywordThemeCounts(entries),
      contradictionIds: contradictions.reports.map((r) => r.id).toList(),
      latestChapterId: chapters.isNotEmpty ? chapters.last.id : null,
      avgEmotionalIntensity: _avgIntensity(entries),
      beliefStrengthPercent: timeline.currentPercent,
    );
  }

  void _detectNewBelief(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DailyDiscoveryBaseline? baseline,
    DailyDiscoveryBaseline current,
    List<DailyDiscovery> out,
  ) {
    final belief = current.belief;
    if (belief == null || belief.isEmpty) return;
    final hadBelief =
        baseline?.belief != null && baseline!.belief!.trim().isNotEmpty;
    if (hadBelief) return;

    final evidence = archiveEligibleEvidenceEntries(
      entries,
    ).reversed.take(4).map((e) => e.id).toList();
    if (evidence.length < 2) return;

    out.add(
      DailyDiscovery(
        id: 'daily:new-belief:${belief.hashCode}',
        type: DailyDiscoveryType.newBelief,
        title: 'A belief is taking shape',
        summary:
            'Your archive now holds a working belief: “${_truncate(belief, 90)}”.',
        whyItMatters:
            'Naming a pattern gives you something concrete to compare against new recordings.',
        evidenceIds: evidence,
        confidence: 78,
        createdAt: entries.last.createdAt,
        insightRef: ArchiveInsightRef.belief(),
      ),
    );
  }

  void _detectBeliefTrend(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DailyDiscoveryBaseline? baseline,
    DailyDiscoveryBaseline current,
    List<DailyDiscovery> out,
  ) {
    if (baseline == null || current.belief == null) return;
    final delta =
        current.beliefStrengthPercent - baseline.beliefStrengthPercent;
    if (delta.abs() < 15) return;

    final evidence = archiveEligibleEvidenceEntries(
      entries,
    ).reversed.take(4).map((e) => e.id).toList();
    if (evidence.length < 2) return;

    if (delta >= 15) {
      out.add(
        DailyDiscovery(
          id: 'daily:belief-strengthen:${current.beliefStrengthPercent}',
          type: DailyDiscoveryType.beliefStrengthening,
          title: 'This belief is strengthening',
          summary: WarmArchiveCopy.beliefStrengtheningSummary(
            _truncate(current.belief!, 60),
          ),
          whyItMatters:
              'A strengthening pattern often means the archive is hearing it on repeat — worth noticing if it still fits.',
          evidenceIds: evidence,
          confidence: (65 + delta).clamp(60, 92).toDouble(),
          createdAt: entries.last.createdAt,
          insightRef: ArchiveInsightRef.belief(),
        ),
      );
    } else {
      out.add(
        DailyDiscovery(
          id: 'daily:belief-weaken:${current.beliefStrengthPercent}',
          type: DailyDiscoveryType.beliefWeakening,
          title: 'This belief may be loosening',
          summary: WarmArchiveCopy.beliefWeakeningSummary(
            _truncate(current.belief!, 60),
          ),
          whyItMatters:
              'Weakening language does not erase the pattern — it can mean your relationship to it is shifting.',
          evidenceIds: evidence,
          confidence: (65 + delta.abs()).clamp(60, 90).toDouble(),
          createdAt: entries.last.createdAt,
          insightRef: ArchiveInsightRef.belief(),
        ),
      );
    }
  }

  void _detectContradictions(
    List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
    DailyDiscoveryBaseline? baseline,
    DailyDiscoveryBaseline current,
    List<DailyDiscovery> out,
  ) {
    final belief = current.belief;
    final result = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: belief,
    );
    final priorIds = baseline?.contradictionIds.toSet() ?? {};
    final currentIds = current.contradictionIds.toSet();

    for (final report in result.reports) {
      if (!priorIds.contains(report.id)) {
        out.add(
          DailyDiscovery(
            id: 'daily:ctr-emerge:${report.id}',
            type: DailyDiscoveryType.contradictionEmerging,
            title: 'A new tension appeared',
            summary:
                'Two reflections pull apart: “${_truncate(report.originalStatement, 70)}” vs “${_truncate(report.conflictingStatement, 70)}”.',
            whyItMatters:
                'When two reflections pull apart, it often marks competing needs — '
                'both are real entries worth sitting with.',
            evidenceIds: report.recordingIds,
            confidence: report.confidenceScore.toDouble(),
            createdAt: entries.last.createdAt,
            insightRef: ArchiveInsightRef.contradiction(
              entryIdA: report.originalEntryId,
              entryIdB: report.conflictingEntryId,
            ),
          ),
        );
      }
    }

    for (final priorId in priorIds) {
      if (!currentIds.contains(priorId)) {
        out.add(
          DailyDiscovery(
            id: 'daily:ctr-resolved:$priorId',
            type: DailyDiscoveryType.contradictionResolved,
            title: 'A tension eased',
            summary:
                'An earlier contradiction is no longer showing up in your latest eligible reflections.',
            whyItMatters:
                'When opposing lines stop appearing together, the archive reads it as movement — not a final verdict.',
            evidenceIds: archiveEligibleEvidenceEntries(
              entries,
            ).reversed.take(3).map((e) => e.id).toList(),
            confidence: 62,
            createdAt: entries.last.createdAt,
            insightRef: ArchiveInsightRef.belief(),
          ),
        );
      }
    }
  }

  void _detectThemeShifts(
    List<JournalEntry> entries,
    DailyDiscoveryBaseline? baseline,
    DailyDiscoveryBaseline current,
    List<DailyDiscovery> out,
  ) {
    if (baseline == null) return;

    final recent = _entriesInWindow(entries, const Duration(days: 30));
    final prior = _entriesInWindow(
      entries,
      const Duration(days: 60),
      excludeRecentDays: 30,
    );
    if (recent.length < 2 || prior.length < 2) return;

    for (final entry in _themeKeywords.entries) {
      final key = entry.key;
      final keywords = entry.value;
      final nowCount = _countKeywordMentions(recent, keywords);
      final beforeCount = _countKeywordMentions(prior, keywords);
      final delta = nowCount - beforeCount;
      if (delta.abs() < minThemeDelta) continue;
      if (nowCount < minKeywordMentions && beforeCount < minKeywordMentions) {
        continue;
      }

      final label = _themeLabels[key] ?? key;
      final evidence = _entryIdsWithKeywords(
        entries,
        keywords,
      ).take(4).toList();
      if (evidence.length < 2) continue;

      if (delta >= minThemeDelta) {
        final recentSummary = LivingArchiveCopy.mentionCountInRecentRecordings(
          themeLabel: label,
          entries: entries,
          keywords: keywords,
        );
        out.add(
          DailyDiscovery(
            id: 'daily:theme-spike:$key:$nowCount',
            type: DailyDiscoveryType.themeSpike,
            title: 'Your archive noticed something.',
            summary: recentSummary,
            whyItMatters:
                'Spikes in language often precede conscious decisions — the archive is flagging the shift early.',
            evidenceIds: evidence,
            confidence: (60 + delta * 4).clamp(58, 88).toDouble(),
            createdAt: entries.last.createdAt,
            insightRef: ArchiveInsightRef.theme(key),
          ),
        );
      } else {
        final recentSummary = LivingArchiveCopy.mentionCountInRecentRecordings(
          themeLabel: label,
          entries: entries,
          keywords: keywords,
        );
        out.add(
          DailyDiscovery(
            id: 'daily:theme-decline:$key:$nowCount',
            type: DailyDiscoveryType.themeDecline,
            title: 'This pattern changed.',
            summary: recentSummary,
            whyItMatters:
                'Declining language can mean relief, avoidance, or a shift in focus — your recordings are the evidence.',
            evidenceIds: evidence,
            confidence: (60 + delta.abs() * 4).clamp(58, 86).toDouble(),
            createdAt: entries.last.createdAt,
            insightRef: ArchiveInsightRef.theme(key),
          ),
        );
      }
    }
  }

  void _detectChapterTransition(
    List<JournalEntry> entries,
    DailyDiscoveryBaseline? baseline,
    DailyDiscoveryBaseline current,
    List<DailyDiscovery> out,
  ) {
    final chapterId = current.latestChapterId;
    if (chapterId == null) return;
    if (baseline?.latestChapterId == chapterId) return;

    final chapters = const DiscoverChapterEngine().build(entries);
    DiscoverChapterSummary? chapter;
    for (final c in chapters) {
      if (c.id == chapterId) {
        chapter = c;
        break;
      }
    }
    if (chapter == null || chapter.entryIds.length < 2) return;

    out.add(
      DailyDiscovery(
        id: 'daily:chapter:$chapterId',
        type: DailyDiscoveryType.chapterTransition,
        title: 'A life chapter shifted',
        summary:
            'The archive grouped recent reflections into “${chapter.title}”.',
        whyItMatters:
            'Chapter transitions mark stretches of life where your language clusters — useful for revisiting later.',
        evidenceIds: chapter.entryIds.take(4).toList(),
        confidence: 70,
        createdAt: entries.last.createdAt,
        insightRef: ArchiveInsightRef.chapter(chapterId),
      ),
    );
  }

  void _detectEmotionalShift(
    List<JournalEntry> entries,
    DailyDiscoveryBaseline? baseline,
    DailyDiscoveryBaseline current,
    List<DailyDiscovery> out,
  ) {
    if (baseline?.avgEmotionalIntensity == null) return;
    final prior = baseline!.avgEmotionalIntensity!;
    final now = current.avgEmotionalIntensity;
    if (now == null) return;

    final delta = now - prior;
    if (delta.abs() < 1.2) return;

    final recent = archiveEligibleEvidenceEntries(entries).reversed.take(4);
    if (recent.length < 2) return;
    final ids = recent.map((e) => e.id).toList();

    final direction = delta > 0 ? 'higher' : 'lower';
    out.add(
      DailyDiscovery(
        id: 'daily:emotion:${delta > 0 ? 'up' : 'down'}:${now.round()}',
        type: DailyDiscoveryType.emotionalShift,
        title: 'Emotional intensity shifted',
        summary:
            'Recent reflections carry $direction emotional intensity than your prior baseline in the archive.',
        whyItMatters:
            'Intensity shifts are measured from your own words — not a mood score from outside the journal.',
        evidenceIds: ids,
        confidence: (62 + (delta.abs() * 3)).clamp(58, 85).toDouble(),
        createdAt: entries.last.createdAt,
        insightRef: ArchiveInsightRef.belief(),
      ),
    );
  }

  void _detectUnexpectedCorrelation(
    List<JournalEntry> entries,
    DailyDiscoveryBaseline? baseline,
    List<DailyDiscovery> out,
  ) {
    if (baseline == null) return;

    final surprises = explanationEngine.buildUnexpectedInsights(entries);
    for (var i = 0; i < surprises.length; i++) {
      final s = surprises[i];
      if (s.evidenceEntryIds.length < 2) continue;
      out.add(
        DailyDiscovery(
          id: 'daily:correlation:$i:${s.evidenceEntryIds.first}',
          type: DailyDiscoveryType.unexpectedCorrelation,
          title: 'An unexpected pattern',
          summary: s.body,
          whyItMatters:
              'Correlations the archive finds often differ from what you say matters most — worth a second look.',
          evidenceIds: s.evidenceEntryIds,
          confidence: s.confidence.toDouble(),
          createdAt: entries.last.createdAt,
          insightRef: ArchiveInsightRef.surprise(i),
        ),
      );
    }
  }

  Map<String, int> _keywordThemeCounts(List<JournalEntry> entries) {
    final counts = <String, int>{};
    for (final key in _themeKeywords.keys) {
      counts[key] = _countKeywordMentions(entries, _themeKeywords[key]!);
    }
    return counts;
  }

  static int _countKeywordMentions(
    List<JournalEntry> entries,
    List<String> keywords,
  ) {
    var n = 0;
    for (final e in entries) {
      final t = e.transcript.toLowerCase();
      if (keywords.any(t.contains)) n++;
    }
    return n;
  }

  static List<String> _entryIdsWithKeywords(
    List<JournalEntry> entries,
    List<String> keywords,
  ) {
    final ids = <String>[];
    for (final e in archiveEligibleEvidenceEntries(entries).reversed) {
      final t = e.transcript.toLowerCase();
      if (keywords.any(t.contains)) ids.add(e.id);
    }
    return ids;
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

  static double? _avgIntensity(List<JournalEntry> entries) {
    // Entries without an intensity reading are excluded rather than counted as
    // zero, which would drag the average toward a number nobody reported.
    final values = archiveEligibleEvidenceEntries(entries)
        .map((e) => e.reflection.emotionalIntensity)
        .where((value) => value > 0)
        .toList(growable: false);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static String _truncate(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}