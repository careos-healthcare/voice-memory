import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import '../contradiction_detection/contradiction_report.dart';
import '../theme_tracking/theme_track.dart';
import '../theme_tracking/theme_tracker_service.dart';
import 'identity_models.dart';

/// Builds a living identity profile from evidence-backed archive signals only.
class IdentityEngine {
  const IdentityEngine();

  /// Minimum recordings that must mention a theme before a trait is emitted.
  static const int minTraitEvidenceCount = 2;

  IdentityProfile build({
    required List<JournalEntry> entries,
    Map<String, int>? themeBaseline,
    String? currentBelief,
  }) {
    final evidenceCount = archiveEvidenceReflectionCount(entries);
    final hasMin = archiveHasMinimumEvidence(entries);
    final now = DateTime.now().toUtc();

    if (!hasMin) {
      return IdentityProfile.empty(evidenceCount: evidenceCount);
    }

    final eligible = archiveEligibleEvidenceEntries(entries);
    final byId = {for (final e in eligible) e.id: e};
    final themes = const ThemeTrackerService().track(
      entries: entries,
      baselineCounts: themeBaseline,
    );

    final traits = <IdentityTrait>[];

    for (final theme in themes.topThemes) {
      final trait = _traitFromTheme(theme, byId);
      if (trait != null) traits.add(trait);
    }

    final belief =
        currentBelief?.trim() ??
        archiveBeliefFromReflections(entries)?.trim() ??
        '';
    if (belief.isNotEmpty) {
      final beliefTrait = _beliefBackedTrait(belief, eligible, byId);
      if (beliefTrait != null && !traits.any((t) => t.id == beliefTrait.id)) {
        traits.add(beliefTrait);
      }
    }

    final contradictions = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: belief,
    );
    if (contradictions.reports.isNotEmpty) {
      final top = contradictions.reports.first;
      if (top.confidenceScore >= 65) {
        traits.add(_contradictionTrait(top, eligible));
      }
    }

    if (traits.isEmpty) {
      return IdentityProfile(
        currentTraits: const [],
        emergingTraits: const [],
        decliningTraits: const [],
        lastUpdated: now,
        hasMinimumArchiveEvidence: true,
        evidenceReflectionCount: evidenceCount,
      );
    }

    final current = <IdentityTrait>[];
    final emerging = <IdentityTrait>[];
    final declining = <IdentityTrait>[];

    for (final trait in traits) {
      if (trait.evidenceCount < minTraitEvidenceCount) continue;
      switch (trait.trend) {
        case ThemeTrend.down:
          declining.add(trait);
        case ThemeTrend.up:
          emerging.add(trait);
          if (trait.confidence >= 58) current.add(trait);
        case ThemeTrend.stable:
          current.add(trait);
      }
    }

    int sortKey(IdentityTrait a, IdentityTrait b) =>
        b.confidence.compareTo(a.confidence);

    current.sort(sortKey);
    emerging.sort(sortKey);
    declining.sort(sortKey);

    // Emerging traits that are already top current are not duplicated.
    final currentIds = current.map((t) => t.id).toSet();
    final emergingOnly = emerging
        .where((t) => !currentIds.contains(t.id))
        .toList();

    return IdentityProfile(
      currentTraits: current,
      emergingTraits: emergingOnly,
      decliningTraits: declining,
      lastUpdated: now,
      hasMinimumArchiveEvidence: true,
      evidenceReflectionCount: evidenceCount,
    );
  }
}

IdentityTrait? _traitFromTheme(
  ArchiveTheme theme,
  Map<String, JournalEntry> byId,
) {
  if (theme.frequency < IdentityEngine.minTraitEvidenceCount) return null;

  final themeId =
      ThemeTrackerService.displayNames.entries
          .where((e) => e.value == theme.name)
          .map((e) => e.key)
          .firstOrNull ??
      theme.name.toLowerCase();
  final title = _titleForTheme(themeId, theme.trend, theme.frequency);
  if (title == null) return null;

  final entries = _entriesForTheme(themeId, byId);
  if (entries.length < IdentityEngine.minTraitEvidenceCount) return null;

  return _traitFromEntries(
    id: 'theme:$themeId',
    title: title,
    entries: entries,
    trend: theme.trend,
    frequency: theme.frequency,
  );
}

String? _titleForTheme(String themeId, ThemeTrend trend, int frequency) {
  switch (themeId) {
    case 'approval':
      return 'You seek approval';
    case 'confidence':
      if (trend == ThemeTrend.up) return 'You are becoming more confident';
      if (frequency >= 3) return 'You express confidence';
      return null;
    case 'avoidance':
      return 'You avoid conflict';
    case 'relationships':
      return frequency >= 3
          ? 'You focus on relationships'
          : 'You return to relationship themes';
    case 'career':
      return 'You focus on career';
    case 'money':
      return 'You focus on money';
    case 'health':
      return 'You focus on health';
    default:
      return null;
  }
}

List<JournalEntry> _entriesForTheme(
  String themeId,
  Map<String, JournalEntry> byId,
) {
  final keywords = ThemeTrackerService.canonicalThemeIds.contains(themeId)
      ? _themeKeywordList(themeId)
      : <String>[themeId];

  return byId.values.where((entry) {
    final blob = _entryBlob(entry);
    if (entry.reflection.recurringThemes.any(
      (t) => t.trim().toLowerCase() == themeId,
    )) {
      return true;
    }
    return keywords.any(blob.contains);
  }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

List<String> _themeKeywordList(String themeId) {
  const keys = {
    'approval': ['approval', 'validation', 'people-pleas'],
    'confidence': ['confidence', 'confident', 'trust my judgment'],
    'avoidance': ['avoid', 'avoidance', 'procrastinat'],
    'relationships': ['relationship', 'partner', 'family'],
    'career': ['career', 'work', 'networking', 'job'],
    'money': ['money', 'financial', 'income', 'salary'],
    'health': ['health', 'sleep', 'burnout', 'anxiety'],
  };
  return keys[themeId] ?? [themeId];
}

IdentityTrait? _beliefBackedTrait(
  String belief,
  List<JournalEntry> eligible,
  Map<String, JournalEntry> byId,
) {
  final supporting = eligible.where((e) {
    final obs = e.reflection.concreteObservation.trim();
    return obs.length >= 16 &&
        (obs == belief || belief.contains(obs) || obs.contains(belief));
  }).toList();

  final entries = supporting.length >= IdentityEngine.minTraitEvidenceCount
      ? supporting
      : (eligible.length >= IdentityEngine.minTraitEvidenceCount
            ? eligible.sublist(
                eligible.length - IdentityEngine.minTraitEvidenceCount,
              )
            : <JournalEntry>[]);

  if (entries.length < IdentityEngine.minTraitEvidenceCount) return null;

  return _traitFromEntries(
    id: 'belief:working',
    title: 'Your archive working belief is forming from saved moments',
    entries: entries,
    trend: ThemeTrend.stable,
    frequency: entries.length,
    confidenceCap: 62,
  );
}

IdentityTrait _contradictionTrait(
  ContradictionReport report,
  List<JournalEntry> eligible,
) {
  final ids = [report.originalEntryId, report.conflictingEntryId];
  final entries = eligible.where((e) => ids.contains(e.id)).toList();
  return _traitFromEntries(
    id: 'signal:contradiction',
    title: 'Your language about core themes is shifting',
    entries: entries.isNotEmpty
        ? entries
        : eligible.take(IdentityEngine.minTraitEvidenceCount).toList(),
    trend: ThemeTrend.up,
    frequency: entries.length.clamp(IdentityEngine.minTraitEvidenceCount, 99),
    confidenceCap: report.confidenceScore.clamp(50, 85),
  );
}

IdentityTrait _traitFromEntries({
  required String id,
  required String title,
  required List<JournalEntry> entries,
  required ThemeTrend trend,
  required int frequency,
  int? confidenceCap,
}) {
  final quotes = <String>[];
  final ids = <String>[];
  for (final e in entries.take(4)) {
    ids.add(e.id);
    quotes.add(_quoteForEntry(e));
  }

  var confidence = 38 + frequency * 9;
  if (trend == ThemeTrend.up) confidence += 10;
  if (trend == ThemeTrend.down) confidence += 4;
  if (confidenceCap != null) confidence = confidence.clamp(0, confidenceCap);
  confidence = confidence.clamp(0, 100);

  return IdentityTrait(
    id: id,
    title: title,
    confidence: confidence,
    evidenceCount: frequency,
    supportingRecordingIds: ids,
    supportingQuotes: quotes,
    trend: trend,
    firstSeen: entries.first.createdAt,
    lastSeen: entries.last.createdAt,
  );
}

String _quoteForEntry(JournalEntry entry) {
  final exact = entry.reflection.exactLanguagePattern.trim();
  if (exact.length >= 12) {
    return exact.length <= 140 ? exact : '${exact.substring(0, 140).trim()}…';
  }
  final line = entry.transcript.trim().split('\n').first.trim();
  if (line.length >= 12) {
    return line.length <= 140 ? line : '${line.substring(0, 140).trim()}…';
  }
  final obs = entry.reflection.concreteObservation.trim();
  return obs.isEmpty ? 'Saved words excerpt' : obs;
}

String _entryBlob(JournalEntry entry) {
  return [
    entry.transcript,
    entry.reflection.exactLanguagePattern,
    entry.reflection.concreteObservation,
    ...entry.reflection.recurringThemes,
  ].join(' ').toLowerCase();
}
