import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_model.dart';
import 'package:archiveme_mobile/features/acquisition/acquisition_intent_model.dart';
import 'package:archiveme_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:archiveme_mobile/features/quality/first_insight_specificity_store.dart';
import 'package:archiveme_mobile/features/quality/interpretation_quality_signal_model.dart';

/// Primary bottleneck in the early ArchiveMe loop — trial/debug only.
enum RetentionBottleneckV2 {
  noFirstMoment,
  weakInterpretation,
  reminderNotAccepted,
  reminderAcceptedNoReturn,
  noSecondMoment,
  noThirdMoment,
  acquisitionMismatch,
  audienceNotActivated,
  insightTooGeneric,
  wrongAngle,
  weakWedgeFit,
  loopNotActivated,
  loopUnsupportedByRecording,
  loopReadRejected,
  loopNoSecondEvidence,
  loopHealthy,
  healthyEarlyLoop,
  unknown,
}

extension RetentionBottleneckV2Ids on RetentionBottleneckV2 {
  String get id => name;

  /// Trial-control label — internal wording, not consumer UI.
  String get trialLabel {
    switch (this) {
      case RetentionBottleneckV2.weakInterpretation:
        return 'Likely bottleneck: weak interpretation';
      case RetentionBottleneckV2.reminderNotAccepted:
      case RetentionBottleneckV2.reminderAcceptedNoReturn:
        return 'Likely bottleneck: reminder timing';
      case RetentionBottleneckV2.acquisitionMismatch:
      case RetentionBottleneckV2.noFirstMoment:
        return 'Likely bottleneck: acquisition fit';
      case RetentionBottleneckV2.audienceNotActivated:
        return 'Likely bottleneck: audience not activated';
      case RetentionBottleneckV2.insightTooGeneric:
        return 'Likely bottleneck: insight too generic';
      case RetentionBottleneckV2.wrongAngle:
        return 'Likely bottleneck: wrong angle';
      case RetentionBottleneckV2.weakWedgeFit:
        return 'Likely bottleneck: weak wedge fit';
      case RetentionBottleneckV2.loopNotActivated:
        return 'Likely bottleneck: loop not activated';
      case RetentionBottleneckV2.loopUnsupportedByRecording:
        return 'Likely bottleneck: loop unsupported by recording';
      case RetentionBottleneckV2.loopReadRejected:
        return 'Likely bottleneck: loop read rejected';
      case RetentionBottleneckV2.loopNoSecondEvidence:
        return 'Likely bottleneck: loop no second evidence';
      case RetentionBottleneckV2.loopHealthy:
        return 'Likely bottleneck: loop healthy';
      case RetentionBottleneckV2.healthyEarlyLoop:
        return 'Likely bottleneck: healthy early loop';
      case RetentionBottleneckV2.noSecondMoment:
        return 'Likely bottleneck: no second moment';
      case RetentionBottleneckV2.noThirdMoment:
        return 'Likely bottleneck: no third moment';
      case RetentionBottleneckV2.unknown:
        return 'Likely bottleneck: unknown';
    }
  }
}

/// Inputs for retention bottleneck analysis.
class RetentionDiagnosisV2Input {
  const RetentionDiagnosisV2Input({
    required this.firstMomentRecorded,
    required this.secondMomentRecorded,
    required this.thirdMomentRecorded,
    required this.interpretationSignals,
    required this.reminderPrePromptShown,
    required this.reminderPrePromptAccepted,
    required this.reminderPrePromptDismissed,
    required this.reminderReturnCount,
    required this.onboardingIntent,
    required this.journeyEvidenceCount,
    required this.reviewConfirmed,
    this.audienceWedge,
    this.firstInsightSpecificityRating,
    this.wedgeInterpretationMatched = false,
    this.firstPromptUsed = false,
    this.lastReadTemplateId,
    this.entryTextSupportsWedge = false,
    this.loopModeSelected,
    this.loopFirstPromptUsed = false,
    this.loopMatchedFirstRecording = false,
    this.loopReadAccepted = false,
    this.loopUnsupportedRecording = false,
    this.loopReadRejected = false,
    this.loopCompleted = false,
    this.loopReviewViewed = false,
    this.loopReviewConfirmed = false,
    this.loopReviewCorrected = false,
    this.loopPaywallTeaserTapped = false,
    this.acquisitionCohortId,
  });

  final bool firstMomentRecorded;
  final bool secondMomentRecorded;
  final bool thirdMomentRecorded;
  final List<InterpretationQualitySignal> interpretationSignals;
  final bool reminderPrePromptShown;
  final bool reminderPrePromptAccepted;
  final int reminderPrePromptDismissed;
  final int reminderReturnCount;
  final AcquisitionIntent? onboardingIntent;
  final int journeyEvidenceCount;
  final bool reviewConfirmed;
  final AudienceWedge? audienceWedge;
  final FirstInsightSpecificityRating? firstInsightSpecificityRating;
  final bool wedgeInterpretationMatched;
  final bool firstPromptUsed;
  final String? lastReadTemplateId;
  final bool entryTextSupportsWedge;
  final String? loopModeSelected;
  final bool loopFirstPromptUsed;
  final bool loopMatchedFirstRecording;
  final bool loopReadAccepted;
  final bool loopUnsupportedRecording;
  final bool loopReadRejected;
  final bool loopCompleted;
  final bool loopReviewViewed;
  final bool loopReviewConfirmed;
  final bool loopReviewCorrected;
  final bool loopPaywallTeaserTapped;
  final AcquisitionCohortId? acquisitionCohortId;
}

class RetentionDiagnosisV2Result {
  const RetentionDiagnosisV2Result({
    required this.bottleneck,
    required this.summary,
  });

  final RetentionBottleneckV2 bottleneck;
  final String summary;
}

/// Diagnoses which retention problem is most likely.
class RetentionDiagnosisV2Engine {
  const RetentionDiagnosisV2Engine();

  RetentionDiagnosisV2Result diagnose(RetentionDiagnosisV2Input input) {
    final cohortResult = _cohortWedgeDiagnosis(input);
    if (cohortResult != null) return cohortResult;

    final loopSelected =
        input.loopModeSelected != null && input.loopModeSelected != 'not_sure';

    if (loopSelected && input.loopReviewConfirmed) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopHealthy,
        summary: 'Strong product signal: loop review reached and confirmed.',
      );
    }

    if (loopSelected && input.loopReviewCorrected) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.healthyEarlyLoop,
        summary: 'Interpretation mismatch but engaged: loop review corrected.',
      );
    }

    if (loopSelected &&
        input.loopReviewViewed &&
        !input.loopReviewConfirmed &&
        !input.loopReviewCorrected) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.weakInterpretation,
        summary: 'Payoff weak: loop review viewed without confirm or correct.',
      );
    }

    if (loopSelected && input.loopPaywallTeaserTapped) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.healthyEarlyLoop,
        summary: 'Monetization signal: loop paywall teaser tapped.',
      );
    }

    if (input.loopCompleted || (loopSelected && input.reviewConfirmed)) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopHealthy,
        summary: 'User completed loop review path.',
      );
    }

    if (loopSelected && !input.firstMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopNotActivated,
        summary: 'Loop selected but no first recording saved.',
      );
    }

    if (loopSelected && input.loopUnsupportedRecording) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopUnsupportedByRecording,
        summary: 'First recording did not support active loop.',
      );
    }

    if (loopSelected && input.loopReadRejected) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopReadRejected,
        summary: 'Capacity read rejected by user.',
      );
    }

    if (loopSelected && input.loopReadAccepted && !input.secondMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopNoSecondEvidence,
        summary: 'Loop read accepted but second evidence not recorded.',
      );
    }

    if (input.reviewConfirmed || input.journeyEvidenceCount >= 3) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.healthyEarlyLoop,
        summary: 'User reached signal review or full evidence path.',
      );
    }

    final wedgeSelected =
        input.audienceWedge != null &&
        input.audienceWedge != AudienceWedge.notSureYet;

    if (wedgeSelected && !input.firstMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.audienceNotActivated,
        summary: 'Audience wedge selected but no first moment recorded.',
      );
    }

    if (input.firstInsightSpecificityRating ==
        FirstInsightSpecificityRating.tooGeneric) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.insightTooGeneric,
        summary: 'User said first read felt too generic.',
      );
    }

    if (input.firstInsightSpecificityRating ==
        FirstInsightSpecificityRating.wrongAngle) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.wrongAngle,
        summary: 'User said first read took the wrong angle.',
      );
    }

    if (!input.firstMomentRecorded) {
      if (input.onboardingIntent != null &&
          input.onboardingIntent != AcquisitionIntent.notSureYet) {
        return const RetentionDiagnosisV2Result(
          bottleneck: RetentionBottleneckV2.acquisitionMismatch,
          summary: 'Intent selected but no first moment recorded.',
        );
      }
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.noFirstMoment,
        summary: 'No first moment recorded yet.',
      );
    }

    if (wedgeSelected &&
        input.entryTextSupportsWedge &&
        input.lastReadTemplateId != null &&
        !input.audienceWedge!.templateIds.contains(input.lastReadTemplateId)) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.weakWedgeFit,
        summary: 'Wedge selected but top read did not match wedge templates.',
      );
    }

    if (input.firstInsightSpecificityRating ==
            FirstInsightSpecificityRating.yesSpecific &&
        input.secondMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.healthyEarlyLoop,
        summary: 'User accepted a specific read and returned to record again.',
      );
    }

    if (input.wedgeInterpretationMatched && input.secondMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.healthyEarlyLoop,
        summary: 'Wedge-aligned read accepted and user returned.',
      );
    }

    final weakReads = input.interpretationSignals
        .where((s) => s.qualityLabel == InterpretationQualityLabel.weak)
        .length;
    final strongReads = input.interpretationSignals
        .where((s) => s.qualityLabel == InterpretationQualityLabel.strong)
        .length;
    final ignoredReads = input.interpretationSignals
        .where((s) => s.userAction == ReadUserAction.ignored)
        .length;

    if (weakReads > 0 ||
        (ignoredReads > 0 && strongReads == 0 && !input.secondMomentRecorded)) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.weakInterpretation,
        summary: 'Reads rejected or ignored without return.',
      );
    }

    if (strongReads > 0 &&
        input.reminderPrePromptDismissed > 0 &&
        !input.secondMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.reminderNotAccepted,
        summary: 'Useful read accepted but reminder dismissed and no return.',
      );
    }

    if (input.reminderPrePromptAccepted &&
        input.reminderReturnCount == 0 &&
        !input.secondMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.reminderAcceptedNoReturn,
        summary: 'Reminder accepted but user did not return to record.',
      );
    }

    if (input.secondMomentRecorded && !input.thirdMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.noThirdMoment,
        summary: 'Two moments recorded; third evidence not yet saved.',
      );
    }

    if (input.firstMomentRecorded && !input.secondMomentRecorded) {
      return const RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.noSecondMoment,
        summary: 'First moment saved; second not yet recorded.',
      );
    }

    return const RetentionDiagnosisV2Result(
      bottleneck: RetentionBottleneckV2.unknown,
      summary: 'Not enough signal to classify bottleneck.',
    );
  }

  RetentionDiagnosisV2Result? _cohortWedgeDiagnosis(
    RetentionDiagnosisV2Input input,
  ) {
    final cohort = input.acquisitionCohortId;
    if (cohort != AcquisitionCohortId.capacityYesDirect &&
        cohort != AcquisitionCohortId.proveEnoughDirect) {
      return null;
    }

    final wedge = cohort == AcquisitionCohortId.capacityYesDirect
        ? 'capacity'
        : 'prove';

    if (input.loopReviewConfirmed) {
      return RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopHealthy,
        summary: '$wedge wedge working: loop review confirmed.',
      );
    }

    if (!input.firstMomentRecorded) {
      return RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopNotActivated,
        summary: '$wedge promise failed to activate: no first moment.',
      );
    }

    if (!input.loopReadAccepted) {
      return RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.weakInterpretation,
        summary: '$wedge insight mismatch: first moment without accept.',
      );
    }

    if (!input.secondMomentRecorded) {
      return RetentionDiagnosisV2Result(
        bottleneck: RetentionBottleneckV2.loopNoSecondEvidence,
        summary: '$wedge retention gap: accepted read but no second moment.',
      );
    }

    return null;
  }
}