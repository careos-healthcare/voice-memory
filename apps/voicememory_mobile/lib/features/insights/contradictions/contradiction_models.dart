import '../insight_evidence.dart';

class ContradictionEvidence {
  const ContradictionEvidence({
    required this.role,
    required this.lines,
  });

  /// e.g. stated_desire | stated_action | pattern
  final String role;
  final List<InsightEvidenceLine> lines;
}

class ContradictionInsight {
  const ContradictionInsight({
    required this.id,
    required this.summary,
    required this.confidence,
    required this.evidenceCount,
    required this.supportingReflectionIds,
    required this.evidence,
    required this.firstSeen,
    required this.lastSeen,
    this.statedDesire,
    this.statedAction,
    this.recurringPattern,
  });

  final String id;
  final String summary;
  final int confidence;
  final int evidenceCount;
  final List<String> supportingReflectionIds;
  final List<ContradictionEvidence> evidence;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String? statedDesire;
  final String? statedAction;
  final String? recurringPattern;
}
