import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import 'contradiction_report.dart';
import 'statement_analysis.dart';

/// Analyzes archive reflections for belief-relevant contradictions and gradual shifts.
class ContradictionDetectionService {
  const ContradictionDetectionService();

  ContradictionDetectionResult detect({
    required List<JournalEntry> entries,
    String? currentBelief,
  }) {
    final belief =
        currentBelief?.trim() ?? archiveBeliefFromReflections(entries)?.trim();
    final eligible = archiveEligibleEvidenceEntries(entries);
    if (eligible.length < 2) {
      return ContradictionDetectionResult(reports: const [], currentBelief: belief);
    }

    final statements = archivedStatementsFromEntries(eligible);
    final reports = <ContradictionReport>[];
    final seen = <String>{};

    for (var i = 0; i < statements.length; i++) {
      for (var j = i + 1; j < statements.length; j++) {
        final earlier = statements[i];
        final later = statements[j];
        if (!earlier.at.isBefore(later.at)) continue;
        if (earlier.entryId == later.entryId) continue;

        final report = _comparePair(earlier, later);
        if (report == null) continue;
        final key =
            '${report.originalEntryId}|${report.conflictingEntryId}|${report.kind.name}';
        if (!seen.add(key)) continue;
        reports.add(report);
      }
    }

    reports.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    return ContradictionDetectionResult(
      reports: reports.take(8).toList(),
      currentBelief: belief,
    );
  }
}

ContradictionReport? _comparePair(ArchivedStatement earlier, ArchivedStatement later) {
  final sharedThemes = earlier.themes.intersection(later.themes).toList();
  final sharedKeywords = earlier.keywords.intersection(later.keywords);

  final hasTopicLink = sharedThemes.isNotEmpty || sharedKeywords.length >= 2;
  if (!hasTopicLink) return null;

  final hardOpposition = (earlier.isStrongNegative && later.isPositive) ||
      (earlier.isPositive && later.isStrongNegative);
  final softToPositive =
      (earlier.isSoftNegative || earlier.softNegativeScore > 0) && later.isPositive;
  final gradualPolarity = softToPositive && !hardOpposition;
  final opposingPolarity = hardOpposition ||
      ((earlier.isNegative && later.isPositive) ||
          (earlier.isPositive && later.isNegative));

  if (!opposingPolarity && !gradualPolarity) return null;

  ContradictionKind kind;
  var confidence = 52;

  if (gradualPolarity) {
    kind = ContradictionKind.gradualShift;
    confidence = 58;
    if (earlier.isSoftNegative || earlier.text.toLowerCase().contains('uncomfortable')) {
      confidence += 8;
    }
    if (later.isPositive) confidence += 8;
    if (hasReversalPhrase(earlier.text, later.text)) confidence += 10;
  } else if (opposingPolarity && sharedThemes.isNotEmpty) {
    kind = ContradictionKind.reversedTheme;
    confidence = 68 + sharedThemes.length * 8;
    if (hasReversalPhrase(earlier.text, later.text)) confidence += 12;
  } else if (hasReversalPhrase(earlier.text, later.text)) {
    kind = ContradictionKind.changedLanguage;
    confidence = 62;
  } else if (opposingPolarity) {
    kind = ContradictionKind.opposingStatements;
    confidence = 55 + sharedKeywords.length * 5;
  } else {
    return null;
  }

  if (later.at.difference(earlier.at).inDays >= 30) confidence += 8;
  if (later.at.difference(earlier.at).inDays >= 90) confidence += 6;

  confidence = confidence.clamp(0, 100);

  return ContradictionReport(
    id: 'ctr-${earlier.entryId}-${later.entryId}',
    originalStatement: earlier.text,
    conflictingStatement: later.text,
    confidenceScore: confidence,
    originalEntryId: earlier.entryId,
    conflictingEntryId: later.entryId,
    kind: kind,
    sharedThemes: sharedThemes,
  );
}
