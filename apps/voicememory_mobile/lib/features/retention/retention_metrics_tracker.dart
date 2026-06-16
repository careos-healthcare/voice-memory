import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';

/// Local counters for onboarding + retention funnel (trial-safe).
class RetentionMetricsStore {
  RetentionMetricsStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'retentionMetrics';

  static RetentionMetricsStore instance() =>
      RetentionMetricsStore(AppServices.instance.prefs);

  Future<Map<String, int>> _load() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null) return {};
    return raw.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
  }

  Future<void> increment(String event) async {
    final data = await _load();
    data[event] = (data[event] ?? 0) + 1;
    await _prefs.writeMap(_key, data);
  }

  Future<int> count(String event) async {
    final data = await _load();
    return data[event] ?? 0;
  }
}

/// Retention/onboarding analytics — separate from core activation funnel.
abstract class RetentionMetricsTracker {
  RetentionMetricsTracker._();

  static const onboardingStarted = 'onboardingStarted';
  static const onboardingCompleted = 'onboardingCompleted';
  static const firstRecordCtaTapped = 'firstRecordCtaTapped';
  static const reminderPrePromptShown = 'reminderPrePromptShown';
  static const reminderAllowedTapped = 'reminderAllowedTapped';
  static const reminderDismissedTapped = 'reminderDismissedTapped';
  static const nextEvidenceReminderScheduled = 'nextEvidenceReminderScheduled';
  static const returnDayJourneyCardShown = 'returnDayJourneyCardShown';
  static const returnDayJourneyCtaTapped = 'returnDayJourneyCtaTapped';

  static const onboardingIntentSelected = 'onboardingIntentSelected';
  static const readUsefulTapped = 'readUsefulTapped';
  static const readNotQuiteTapped = 'readNotQuiteTapped';
  static const interpretationStrongCount = 'interpretationStrongCount';
  static const interpretationWeakCount = 'interpretationWeakCount';
  static const reminderTimingOffered = 'reminderTimingOffered';
  static const reminderTimingSelected = 'reminderTimingSelected';
  static const reminderPrePromptDismissed = 'reminderPrePromptDismissed';
  static const reminderReturnRecorded = 'reminderReturnRecorded';
  static const secondMomentRecorded = 'secondMomentRecorded';
  static const thirdMomentRecorded = 'thirdMomentRecorded';
  static const retentionDiagnosisComputed = 'retentionDiagnosisComputed';
  static const audienceWedgeSelected = 'audienceWedgeSelected';
  static const firstInsightYesSpecific = 'firstInsightYesSpecific';
  static const firstInsightTooGeneric = 'firstInsightTooGeneric';
  static const firstInsightWrongAngle = 'firstInsightWrongAngle';
  static const firstPromptUsed = 'firstPromptUsed';
  static const loopModeSelected = 'loopModeSelected';
  static const loopFirstPromptUsed = 'loopFirstPromptUsed';
  static const loopFirstRecordingSaved = 'loopFirstRecordingSaved';
  static const loopReadAccepted = 'loopReadAccepted';
  static const loopReadRejected = 'loopReadRejected';
  static const loopUnsupportedRecording = 'loopUnsupportedRecording';
  static const loopCompleted = 'loopCompleted';
  static const loopReviewViewed = 'loopReviewViewed';
  static const loopReviewConfirmed = 'loopReviewConfirmed';
  static const loopReviewCorrected = 'loopReviewCorrected';
  static const loopReviewKeptWatching = 'loopReviewKeptWatching';
  static const loopPaywallTeaserShown = 'loopPaywallTeaserShown';
  static const loopPaywallTeaserTapped = 'loopPaywallTeaserTapped';

  static const cohortAssigned = 'cohortAssigned';
  static const cohortStartScreenViewed = 'cohortStartScreenViewed';
  static const cohortStartCtaTapped = 'cohortStartCtaTapped';
  static const cohortLoopSelected = 'cohortLoopSelected';
  static const cohortFirstMomentRecorded = 'cohortFirstMomentRecorded';
  static const cohortSecondMomentRecorded = 'cohortSecondMomentRecorded';
  static const cohortThirdMomentRecorded = 'cohortThirdMomentRecorded';
  static const cohortReviewReached = 'cohortReviewReached';
  static const cohortReviewConfirmed = 'cohortReviewConfirmed';
  static const cohortPaywallTeaserTapped = 'cohortPaywallTeaserTapped';

  static const capacityInviteCopied = 'capacityInviteCopied';
  static const proveInviteCopied = 'proveInviteCopied';
  static const genericInviteCopied = 'genericInviteCopied';

  static const proveDefaultShown = 'proveDefaultShown';
  static const proveDefaultStarted = 'proveDefaultStarted';
  static const proveFirstMomentRecorded = 'proveFirstMomentRecorded';
  static const proveReadAccepted = 'proveReadAccepted';
  static const proveSecondMomentRecorded = 'proveSecondMomentRecorded';
  static const proveReviewConfirmed = 'proveReviewConfirmed';
  static const provePaywallTeaserTapped = 'provePaywallTeaserTapped';

  static const enoughnessScoreShown = 'enoughnessScoreShown';
  static const choicePressureShown = 'choicePressureShown';
  static const stopCostPromptShown = 'stopCostPromptShown';
  static const stopCostPromptAnswered = 'stopCostPromptAnswered';

  static const nextEvidenceMissionShown = 'nextEvidenceMissionShown';
  static const nextEvidenceMissionTapped = 'nextEvidenceMissionTapped';
  static const contradictionCaptureShown = 'contradictionCaptureShown';
  static const contradictionSaved = 'contradictionSaved';

  static const monthlyReviewPreviewShown = 'monthlyReviewPreviewShown';
  static const monthlyReviewOpened = 'monthlyReviewOpened';
  static const monthlyReviewPaywallTapped = 'monthlyReviewPaywallTapped';
  static const loopDirectionShown = 'loopDirectionShown';

  static Future<void> track(String event) async {
    if (!AppServices.isInitialized) return;
    await RetentionMetricsStore.instance().increment(event);
  }
}
