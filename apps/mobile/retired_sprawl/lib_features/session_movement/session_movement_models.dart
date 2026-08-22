/// Session movement kinds aligned with web [SessionMovementKind].
enum SessionMovementKind {
  beliefChanged,
  confidenceMoved,
  newEvidenceAdded,
  contradictionAppeared,
  beliefWeakened,
  beliefStrengthened,
  comparisonPoint,
}

class SessionMovementSummaryView {
  const SessionMovementSummaryView({
    required this.id,
    required this.kind,
    required this.headline,
    required this.reason, this.detailLine,
    this.theoryId,
  });

  final String id;
  final SessionMovementKind kind;
  final String headline;
  final String? detailLine;
  final String reason;
  final String? theoryId;
}