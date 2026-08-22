import 'package:archiveme_mobile/features/acquisition/acquisition_cohort_coordinator.dart';
import 'package:archiveme_mobile/features/acquisition/acquisition_intent_store.dart';
import 'package:archiveme_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:archiveme_mobile/features/acquisition/audience_wedge_store.dart';
import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_engine.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/quality/first_insight_specificity_store.dart';
import 'package:archiveme_mobile/features/quality/interpretation_quality_store.dart';
import 'package:archiveme_mobile/features/reminders/reminder_timing_store.dart';
import 'package:archiveme_mobile/features/retention/retention_diagnosis_snapshot.dart';
import 'package:archiveme_mobile/features/retention/retention_diagnosis_v2_engine.dart';
import 'package:archiveme_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:archiveme_mobile/features/retention/return_reason_capture_store.dart';
import 'package:archiveme_mobile/features/signal_journey/signal_journey_coordinator.dart';
import 'package:archiveme_mobile/features/signal_review/signal_review_coordinator.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Builds retention diagnosis snapshot for trial/debug surfaces.
abstract class RetentionDiagnosisV2Coordinator {
  RetentionDiagnosisV2Coordinator._();

  static Future<RetentionDiagnosisSnapshot> build() async {
    if (!AppServices.isInitialized) {
      return const RetentionDiagnosisSnapshot();
    }

    final prefs = AppServices.instance.prefs;
    final metrics = RetentionMetricsStore.instance();
    final timing = ReminderTimingStore.instance();
    final cohort = await AcquisitionCohortCoordinator.load();
    await AcquisitionCohortCoordinator.syncMilestonesFromAppState();
    final syncedCohort = await AcquisitionCohortCoordinator.load();
    final intent = await AcquisitionIntentStore.instance().load();
    final wedge = await AudienceWedgeStore.instance().load();
    final loop = await LoopModeCoordinator.loadActive();
    const loopEngine = LoopModeEngine();
    final specificity = await FirstInsightSpecificityStore.latest();
    final firstPromptUsed =
        await FirstInsightSpecificityStore.firstPromptUsed();
    final journey = await SignalJourneyCoordinator.loadActive();
    final confirmedReviews =
        await SignalReviewCoordinator.confirmedReviewCount();
    final activationEvents = await ActivationEventsStore(prefs).read();
    final interpretationSignals = await InterpretationQualityStore.loadAll();
    final lastReadId = interpretationSignals.isNotEmpty
        ? interpretationSignals.last.readId
        : null;

    final entries = await AppServices.instance.journal.loadAll();
    final lastText = entries.isNotEmpty ? entries.last.transcript : '';
    final entrySupportsWedge =
        wedge != null &&
        wedge != AudienceWedge.notSureYet &&
        wedge.textSupports(lastText);

    var wedgeMatched = false;
    if (specificity == FirstInsightSpecificityRating.yesSpecific) {
      wedgeMatched = true;
    } else if (wedge != null &&
        lastReadId != null &&
        wedge.templateIds.contains(lastReadId)) {
      wedgeMatched = true;
    }

    final input = RetentionDiagnosisV2Input(
      firstMomentRecorded: activationEvents.firstReflectionSaved > 0,
      secondMomentRecorded: activationEvents.secondReflectionSaved > 0,
      thirdMomentRecorded: activationEvents.thirdReflectionSaved > 0,
      interpretationSignals: interpretationSignals,
      reminderPrePromptShown:
          (await metrics.count(
            RetentionMetricsTracker.reminderPrePromptShown,
          )) >
          0,
      reminderPrePromptAccepted:
          (await metrics.count(RetentionMetricsTracker.reminderAllowedTapped)) >
          0,
      reminderPrePromptDismissed: await metrics.count(
        RetentionMetricsTracker.reminderPrePromptDismissed,
      ),
      reminderReturnCount: await ReturnReasonCaptureStore.instance()
          .reminderReturnCount(),
      onboardingIntent: intent,
      journeyEvidenceCount: journey?.evidenceCount ?? 0,
      reviewConfirmed: confirmedReviews > 0,
      audienceWedge: wedge,
      firstInsightSpecificityRating: specificity,
      wedgeInterpretationMatched: wedgeMatched,
      firstPromptUsed: firstPromptUsed,
      lastReadTemplateId: lastReadId,
      entryTextSupportsWedge: entrySupportsWedge,
      loopModeSelected: loop?.id,
      loopFirstPromptUsed: loop?.firstPromptUsed ?? false,
      loopMatchedFirstRecording:
          loop != null &&
          lastReadId != null &&
          loopEngine.readMatchesLoop(loop, lastReadId),
      loopReadAccepted: loop?.readAccepted ?? false,
      loopUnsupportedRecording: loop?.unsupportedRecording ?? false,
      loopReadRejected:
          (await metrics.count(RetentionMetricsTracker.loopReadRejected)) > 0,
      loopCompleted: loop?.completed ?? false,
      loopReviewViewed:
          (await metrics.count(RetentionMetricsTracker.loopReviewViewed)) > 0,
      loopReviewConfirmed:
          (await metrics.count(RetentionMetricsTracker.loopReviewConfirmed)) >
          0,
      loopReviewCorrected:
          (await metrics.count(RetentionMetricsTracker.loopReviewCorrected)) >
          0,
      loopPaywallTeaserTapped:
          (await metrics.count(
            RetentionMetricsTracker.loopPaywallTeaserTapped,
          )) >
          0,
      acquisitionCohortId: syncedCohort?.cohortId ?? cohort?.cohortId,
    );

    const engine = RetentionDiagnosisV2Engine();
    final result = engine.diagnose(input);
    ActivationTracker.trackRetentionDiagnosisComputed();

    final timingOffer = await timing.loadLatest();

    return RetentionDiagnosisSnapshot(
      onboardingIntent: intent,
      onboardingIntentSelectedCount: await metrics.count(
        RetentionMetricsTracker.onboardingIntentSelected,
      ),
      readUsefulTappedCount: await metrics.count(
        RetentionMetricsTracker.readUsefulTapped,
      ),
      readNotQuiteTappedCount: await metrics.count(
        RetentionMetricsTracker.readNotQuiteTapped,
      ),
      interpretationStrongCount: await InterpretationQualityStore.strongCount(),
      interpretationWeakCount: await InterpretationQualityStore.weakCount(),
      reminderTimingOfferedCount: await metrics.count(
        RetentionMetricsTracker.reminderTimingOffered,
      ),
      reminderTimingSelectedCount: timingOffer?.selectedVariant != null
          ? await metrics.count(RetentionMetricsTracker.reminderTimingSelected)
          : 0,
      reminderPrePromptDismissedCount: await metrics.count(
        RetentionMetricsTracker.reminderPrePromptDismissed,
      ),
      reminderReturnRecordedCount: await metrics.count(
        RetentionMetricsTracker.reminderReturnRecorded,
      ),
      secondMomentRecordedCount: await metrics.count(
        RetentionMetricsTracker.secondMomentRecorded,
      ),
      thirdMomentRecordedCount: await metrics.count(
        RetentionMetricsTracker.thirdMomentRecorded,
      ),
      retentionBottleneck: result.bottleneck,
      retentionBottleneckLabel: result.bottleneck.trialLabel,
      retentionBottleneckSummary: result.summary,
      audienceWedgeSelected: wedge,
      firstInsightSpecificityRating: specificity,
      wedgeInterpretationMatched: wedgeMatched,
      firstPromptUsed: firstPromptUsed,
      loopModeSelected: loop?.id,
      loopFirstPromptUsed: loop?.firstPromptUsed ?? false,
      loopMatchedFirstRecording:
          loop != null &&
          lastReadId != null &&
          loopEngine.readMatchesLoop(loop, lastReadId),
      loopReadAccepted: loop?.readAccepted ?? false,
      loopUnsupportedRecording: loop?.unsupportedRecording ?? false,
      loopCompleted: loop?.completed ?? false,
      loopReviewViewed:
          (await metrics.count(RetentionMetricsTracker.loopReviewViewed)) > 0,
      loopReviewConfirmed:
          (await metrics.count(RetentionMetricsTracker.loopReviewConfirmed)) >
          0,
      loopReviewCorrected:
          (await metrics.count(RetentionMetricsTracker.loopReviewCorrected)) >
          0,
      loopReviewKeptWatching:
          (await metrics.count(
            RetentionMetricsTracker.loopReviewKeptWatching,
          )) >
          0,
      loopPaywallTeaserShown:
          (await metrics.count(
            RetentionMetricsTracker.loopPaywallTeaserShown,
          )) >
          0,
      loopPaywallTeaserTapped:
          (await metrics.count(
            RetentionMetricsTracker.loopPaywallTeaserTapped,
          )) >
          0,
      proveEnoughSelected: loop?.id == LoopModeIds.proveEnough,
      proveEnoughFirstPromptUsed:
          loop?.id == LoopModeIds.proveEnough &&
          (loop?.firstPromptUsed ?? false),
      proveEnoughMatchedFirstRecording:
          loop?.id == LoopModeIds.proveEnough &&
          lastReadId != null &&
          loopEngine.readMatchesLoop(loop!, lastReadId),
      proveEnoughReadAccepted:
          loop?.id == LoopModeIds.proveEnough && (loop?.readAccepted ?? false),
      proveEnoughUnsupportedRecording:
          loop?.id == LoopModeIds.proveEnough &&
          (loop?.unsupportedRecording ?? false),
      proveEnoughCompleted:
          loop?.id == LoopModeIds.proveEnough && (loop?.completed ?? false),
      acquisitionCohortId: syncedCohort?.cohortId ?? cohort?.cohortId,
      acquisitionCohortPromiseShown: syncedCohort?.promiseShown ?? '',
      acquisitionCohortFirstMomentRecorded:
          syncedCohort?.firstMomentRecorded ?? false,
      acquisitionCohortSecondMomentRecorded:
          syncedCohort?.secondMomentRecorded ?? false,
      acquisitionCohortThirdMomentRecorded:
          syncedCohort?.thirdMomentRecorded ?? false,
      acquisitionCohortReviewReached: syncedCohort?.loopReviewReached ?? false,
      acquisitionCohortReviewConfirmed:
          syncedCohort?.loopReviewConfirmed ?? false,
      acquisitionCohortPaywallTeaserTapped:
          syncedCohort?.paywallTeaserTapped ?? false,
    );
  }
}