import '../acquisition/acquisition_cohort_model.dart';
import '../acquisition/acquisition_intent_model.dart';
import '../acquisition/audience_wedge_model.dart';
import '../quality/first_insight_specificity_store.dart';
import 'retention_diagnosis_v2_engine.dart';

/// Retention instrumentation rollup for trial export.
class RetentionDiagnosisSnapshot {
  const RetentionDiagnosisSnapshot({
    this.onboardingIntent,
    this.onboardingIntentSelectedCount = 0,
    this.readUsefulTappedCount = 0,
    this.readNotQuiteTappedCount = 0,
    this.interpretationStrongCount = 0,
    this.interpretationWeakCount = 0,
    this.reminderTimingOfferedCount = 0,
    this.reminderTimingSelectedCount = 0,
    this.reminderPrePromptDismissedCount = 0,
    this.reminderReturnRecordedCount = 0,
    this.secondMomentRecordedCount = 0,
    this.thirdMomentRecordedCount = 0,
    this.retentionBottleneck = RetentionBottleneckV2.unknown,
    this.retentionBottleneckLabel = 'Likely bottleneck: unknown',
    this.retentionBottleneckSummary = '',
    this.audienceWedgeSelected,
    this.firstInsightSpecificityRating,
    this.wedgeInterpretationMatched = false,
    this.firstPromptUsed = false,
    this.loopModeSelected,
    this.loopFirstPromptUsed = false,
    this.loopMatchedFirstRecording = false,
    this.loopReadAccepted = false,
    this.loopUnsupportedRecording = false,
    this.loopCompleted = false,
    this.loopReviewViewed = false,
    this.loopReviewConfirmed = false,
    this.loopReviewCorrected = false,
    this.loopReviewKeptWatching = false,
    this.loopPaywallTeaserShown = false,
    this.loopPaywallTeaserTapped = false,
    this.proveEnoughSelected = false,
    this.proveEnoughFirstPromptUsed = false,
    this.proveEnoughMatchedFirstRecording = false,
    this.proveEnoughReadAccepted = false,
    this.proveEnoughUnsupportedRecording = false,
    this.proveEnoughCompleted = false,
    this.acquisitionCohortId,
    this.acquisitionCohortPromiseShown = '',
    this.acquisitionCohortFirstMomentRecorded = false,
    this.acquisitionCohortSecondMomentRecorded = false,
    this.acquisitionCohortThirdMomentRecorded = false,
    this.acquisitionCohortReviewReached = false,
    this.acquisitionCohortReviewConfirmed = false,
    this.acquisitionCohortPaywallTeaserTapped = false,
  });

  final AcquisitionIntent? onboardingIntent;
  final int onboardingIntentSelectedCount;
  final int readUsefulTappedCount;
  final int readNotQuiteTappedCount;
  final int interpretationStrongCount;
  final int interpretationWeakCount;
  final int reminderTimingOfferedCount;
  final int reminderTimingSelectedCount;
  final int reminderPrePromptDismissedCount;
  final int reminderReturnRecordedCount;
  final int secondMomentRecordedCount;
  final int thirdMomentRecordedCount;
  final RetentionBottleneckV2 retentionBottleneck;
  final String retentionBottleneckLabel;
  final String retentionBottleneckSummary;
  final AudienceWedge? audienceWedgeSelected;
  final FirstInsightSpecificityRating? firstInsightSpecificityRating;
  final bool wedgeInterpretationMatched;
  final bool firstPromptUsed;
  final String? loopModeSelected;
  final bool loopFirstPromptUsed;
  final bool loopMatchedFirstRecording;
  final bool loopReadAccepted;
  final bool loopUnsupportedRecording;
  final bool loopCompleted;
  final bool loopReviewViewed;
  final bool loopReviewConfirmed;
  final bool loopReviewCorrected;
  final bool loopReviewKeptWatching;
  final bool loopPaywallTeaserShown;
  final bool loopPaywallTeaserTapped;
  final bool proveEnoughSelected;
  final bool proveEnoughFirstPromptUsed;
  final bool proveEnoughMatchedFirstRecording;
  final bool proveEnoughReadAccepted;
  final bool proveEnoughUnsupportedRecording;
  final bool proveEnoughCompleted;
  final AcquisitionCohortId? acquisitionCohortId;
  final String acquisitionCohortPromiseShown;
  final bool acquisitionCohortFirstMomentRecorded;
  final bool acquisitionCohortSecondMomentRecorded;
  final bool acquisitionCohortThirdMomentRecorded;
  final bool acquisitionCohortReviewReached;
  final bool acquisitionCohortReviewConfirmed;
  final bool acquisitionCohortPaywallTeaserTapped;

  Map<String, dynamic> toJson() => {
    if (onboardingIntent != null) 'onboardingIntent': onboardingIntent!.id,
    'onboardingIntentSelectedCount': onboardingIntentSelectedCount,
    'readUsefulTappedCount': readUsefulTappedCount,
    'readNotQuiteTappedCount': readNotQuiteTappedCount,
    'interpretationStrongCount': interpretationStrongCount,
    'interpretationWeakCount': interpretationWeakCount,
    'reminderTimingOfferedCount': reminderTimingOfferedCount,
    'reminderTimingSelectedCount': reminderTimingSelectedCount,
    'reminderPrePromptDismissedCount': reminderPrePromptDismissedCount,
    'reminderReturnRecordedCount': reminderReturnRecordedCount,
    'secondMomentRecordedCount': secondMomentRecordedCount,
    'thirdMomentRecordedCount': thirdMomentRecordedCount,
    'retentionBottleneck': retentionBottleneck.id,
    'retentionBottleneckLabel': retentionBottleneckLabel,
    'retentionBottleneckSummary': retentionBottleneckSummary,
    if (audienceWedgeSelected != null)
      'audienceWedgeSelected': audienceWedgeSelected!.id,
    if (firstInsightSpecificityRating != null)
      'firstInsightSpecificityRating': firstInsightSpecificityRating!.id,
    'wedgeInterpretationMatched': wedgeInterpretationMatched,
    'firstPromptUsed': firstPromptUsed,
    if (loopModeSelected != null) 'loopModeSelected': loopModeSelected,
    'loopFirstPromptUsed': loopFirstPromptUsed,
    'loopMatchedFirstRecording': loopMatchedFirstRecording,
    'loopReadAccepted': loopReadAccepted,
    'loopUnsupportedRecording': loopUnsupportedRecording,
    'loopCompleted': loopCompleted,
    'loopReviewViewed': loopReviewViewed,
    'loopReviewConfirmed': loopReviewConfirmed,
    'loopReviewCorrected': loopReviewCorrected,
    'loopReviewKeptWatching': loopReviewKeptWatching,
    'loopPaywallTeaserShown': loopPaywallTeaserShown,
    'loopPaywallTeaserTapped': loopPaywallTeaserTapped,
    'proveEnoughSelected': proveEnoughSelected,
    'proveEnoughFirstPromptUsed': proveEnoughFirstPromptUsed,
    'proveEnoughMatchedFirstRecording': proveEnoughMatchedFirstRecording,
    'proveEnoughReadAccepted': proveEnoughReadAccepted,
    'proveEnoughUnsupportedRecording': proveEnoughUnsupportedRecording,
    'proveEnoughCompleted': proveEnoughCompleted,
    if (acquisitionCohortId != null)
      'acquisitionCohortId': acquisitionCohortId!.id,
    'acquisitionCohortPromiseShown': acquisitionCohortPromiseShown,
    'acquisitionCohortFirstMomentRecorded':
        acquisitionCohortFirstMomentRecorded,
    'acquisitionCohortSecondMomentRecorded':
        acquisitionCohortSecondMomentRecorded,
    'acquisitionCohortThirdMomentRecorded':
        acquisitionCohortThirdMomentRecorded,
    'acquisitionCohortReviewReached': acquisitionCohortReviewReached,
    'acquisitionCohortReviewConfirmed': acquisitionCohortReviewConfirmed,
    'acquisitionCohortPaywallTeaserTapped':
        acquisitionCohortPaywallTeaserTapped,
  };
}
