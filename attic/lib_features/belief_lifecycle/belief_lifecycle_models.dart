/// User-facing lifecycle status for a belief / theory statement.
enum BeliefLifecycleStatus {
  emerging,
  stable,
  weakening,
  dormant,
  noLongerDetected,
}

/// Tracked phase in the belief lifecycle.
enum BeliefLifecyclePhase { firstAppearance, strengthening, weakening, death }

class BeliefLifecycleEvent {
  const BeliefLifecycleEvent({
    required this.phase,
    required this.date,
    required this.summary,
  });

  final BeliefLifecyclePhase phase;
  final DateTime date;
  final String summary;
}

/// Lifecycle for one belief statement.
class BeliefLifecycleEntry {
  const BeliefLifecycleEntry({
    required this.statement,
    required this.status,
    required this.firstSeen,
    required this.lastSeen,
    required this.isActiveInArchive,
    required this.events,
  });

  final String statement;
  final BeliefLifecycleStatus status;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final bool isActiveInArchive;
  final List<BeliefLifecycleEvent> events;

  bool get isNoLongerDetected =>
      status == BeliefLifecycleStatus.noLongerDetected;
}

/// Current + retired beliefs from evolution history.
class BeliefLifecycleView {
  const BeliefLifecycleView({required this.current, required this.retired});

  final BeliefLifecycleEntry? current;
  final List<BeliefLifecycleEntry> retired;

  bool get hasContent => current != null || retired.isNotEmpty;
}
