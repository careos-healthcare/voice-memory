import '../archive_explanations/explanation_models.dart';

/// Evidence-grounded interpretation journey for one archive insight.
class ArchiveInterpretation {
  const ArchiveInterpretation({
    required this.ref,
    required this.insightId,
    required this.kind,
    required this.title,
    required this.whyText,
    required this.supportingEvidence,
    required this.contradictingEvidence,
    required this.timeline,
    required this.relatedThemes,
    required this.relatedBeliefs,
    required this.relatedBlindSpots,
    required this.relatedContradictions,
    required this.whatThisMightMean,
    required this.supportsSummary,
    required this.contradictsSummary,
    required this.mindChange,
    required this.followUpQuestion,
    this.beliefStatement,
  });

  final ArchiveInsightRef ref;
  final String insightId;
  final ArchiveInsightKind kind;
  final String title;
  final String whyText;
  final List<EvidenceReference> supportingEvidence;
  final List<EvidenceReference> contradictingEvidence;
  final BeliefTimeline timeline;
  final List<RelatedTheme> relatedThemes;
  final List<RelatedBelief> relatedBeliefs;
  final List<RelatedBlindSpot> relatedBlindSpots;
  final List<RelatedContradiction> relatedContradictions;
  final String whatThisMightMean;
  final InterpretationEvidenceSummary supportsSummary;
  final InterpretationEvidenceSummary contradictsSummary;
  final InterpretationMindChange mindChange;
  final String followUpQuestion;
  final String? beliefStatement;

  bool get hasTimeline => timeline.points.isNotEmpty;

  bool get hasCrossReferences =>
      relatedThemes.isNotEmpty ||
      relatedBeliefs.isNotEmpty ||
      relatedBlindSpots.isNotEmpty ||
      relatedContradictions.isNotEmpty;

  bool get hasDeeperContent =>
      whatThisMightMean.isNotEmpty ||
      supportsSummary.bullets.isNotEmpty ||
      contradictsSummary.bullets.isNotEmpty ||
      mindChange.hasContent ||
      followUpQuestion.isNotEmpty;
}

class InterpretationEvidenceSummary {
  const InterpretationEvidenceSummary({
    required this.bullets,
    required this.entries,
  });

  final List<String> bullets;
  final List<EvidenceReference> entries;

  bool get isEmpty => bullets.isEmpty && entries.isEmpty;
}

class InterpretationMindChange {
  const InterpretationMindChange({
    required this.strongerIf,
    required this.weakerIf,
  });

  final List<String> strongerIf;
  final List<String> weakerIf;

  bool get hasContent => strongerIf.isNotEmpty || weakerIf.isNotEmpty;
}
