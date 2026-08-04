import '../../core/config/v1_feature_flags.dart';

/// Primary focus of the Record tab at a given moment.
enum RecordPrimaryState {
  dueCheck,
  firstRun,
  recordingReady,
  recording,
  postSaveNeedsInputQuality,
  postSaveResult,
  postSaveNextCheck,
  postSaveArchiveProof,
  idle,
}

/// Visibility and ordering for cards on the Record tab.
class RecordStackDecision {
  const RecordStackDecision({
    required this.primaryState,
    this.showDueCheckCard = false,
    this.showArchiveMemoryDemo = false,
    this.showFirstRecordingHandoff = false,
    this.showFirstLoopStartCard = false,
    this.showTrialFirstMomentCard = false,
    this.showStarterPrompts = false,
    this.showInputQualityCoach = false,
    this.showCompletedResult = false,
    this.showResultNextCheck = false,
    this.showRoutineAnchor = false,
    this.showFeedback = false,
    this.showArchiveProofCards = false,
    this.suppressDuplicateRecordCtas = false,
    this.suppressDuplicateUseTomorrowCtas = false,
    this.showFramingTitle = false,
    this.showActivePatternThread = false,
    this.showFirstThreeJourney = false,
    this.showPendingWatchFor = false,
    this.showRetentionStateCard = false,
    this.showCurrentObjectiveCard = false,
    this.showReturnDayJourneyCard = false,
  });

  final RecordPrimaryState primaryState;
  final bool showDueCheckCard;
  final bool showArchiveMemoryDemo;
  final bool showFirstRecordingHandoff;
  final bool showFirstLoopStartCard;
  final bool showTrialFirstMomentCard;
  final bool showStarterPrompts;
  final bool showInputQualityCoach;
  final bool showCompletedResult;
  final bool showResultNextCheck;
  final bool showRoutineAnchor;
  final bool showFeedback;
  final bool showArchiveProofCards;
  final bool suppressDuplicateRecordCtas;
  final bool suppressDuplicateUseTomorrowCtas;
  final bool showFramingTitle;
  final bool showActivePatternThread;
  final bool showFirstThreeJourney;
  final bool showPendingWatchFor;
  final bool showRetentionStateCard;
  final bool showCurrentObjectiveCard;
  final bool showReturnDayJourneyCard;
}

/// Decides Record tab card visibility, order, and duplicate CTA suppression.
RecordStackDecision decideRecordStack({
  required bool hasDueCheck,
  required bool isFirstRun,
  required bool isTrialMode,
  required bool isRecording,
  required bool hasSavedReflection,
  required bool inputQualityNeedsCoach,
  required bool hasCompletedResult,
  required bool hasResultNextCheck,
  required bool hasRoutineAnchorOffer,
  required bool hasArchiveProof,
  int reflectionCount = 0,
  bool entryCountLoaded = true,
  bool archiveMemoryDemoEligible = true,
  bool hasRetentionStateCard = false,
  bool suppressRetentionForFirstRunDemo = false,
  bool suppressRetentionForPostSaveNextCheck = false,
  bool showReturnDayJourney = false,
}) {
  final readyNotPostSave = !hasSavedReflection && !isRecording;
  final hasPatternEvidence = entryCountLoaded && reflectionCount >= 3;
  final showFirstThreeJourneyEligible =
      entryCountLoaded && reflectionCount == 2;

  RecordPrimaryState primaryState;
  if (isRecording) {
    primaryState = RecordPrimaryState.recording;
  } else if (hasDueCheck && readyNotPostSave) {
    primaryState = RecordPrimaryState.dueCheck;
  } else if (hasSavedReflection) {
    if (inputQualityNeedsCoach) {
      primaryState = RecordPrimaryState.postSaveNeedsInputQuality;
    } else if (hasResultNextCheck) {
      primaryState = RecordPrimaryState.postSaveNextCheck;
    } else if (hasCompletedResult) {
      primaryState = RecordPrimaryState.postSaveResult;
    } else if (hasArchiveProof) {
      primaryState = RecordPrimaryState.postSaveArchiveProof;
    } else {
      primaryState = RecordPrimaryState.postSaveResult;
    }
  } else if (isFirstRun && readyNotPostSave) {
    primaryState = RecordPrimaryState.firstRun;
  } else if (readyNotPostSave) {
    primaryState = RecordPrimaryState.recordingReady;
  } else {
    primaryState = RecordPrimaryState.idle;
  }

  // Due check wins over first-run guidance.
  final showDueCheckCard = hasDueCheck && readyNotPostSave;

  final inFirstRunReady = isFirstRun && readyNotPostSave && !showDueCheckCard;

  var showArchiveMemoryDemo = false;
  var showFirstRecordingHandoff = false;
  var showFirstLoopStartCard = false;
  var showTrialFirstMomentCard = false;
  var showStarterPrompts = false;

  if (inFirstRunReady && isTrialMode) {
    showTrialFirstMomentCard = true;
  } else if (readyNotPostSave &&
      !showDueCheckCard &&
      !showReturnDayJourney &&
      hasPatternEvidence) {
    showStarterPrompts = true;
  }

  final hasDominantFirstRunCta =
      showFirstRecordingHandoff ||
      showFirstLoopStartCard ||
      showTrialFirstMomentCard;

  final suppressForReturnDay = showReturnDayJourney;

  final showInputQualityCoach = hasSavedReflection && inputQualityNeedsCoach;

  final showCompletedResult =
      hasSavedReflection && hasCompletedResult && !inputQualityNeedsCoach;

  final showResultNextCheck = showCompletedResult && hasResultNextCheck;

  final showRoutineAnchor = showResultNextCheck && hasRoutineAnchorOffer;

  final showFeedback = showResultNextCheck;

  final showArchiveProofCards =
      hasSavedReflection && hasArchiveProof && !inputQualityNeedsCoach;

  final suppressDuplicateRecordCtas = hasDominantFirstRunCta;

  final suppressDuplicateUseTomorrowCtas = showResultNextCheck;

  // Generic title/subtitle competes with the zero-entry archive promise hero.
  final showFramingTitle =
      readyNotPostSave &&
      !showDueCheckCard &&
      !suppressForReturnDay &&
      !isFirstRun;

  final showActivePatternThread =
      readyNotPostSave &&
      !showDueCheckCard &&
      !hasDominantFirstRunCta &&
      !suppressForReturnDay &&
      hasPatternEvidence;

  final showFirstThreeJourney =
      readyNotPostSave &&
      !showDueCheckCard &&
      !hasDominantFirstRunCta &&
      !suppressForReturnDay &&
      showFirstThreeJourneyEligible;

  final showPendingWatchFor =
      readyNotPostSave &&
      !showDueCheckCard &&
      !hasDominantFirstRunCta &&
      !suppressForReturnDay &&
      hasPatternEvidence;

  final showRetentionStateCard =
      hasRetentionStateCard &&
      !showDueCheckCard &&
      !suppressRetentionForFirstRunDemo &&
      !suppressRetentionForPostSaveNextCheck;

  final showCurrentObjectiveCard =
      V1FeatureFlags.enableWidgets &&
      entryCountLoaded &&
      readyNotPostSave &&
      !showDueCheckCard &&
      !showFirstRecordingHandoff &&
      !showFirstLoopStartCard &&
      !showTrialFirstMomentCard &&
      !showRetentionStateCard &&
      !hasSavedReflection &&
      !suppressForReturnDay;

  return RecordStackDecision(
    primaryState: primaryState,
    showDueCheckCard: showDueCheckCard,
    showArchiveMemoryDemo: showArchiveMemoryDemo,
    showFirstRecordingHandoff: showFirstRecordingHandoff,
    showFirstLoopStartCard: showFirstLoopStartCard,
    showTrialFirstMomentCard: showTrialFirstMomentCard,
    showStarterPrompts: showStarterPrompts,
    showInputQualityCoach: showInputQualityCoach,
    showCompletedResult: showCompletedResult,
    showResultNextCheck: showResultNextCheck,
    showRoutineAnchor: showRoutineAnchor,
    showFeedback: showFeedback,
    showArchiveProofCards: showArchiveProofCards,
    suppressDuplicateRecordCtas: suppressDuplicateRecordCtas,
    suppressDuplicateUseTomorrowCtas: suppressDuplicateUseTomorrowCtas,
    showFramingTitle: showFramingTitle,
    showActivePatternThread: showActivePatternThread,
    showFirstThreeJourney: showFirstThreeJourney,
    showPendingWatchFor: showPendingWatchFor,
    showRetentionStateCard: showRetentionStateCard,
    showCurrentObjectiveCard: showCurrentObjectiveCard,
    showReturnDayJourneyCard: showReturnDayJourney,
  );
}
