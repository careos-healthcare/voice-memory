import 'pressure_pattern_review_model.dart';
import 'pressure_return_trigger_model.dart';

/// Decides whether to offer the return trigger. Pure and deterministic.
///
/// Offered when the user accepted the micro-experiment OR has enough entries
/// (5+) for a pressure review. Weak evidence with no accepted experiment
/// never produces a trigger.
class PressureReturnTriggerEngine {
  const PressureReturnTriggerEngine();

  PressureReturnTrigger build({
    required int entryCount,
    required bool experimentAccepted,
    bool accepted = false,
    bool dismissed = false,
  }) {
    if (accepted) {
      return const PressureReturnTrigger(
        status: PressureReturnTriggerStatus.accepted,
      );
    }
    if (dismissed) {
      return const PressureReturnTrigger(
        status: PressureReturnTriggerStatus.dismissed,
      );
    }
    final eligible =
        experimentAccepted || entryCount >= PressurePatternReview.minEntries;
    return PressureReturnTrigger(
      status: eligible
          ? PressureReturnTriggerStatus.eligible
          : PressureReturnTriggerStatus.notEligible,
    );
  }
}
