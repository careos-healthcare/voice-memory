import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_copy.dart';
import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:archiveme_mobile/features/theme_tracking/theme_tracker_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Evidence-backed surprises — self-image vs what the archive shows.
class ArchiveSurprisesEngine {
  const ArchiveSurprisesEngine({
    this.themeTracker = const ThemeTrackerService(),
    this.minEligible = 10,
    this.minEvidenceIds = 3,
    this.maxObservations = 4,
    this.minDominantPercent = 35,
    this.maxContrastPercent = 12,
    this.minDominantMentions = 8,
    this.minCessationPeak = 5,
    this.minLoopWeeks = 3,
    this.minLoopHits = 5,
  });

  final ThemeTrackerService themeTracker;
  final int minEligible;
  final int minEvidenceIds;
  final int maxObservations;
  final int minDominantPercent;
  final int maxContrastPercent;
  final int minDominantMentions;
  final int minCessationPeak;
  final int minLoopWeeks;
  final int minLoopHits;

  static const _importancePhrases = [
    'matter most',
    'matters most',
    'most important',
    'really important',
    'so important',
    'priority',
    'care about',
    'care most',
  ];

  static const _importanceKeywords = <String, List<String>>{
    'relationships': [
      'relationship',
      'partner',
      'marriage',
      'family',
      'friend',
    ],
    'health': ['health', 'sleep', 'exercise', 'body', 'energy'],
    'career': ['career', 'work', 'job', 'manager', 'promotion'],
    'money': ['money', 'finance', 'financial', 'salary', 'runway'],
    'confidence': ['confidence', 'self-doubt', 'imposter', 'certain'],
    'approval': ['approval', 'validate', 'people-pleas'],
    'avoidance': ['avoid', 'procrastinat', 'delay', 'put off'],
  };

  static const _loopPhrases = [
    'every week',
    'each week',
    'week after week',
    'same decision',
    'keep postpon',
    'postponing',
    'revisit',
    'circling back',
    'again and again',
    'same conversation',
  ];

  static const _decisionKeywords = [
    'decision',
    'decide',
    'postpone',
    'delay',
    'hiring',
    'runway',
    'stuck choosing',
  ];

  static const _bannedObservationFragments = [
    'you focus on',
    'you may keep returning',
    'forming from reflections',
    'you avoid conflict',
    'you express confidence',
    'unexpected observation',
  ];

  ArchiveSurprisesView build({required List<JournalEntry> entries}) {
    if (!archiveHasMinimumEvidence(entries)) {
      return const ArchiveSurprisesView(
        observations: [],
        emptyMessage: ArchiveSurprisesCopy.emptyNeedMoreEvidence,
      );
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < minEligible) {
      return const ArchiveSurprisesView(
        observations: [],
        emptyMessage: ArchiveSurprisesCopy.emptyNeedMoreEvidence,
      );
    }

    final candidates = <ArchiveSurpriseObservation>[];
    _detectThemeDominanceGaps(eligible, candidates);
    _detectThemeCessation(eligible, candidates);
    _detectRepeatedDecisionLoop(eligible, candidates);
    _detectStatedImportanceGaps(eligible, candidates);

    final filtered = candidates
        .where((c) => !_isGeneric(c.observation))
        .where((c) => c.evidenceEntryIds.length >= minEvidenceIds)
        .toList();

    filtered.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));

    final top = filtered.take(maxObservations).toList();
    if (top.isEmpty) {
      return const ArchiveSurprisesView(
        observations: [],
        emptyMessage: ArchiveSurprisesCopy.emptyNoneYet,
      );
    }

    return ArchiveSurprisesView(observations: top);
  }

  void _detectThemeDominanceGaps(
    List<JournalEntry> eligible,
    List<ArchiveSurpriseObservation> out,
  ) {
    final total = eligible.length;
    final byTheme = <String, List<JournalEntry>>{
      for (final id in ThemeTrackerService.canonicalThemeIds) id: [],
    };

    for (final e in eligible) {
      for (final id in ThemeTrackerService.themesForEntry(e)) {
        byTheme[id]!.add(e);
      }
    }

    final ranked = byTheme.entries.where((e) => e.value.isNotEmpty).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    if (ranked.isEmpty) return;
    final dominant = ranked.first;
    final dominantCount = dominant.value.length;
    final dominantPct = _percent(dominantCount, total);
    if (dominantPct < minDominantPercent ||
        dominantCount < minDominantMentions) {
      return;
    }

    final dominantLabel =
        ThemeTrackerService.displayNames[dominant.key] ?? dominant.key;

    for (final contrast in ranked.skip(1)) {
      final contrastCount = contrast.value.length;
      final contrastPct = _percent(contrastCount, total);
      if (contrastPct > maxContrastPercent && contrastCount > 2) continue;
      if (dominantCount < contrastCount * 3) continue;

      final contrastLabel =
          ThemeTrackerService.displayNames[contrast.key] ?? contrast.key;
      final observation = ArchiveSurprisesCopy.themeDominanceGap(
        dominantLabel: dominantLabel,
        dominantPercent: dominantPct,
        contrastLabel: contrastLabel,
        contrastPercent: contrastPct,
        contrastCount: contrastCount,
      );

      final ids = _uniqueIds([
        ...dominant.value.take(4),
        ...contrast.value.take(3),
      ]);
      if (ids.length < minEvidenceIds) continue;

      out.add(
        ArchiveSurpriseObservation(
          id: 'surprise:gap:${dominant.key}:${contrast.key}',
          kind: ArchiveSurpriseKind.themeDominanceGap,
          observation: observation,
          evidenceCount: ids.length,
          evidenceEntryIds: ids,
          confidenceScore: (dominantPct - contrastPct).clamp(60, 92),
        ),
      );
      break;
    }
  }

  void _detectThemeCessation(
    List<JournalEntry> eligible,
    List<ArchiveSurpriseObservation> out,
  ) {
    final local = <ArchiveSurpriseObservation>[];
    final archiveEnd = eligible.last.createdAt;

    for (final id in ThemeTrackerService.canonicalThemeIds) {
      final hits = eligible
          .where((e) => ThemeTrackerService.themesForEntry(e).contains(id))
          .toList();
      if (hits.length < minCessationPeak) continue;

      final lastMention = hits.last.createdAt;
      if (!archiveEnd.isAfter(lastMention)) continue;
      if (archiveEnd.difference(lastMention).inDays < 45) continue;

      final monthly = _monthlyBuckets(id, eligible);
      final peak = monthly.isEmpty
          ? 0
          : monthly.map((b) => b.count).reduce((a, b) => a > b ? a : b);
      if (peak < minCessationPeak) continue;

      final lastActiveMonth = DateTime(
        lastMention.toLocal().year,
        lastMention.toLocal().month,
      );

      final label = ThemeTrackerService.displayNames[id] ?? id;
      final ids = _uniqueIds(hits.take(6).toList());
      if (ids.length < minEvidenceIds) continue;

      local.add(
        ArchiveSurpriseObservation(
          id: 'surprise:cessation:$id',
          kind: ArchiveSurpriseKind.themeStoppedMentioning,
          observation: ArchiveSurprisesCopy.themeStoppedMentioning(
            themeLabel: label,
            lastMentionMonth: lastActiveMonth,
          ),
          evidenceCount: ids.length,
          evidenceEntryIds: ids,
          confidenceScore: (70 + peak).clamp(65, 90),
        ),
      );
    }
    if (local.isEmpty) return;
    local.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    out.add(local.first);
  }

  void _detectRepeatedDecisionLoop(
    List<JournalEntry> eligible,
    List<ArchiveSurpriseObservation> out,
  ) {
    final byWeek = <int, List<JournalEntry>>{};

    for (final e in eligible) {
      if (!_mentionsDecisionLoop(e.transcript)) continue;
      final key = _weekKey(e.createdAt);
      byWeek.putIfAbsent(key, () => []).add(e);
    }

    final weeks = byWeek.entries.where((e) => e.value.isNotEmpty).toList();
    final totalHits = weeks.fold<int>(0, (s, w) => s + w.value.length);
    if (weeks.length < minLoopWeeks || totalHits < minLoopHits) return;

    final ids = _uniqueIds(weeks.expand((w) => w.value).take(8).toList());
    if (ids.length < minEvidenceIds) return;

    out.add(
      ArchiveSurpriseObservation(
        id: 'surprise:loop:decision',
        kind: ArchiveSurpriseKind.repeatedDecisionLoop,
        observation: ArchiveSurprisesCopy.repeatedDecisionLoop(
          weekCount: weeks.length,
          recordingCount: totalHits,
        ),
        evidenceCount: ids.length,
        evidenceEntryIds: ids,
        confidenceScore: (65 + weeks.length * 4).clamp(68, 88),
      ),
    );
  }

  void _detectStatedImportanceGaps(
    List<JournalEntry> eligible,
    List<ArchiveSurpriseObservation> out,
  ) {
    final total = eligible.length;

    for (final entry in _importanceKeywords.entries) {
      final themeId = entry.key;
      final keywords = entry.value;
      final importanceHits = <JournalEntry>[];

      for (final e in eligible) {
        final t = e.transcript.toLowerCase();
        final mentionsTheme =
            keywords.any(t.contains) ||
            ThemeTrackerService.themesForEntry(e).contains(themeId);
        final claimsImportance =
            _importancePhrases.any(t.contains) && mentionsTheme;
        if (claimsImportance) importanceHits.add(e);
      }

      if (importanceHits.length < 2) continue;

      final mentionHits = eligible
          .where(
            (e) =>
                ThemeTrackerService.themesForEntry(e).contains(themeId) ||
                keywords.any(e.transcript.toLowerCase().contains),
          )
          .toList();

      final share = _percent(mentionHits.length, total);
      if (share > maxContrastPercent && mentionHits.length > 3) continue;

      final label = ThemeTrackerService.displayNames[themeId] ?? themeId;
      final observation = ArchiveSurprisesCopy.statedImportanceGap(
        themeLabel: label,
        sharePercent: share,
        mentionCount: mentionHits.length,
      );

      final ids = _uniqueIds([...importanceHits, ...mentionHits]);
      if (ids.length < minEvidenceIds) continue;

      out.add(
        ArchiveSurpriseObservation(
          id: 'surprise:importance:$themeId',
          kind: ArchiveSurpriseKind.statedImportanceGap,
          observation: observation,
          evidenceCount: ids.length,
          evidenceEntryIds: ids,
          confidenceScore: (75 + importanceHits.length * 3).clamp(70, 92),
        ),
      );
    }
  }

  bool _mentionsDecisionLoop(String transcript) {
    final lower = transcript.toLowerCase();
    if (_loopPhrases.any(lower.contains)) return true;
    final decisionHits = _decisionKeywords.where(lower.contains).length;
    return decisionHits >= 2;
  }

  List<_MonthBucket> _monthlyBuckets(
    String themeId,
    List<JournalEntry> eligible,
  ) {
    final buckets = <String, _MonthBucket>{};
    for (final e in eligible) {
      if (!ThemeTrackerService.themesForEntry(e).contains(themeId)) continue;
      final local = e.createdAt.toLocal();
      final key = '${local.year}-${local.month.toString().padLeft(2, '0')}';
      final existing = buckets[key];
      if (existing == null) {
        buckets[key] = _MonthBucket(
          key: key,
          monthStart: DateTime(local.year, local.month),
          count: 1,
        );
      } else {
        buckets[key] = _MonthBucket(
          key: key,
          monthStart: existing.monthStart,
          count: existing.count + 1,
        );
      }
    }
    final keys = buckets.keys.toList()..sort();
    return keys.map((k) => buckets[k]!).toList();
  }

  int _weekKey(DateTime at) {
    final local = at.toLocal();
    return local.year * 100 + _isoWeek(local);
  }

  int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: 3 - (date.weekday + 6) % 7));
    final firstThursday = DateTime(thursday.year, 1, 4);
    return 1 + ((thursday.difference(firstThursday).inDays) / 7).floor();
  }

  int _percent(int part, int total) =>
      total == 0 ? 0 : ((part / total) * 100).round();

  List<String> _uniqueIds(List<JournalEntry> entries) {
    final seen = <String>{};
    final out = <String>[];
    for (final e in entries) {
      if (seen.add(e.id)) out.add(e.id);
    }
    return out;
  }

  bool _isGeneric(String observation) {
    final lower = observation.toLowerCase();
    return _bannedObservationFragments.any(lower.contains);
  }
}

class _MonthBucket {
  const _MonthBucket({
    required this.key,
    required this.monthStart,
    required this.count,
  });

  final String key;
  final DateTime monthStart;
  final int count;
}