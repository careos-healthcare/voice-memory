import 'package:archiveme_mobile/features/belief_changes/belief_evolution_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Full deep-dive payload for [/archive-deep-dive].
class ArchiveDeepDiveView {
  const ArchiveDeepDiveView({
    required this.beliefStatement,
    required this.confidencePercent,
    required this.why,
    required this.history,
    required this.patterns,
    required this.counterEvidence,
    required this.inquiryQuestions,
    required this.timeline,
    required this.supportingEntries,
    required this.evolutionTimeline,
  });

  final String beliefStatement;
  final int confidencePercent;
  final ArchiveDeepDiveWhySection why;
  final ArchiveDeepDiveBeliefHistory history;
  final ArchiveDeepDivePatternExplorer patterns;
  final ArchiveDeepDiveCounterEvidence counterEvidence;
  final List<ArchiveDeepDiveInquiryQuestion> inquiryQuestions;
  final ArchiveDeepDiveBeliefTimeline timeline;
  final List<JournalEntry> supportingEntries;
  final BeliefEvolutionTimeline evolutionTimeline;
}

class ArchiveDeepDiveWhySection {
  const ArchiveDeepDiveWhySection({
    required this.summaryLines,
    required this.evidenceCount,
    required this.supportingRecordings,
    required this.excerptLines,
  });

  final List<String> summaryLines;
  final int evidenceCount;
  final int supportingRecordings;
  final List<ArchiveDeepDiveExcerpt> excerptLines;
}

class ArchiveDeepDiveExcerpt {
  const ArchiveDeepDiveExcerpt({
    required this.entryId,
    required this.dateLabel,
    required this.quote,
  });

  final String entryId;
  final String dateLabel;
  final String quote;
}

class ArchiveDeepDiveBeliefHistory {
  const ArchiveDeepDiveBeliefHistory({
    required this.firstAppearance,
    required this.strongestAppearance,
    required this.latestAppearance,
    required this.thenSnapshot,
    required this.nowSnapshot,
    required this.hasDistinctEvolution,
  });

  final ArchiveDeepDiveAppearance firstAppearance;
  final ArchiveDeepDiveAppearance strongestAppearance;
  final ArchiveDeepDiveAppearance latestAppearance;
  final ArchiveDeepDiveEvidenceSnapshot thenSnapshot;
  final ArchiveDeepDiveEvidenceSnapshot nowSnapshot;
  final bool hasDistinctEvolution;
}

class ArchiveDeepDiveAppearance {
  const ArchiveDeepDiveAppearance({
    required this.label,
    required this.beliefText,
    required this.at,
    this.strengthPercent,
  });

  final String label;
  final String beliefText;
  final DateTime? at;
  final int? strengthPercent;
}

class ArchiveDeepDiveEvidenceSnapshot {
  const ArchiveDeepDiveEvidenceSnapshot({
    required this.beliefText,
    required this.excerpt,
    this.entryId,
    this.dateLabel,
  });

  final String beliefText;
  final String excerpt;
  final String? entryId;
  final String? dateLabel;
}

class ArchiveDeepDivePatternExplorer {
  const ArchiveDeepDivePatternExplorer({
    required this.relatedThemes,
    required this.connectedContradictions,
    required this.connectedBlindSpots,
  });

  final List<String> relatedThemes;
  final List<ArchiveDeepDiveConnectedInsight> connectedContradictions;
  final List<ArchiveDeepDiveConnectedInsight> connectedBlindSpots;
}

class ArchiveDeepDiveConnectedInsight {
  const ArchiveDeepDiveConnectedInsight({
    required this.kind,
    required this.headline,
    required this.detail,
    this.entryIds = const [],
  });

  final String kind;
  final String headline;
  final String detail;
  final List<String> entryIds;
}

class ArchiveDeepDiveCounterEvidence {
  const ArchiveDeepDiveCounterEvidence({
    required this.forExcerpts,
    required this.againstExcerpts,
    required this.againstSummaries,
  });

  final List<ArchiveDeepDiveExcerpt> forExcerpts;
  final List<ArchiveDeepDiveExcerpt> againstExcerpts;
  final List<String> againstSummaries;
}

class ArchiveDeepDiveInquiryQuestion {
  const ArchiveDeepDiveInquiryQuestion({
    required this.id,
    required this.prompt,
    required this.rationale,
  });

  final String id;
  final String prompt;
  final String rationale;
}

class ArchiveDeepDiveBeliefTimeline {
  const ArchiveDeepDiveBeliefTimeline({
    required this.firstMention,
    required this.keyRecordings,
    required this.evolutionEvents,
    required this.mostRecent,
  });

  final ArchiveDeepDiveTimelineEvent? firstMention;
  final List<ArchiveDeepDiveTimelineEvent> keyRecordings;
  final List<ArchiveDeepDiveTimelineEvent> evolutionEvents;
  final ArchiveDeepDiveTimelineEvent? mostRecent;
}

class ArchiveDeepDiveTimelineEvent {
  const ArchiveDeepDiveTimelineEvent({
    required this.label,
    required this.subtitle,
    this.entryId,
    this.at,
  });

  final String label;
  final String subtitle;
  final String? entryId;
  final DateTime? at;
}