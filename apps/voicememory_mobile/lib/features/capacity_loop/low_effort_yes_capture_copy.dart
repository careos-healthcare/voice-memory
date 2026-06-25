import '../../product/archive_positioning_copy.dart';
import 'capacity_decision_outcome_copy.dart';
import 'capacity_decision_outcome_models.dart';
import 'capacity_pull_reason_copy.dart';
import 'capacity_pull_reason_models.dart';
import 'low_effort_yes_capture_models.dart';

/// Copy for low-effort yes capture — 10-second check-in, no journaling pressure.
abstract final class LowEffortYesCaptureCopy {
  LowEffortYesCaptureCopy._();

  static const route = '/quick-yes-capture';
  static const recordRoute = '/record';

  static const corePromise = 'Save the moment in 10 seconds.';

  static const title = ArchivePositioningCopy.quickYesMoment;
  static const body =
      'No need to explain everything. Mark what pulled you toward yes, then add a note only if you want.';
  static const pullSectionTitle = 'What pulled you toward yes?';
  static const decisionSectionTitle = 'What did you choose?';

  static const quickSaveCta = 'Quick save';
  static const recordInsteadCta = 'Record instead';
  static const optionalVoiceNoteCta = 'Add voice note';

  static const compactCardTitle = title;
  static const compactCardBody = body;

  static const entryObservation = 'Quick yes moment saved.';

  static const dashboardSignalAvailable = 'Quick capture available: yes';
  static const dashboardSignalUnavailable = 'Quick capture available: no';

  static String labelForPullReason(String id) =>
      CapacityPullReasonCopy.labelForReason(id);

  static String labelForOutcome(String id) =>
      CapacityDecisionOutcomeCopy.labelForOutcome(id);

  static List<String> pullReasonIds() =>
      List<String>.from(CapacityPullReasonIds.all);

  static List<String> decisionOutcomeIds() =>
      List<String>.from(CapacityDecisionOutcomeIds.all);

  static List<String> allVisibleStrings() => [
        corePromise,
        title,
        body,
        pullSectionTitle,
        decisionSectionTitle,
        quickSaveCta,
        recordInsteadCta,
        optionalVoiceNoteCta,
        compactCardTitle,
        compactCardBody,
        entryObservation,
        dashboardSignalAvailable,
        dashboardSignalUnavailable,
        ...pullReasonIds().map(labelForPullReason),
        ...decisionOutcomeIds().map(labelForOutcome),
      ];
}
