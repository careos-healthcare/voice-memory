import 'package:archiveme_mobile/features/insights/insight_evidence.dart';

/// Every displayed belief must ship with cited evidence.
class BeliefEvidenceBundle {
  const BeliefEvidenceBundle({
    required this.beliefId,
    required this.statement,
    required this.confidence,
    required this.supportingEvidence,
    required this.supportingReflectionIds,
    required this.supportingQuotes,
    required this.whyArchiveBelievesThis,
    required this.archiveConclusion,
  });

  final String beliefId;
  final String statement;
  final int confidence;
  final List<InsightEvidenceLine> supportingEvidence;
  final List<String> supportingReflectionIds;
  final List<String> supportingQuotes;
  final String whyArchiveBelievesThis;
  final String archiveConclusion;

  bool get hasMinimumEvidence =>
      supportingQuotes.isNotEmpty &&
      supportingReflectionIds.length >= 3 &&
      supportingEvidence.isNotEmpty;
}