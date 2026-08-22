import 'package:archiveme_mobile/features/archive_evidence/archive_belief_thread_model.dart';
import 'package:archiveme_mobile/features/archive_memory/archive_evolution_model.dart';

/// Copy-only paid value proof — no billing or entitlement changes.
abstract final class ArchivePaidValueProofSource {
  static const minTimelineItems = 3;

  static bool shouldShow({
    required int entryCount,
    required ArchiveBeliefThread belief,
    required ArchiveEvolutionTimeline? timeline,
    required bool returnProofSeen,
  }) {
    if (entryCount < 2) return false;
    if (!belief.hasEnoughData) return false;
    if (!returnProofSeen) return false;

    final timelineItems = timeline?.events.length ?? 0;
    if (timelineItems < minTimelineItems && !_beliefChanged(belief, timeline)) {
      return false;
    }

    return timelineItems >= minTimelineItems ||
        _beliefChanged(belief, timeline) ||
        _timelineHasProofEvidence(timeline);
  }

  static bool _beliefChanged(
    ArchiveBeliefThread belief,
    ArchiveEvolutionTimeline? timeline,
  ) {
    if (belief.whatChanged.trim().isNotEmpty) return true;
    if (belief.previousBeliefLine?.trim().isNotEmpty == true) return true;
    return timeline?.events.any(
          (e) =>
              e.type == ArchiveEvolutionEventType.changed ||
              e.type == ArchiveEvolutionEventType.feltLighter,
        ) ??
        false;
  }

  static bool _timelineHasProofEvidence(ArchiveEvolutionTimeline? timeline) {
    if (timeline == null) return false;
    return timeline.events.any(
      (e) =>
          e.type == ArchiveEvolutionEventType.feltLighter ||
          e.type == ArchiveEvolutionEventType.changed ||
          e.type == ArchiveEvolutionEventType.checkChosen,
    );
  }
}