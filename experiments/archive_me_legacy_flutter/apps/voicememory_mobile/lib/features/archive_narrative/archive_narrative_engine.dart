import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../belief_evolution/belief_evolution_models.dart';
import '../belief_shift/belief_shift_engine.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../identity_engine/identity_engine.dart';
import '../theme_tracking/theme_track.dart';
import '../theme_tracking/theme_tracker_service.dart';
import 'narrative_summary_models.dart';

/// Synthesizes an evidence-only narrative from archive belief systems.
class ArchiveNarrativeEngine {
  const ArchiveNarrativeEngine();

  static const int minThemeMentionsForShift = 2;

  NarrativeSummary build({
    required List<JournalEntry> entries,
    String? currentBelief,
    Map<String, int>? themeBaseline,
    BeliefEvolutionTimeline? beliefEvolution,
  }) {
    final evidenceCount = archiveEvidenceReflectionCount(entries);
    if (!archiveHasMinimumEvidence(entries)) {
      return NarrativeSummary.empty(evidenceCount: evidenceCount);
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.isEmpty) {
      return NarrativeSummary.empty(evidenceCount: evidenceCount);
    }

    final belief =
        currentBelief?.trim() ??
        archiveBeliefFromReflections(entries)?.trim() ??
        '';
    final themes = const ThemeTrackerService().track(
      entries: entries,
      baselineCounts: themeBaseline,
    );
    final identity = const IdentityEngine().build(
      entries: entries,
      themeBaseline: themeBaseline,
      currentBelief: belief,
    );
    final shifts = const BeliefShiftEngine().detect(
      entries: entries,
      currentBelief: belief,
    );
    const contradictions = ContradictionDetectionService();
    final tension = contradictions.detect(
      entries: entries,
      currentBelief: belief,
    );

    final recordingIds = <String>{};
    final supportingBeliefs = <String>[];
    final supportingThemes = <String>{};
    final sentences = <String>[];

    final spanLabel = _spanLabel(eligible);
    if (spanLabel != null) {
      sentences.add(
        'Over the last $spanLabel your archive draws on ${eligible.length} '
        'saved moments with enough spoken detail to trace change.',
      );
      recordingIds.addAll(eligible.map((e) => e.id).take(6));
    }

    final evolutionNarrative = _beliefEvolutionNarrative(beliefEvolution);
    if (evolutionNarrative != null) {
      sentences.add(evolutionNarrative.sentence);
      recordingIds.addAll(evolutionNarrative.entryIds);
      supportingBeliefs.addAll(evolutionNarrative.beliefs);
    }

    final approvalToConfidence = _approvalToConfidenceNarrative(eligible);
    if (approvalToConfidence != null) {
      sentences.add(approvalToConfidence.sentence);
      recordingIds.addAll(approvalToConfidence.entryIds);
      supportingBeliefs.addAll(approvalToConfidence.beliefs);
      supportingThemes.addAll(approvalToConfidence.themes);
    }

    final topGrowth = _topThemeGrowthNarrative(themes.topThemes, eligible);
    if (topGrowth != null) {
      sentences.add(topGrowth.sentence);
      recordingIds.addAll(topGrowth.entryIds);
      supportingBeliefs.addAll(topGrowth.beliefs);
      supportingThemes.addAll(topGrowth.themes);
    }

    if (shifts.reports.isNotEmpty && sentences.length < 3) {
      final shift = shifts.reports.first;
      sentences.add(
        'A major shift appears between earlier and later recordings: '
        'from "${_shorten(shift.originalBelief)}" toward "${_shorten(shift.newBelief)}".',
      );
      recordingIds.addAll(shift.evidenceIds);
      supportingBeliefs.add(shift.originalBelief);
      supportingBeliefs.add(shift.newBelief);
      supportingThemes.addAll(shift.sharedTopics);
    }

    if (identity.hasTraits && sentences.length < 3) {
      final trait = [
        ...identity.emergingTraits,
        ...identity.currentTraits,
      ].firstOrNull;
      if (trait != null) {
        sentences.add(
          'Across recent recordings the archive hears: ${trait.title.toLowerCase()}.',
        );
        recordingIds.addAll(trait.supportingRecordingIds);
        supportingBeliefs.addAll(trait.supportingQuotes.take(2));
      }
    }

    if (tension.hasPossibleBeliefChange &&
        sentences.length < 4 &&
        tension.reports.isNotEmpty) {
      final report = tension.reports.first;
      if (report.confidenceScore >= 60) {
        sentences.add(
          'Some recordings hold tension between earlier and later language on '
          '${report.sharedThemes.isNotEmpty ? report.sharedThemes.join(', ') : 'core themes'}.',
        );
        recordingIds.addAll(report.recordingIds);
        supportingBeliefs.add(report.originalStatement);
        supportingBeliefs.add(report.conflictingStatement);
        supportingThemes.addAll(report.sharedThemes);
      }
    }

    if (belief.isNotEmpty && supportingBeliefs.length < 3) {
      final beliefLine = _beliefLine(belief, eligible);
      if (beliefLine != null &&
          !supportingBeliefs.contains(beliefLine.belief)) {
        supportingBeliefs.add(beliefLine.belief);
        recordingIds.add(beliefLine.entryId);
      }
    }

    if (sentences.isEmpty) {
      return NarrativeSummary(
        summary: '',
        supportingBeliefs: const [],
        supportingThemes: const [],
        supportingRecordingIds: const [],
        hasMinimumArchiveEvidence: true,
        evidenceReflectionCount: evidenceCount,
      );
    }

    final dedupedBeliefs = <String>[];
    final seenBeliefs = <String>{};
    for (final b in supportingBeliefs) {
      final key = b.trim().toLowerCase();
      if (key.length < 12 || !seenBeliefs.add(key)) continue;
      dedupedBeliefs.add(
        b.length <= 160 ? b : '${b.substring(0, 160).trim()}…',
      );
      if (dedupedBeliefs.length >= 5) break;
    }

    return NarrativeSummary(
      summary: sentences.join(' '),
      supportingBeliefs: dedupedBeliefs,
      supportingThemes: supportingThemes.toList()..sort(),
      supportingRecordingIds: recordingIds.toList(),
      hasMinimumArchiveEvidence: true,
      evidenceReflectionCount: evidenceCount,
    );
  }
}

class _NarrativeEvidence {
  const _NarrativeEvidence({
    required this.sentence,
    required this.entryIds,
    required this.beliefs,
    required this.themes,
  });

  final String sentence;
  final List<String> entryIds;
  final List<String> beliefs;
  final List<String> themes;
}

_NarrativeEvidence? _beliefEvolutionNarrative(
  BeliefEvolutionTimeline? timeline,
) {
  if (timeline == null || !timeline.hasEvolution) return null;
  final first = timeline.firstBelief;
  final current = timeline.currentBelief;
  if (first == null || current == null) return null;

  final entryIds = <String>{};
  final beliefs = <String>[first.beliefText, current.beliefText];
  for (final block in timeline.blocks) {
    entryIds.addAll(block.version.supportingEntryIds);
    for (final line in block.evidence) {
      entryIds.add(line.entryId);
      if (beliefs.length < 4 && line.quote.length >= 12) {
        beliefs.add(line.quote);
      }
    }
  }

  return _NarrativeEvidence(
    sentence:
        'Recorded belief evolution moves from "${_shorten(first.beliefText)}" '
        'to "${_shorten(current.beliefText)}".',
    entryIds: entryIds.toList(),
    beliefs: beliefs,
    themes: const [],
  );
}

_NarrativeEvidence? _approvalToConfidenceNarrative(
  List<JournalEntry> eligible,
) {
  if (eligible.length < 4) return null;

  final midpoint = eligible[eligible.length ~/ 2].createdAt;
  final early = eligible.where((e) => !e.createdAt.isAfter(midpoint)).toList();
  final late = eligible.where((e) => e.createdAt.isAfter(midpoint)).toList();
  if (early.length < 2 || late.length < 2) return null;

  final earlyApproval = _entriesWithTheme(early, 'approval');
  final lateConfidence = _entriesWithTheme(late, 'confidence');
  if (earlyApproval.length < ArchiveNarrativeEngine.minThemeMentionsForShift ||
      lateConfidence.length < ArchiveNarrativeEngine.minThemeMentionsForShift) {
    return null;
  }

  final beliefs = <String>[];
  for (final e in [...earlyApproval.take(1), ...lateConfidence.take(1)]) {
    final line = _quoteForEntry(e);
    if (line.isNotEmpty) beliefs.add(line);
  }

  return _NarrativeEvidence(
    sentence:
        'Over the last ${_monthsBetween(eligible.first.createdAt, eligible.last.createdAt)} '
        'months your archive shows a gradual shift from seeking approval to trusting '
        'your own judgement.',
    entryIds: [
      ...earlyApproval.map((e) => e.id),
      ...lateConfidence.map((e) => e.id),
    ],
    beliefs: beliefs,
    themes: const ['Approval', 'Confidence'],
  );
}

_NarrativeEvidence? _topThemeGrowthNarrative(
  List<ArchiveTheme> topThemes,
  List<JournalEntry> eligible,
) {
  for (final theme in topThemes) {
    if (theme.trend != ThemeTrend.up || theme.frequency < 2) continue;
    final themeId = ThemeTrackerService.displayNames.entries
        .where((e) => e.value == theme.name)
        .map((e) => e.key)
        .firstOrNull;
    if (themeId == null) continue;

    final matches = _entriesWithTheme(eligible, themeId);
    if (matches.length < 2) continue;

    final label = theme.name.toLowerCase() == 'confidence'
        ? 'confidence growth'
        : '${theme.name.toLowerCase()} growth';

    return _NarrativeEvidence(
      sentence: 'The strongest recurring theme has been $label.',
      entryIds: matches.map((e) => e.id).take(4).toList(),
      beliefs: matches
          .take(2)
          .map(_quoteForEntry)
          .where((q) => q.length >= 12)
          .toList(),
      themes: [theme.name],
    );
  }
  return null;
}

({String belief, String entryId})? _beliefLine(
  String belief,
  List<JournalEntry> eligible,
) {
  for (final e in eligible.reversed) {
    final obs = e.reflection.concreteObservation.trim();
    if (obs == belief || belief.contains(obs) || obs.contains(belief)) {
      return (belief: obs, entryId: e.id);
    }
  }
  return eligible.isNotEmpty
      ? (belief: belief, entryId: eligible.last.id)
      : null;
}

List<JournalEntry> _entriesWithTheme(
  List<JournalEntry> entries,
  String themeId,
) {
  return entries
      .where((e) => ThemeTrackerService.themesForEntry(e).contains(themeId))
      .toList();
}

String? _spanLabel(List<JournalEntry> eligible) {
  if (eligible.length < 2) return null;
  final months = _monthsBetween(
    eligible.first.createdAt,
    eligible.last.createdAt,
  );
  if (months >= 1) return '$months months';
  final days = eligible.last.createdAt
      .difference(eligible.first.createdAt)
      .inDays;
  if (days >= 14) return '$days days';
  return 'recent weeks';
}

int _monthsBetween(DateTime start, DateTime end) {
  final days = end.difference(start).inDays;
  return (days / 30).round().clamp(1, 120);
}

String _quoteForEntry(JournalEntry entry) {
  final exact = entry.reflection.exactLanguagePattern.trim();
  if (exact.length >= 12) {
    return exact.length <= 140 ? exact : '${exact.substring(0, 140).trim()}…';
  }
  final obs = entry.reflection.concreteObservation.trim();
  if (obs.length >= 12) {
    return obs.length <= 140 ? obs : '${obs.substring(0, 140).trim()}…';
  }
  final line = entry.transcript.trim().split('\n').first.trim();
  return line.length <= 140 ? line : '${line.substring(0, 140).trim()}…';
}

String _shorten(String text) {
  final t = text.trim();
  if (t.length <= 80) return t;
  return '${t.substring(0, 80).trim()}…';
}
