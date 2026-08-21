import 'package:archiveme_mobile/features/early_archive/archive_change_timeline_model.dart';

enum BeliefChangeType {
  softened,
  differentResponse,
  helpfulAction,
  lowerUrgency,
  unknown;

  String get analyticsValue => switch (this) {
    BeliefChangeType.softened => 'softened',
    BeliefChangeType.differentResponse => 'different_response',
    BeliefChangeType.helpfulAction => 'helpful_action',
    BeliefChangeType.lowerUrgency => 'lower_urgency',
    BeliefChangeType.unknown => 'unknown',
  };
}

class BeliefChangeEvidenceSnippet {
  const BeliefChangeEvidenceSnippet({
    required this.entryId,
    required this.label,
    required this.quote,
  });

  final String entryId;
  final String label;
  final String quote;
}

/// Grounded belief-change payoff — earlier and later evidence only.
class BeliefChangeMoment {
  const BeliefChangeMoment({
    required this.changeType,
    required this.earlierBeliefExample,
    required this.changeExample,
    required this.earlierSnippet,
    required this.laterSnippet,
    this.timeline,
  });

  final BeliefChangeType changeType;
  final String earlierBeliefExample;
  final String changeExample;
  final BeliefChangeEvidenceSnippet earlierSnippet;
  final BeliefChangeEvidenceSnippet laterSnippet;
  final ArchiveChangeTimeline? timeline;

  bool get canViewChangeTimeline => timeline != null && timeline!.hasContent;
}