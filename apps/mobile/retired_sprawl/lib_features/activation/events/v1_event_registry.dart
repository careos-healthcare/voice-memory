import 'package:archiveme_mobile/features/activation/activation_tracker.dart' show ActivationTracker;
import 'package:archiveme_mobile/features/activation/events/core_evidence_events.dart';
import 'package:archiveme_mobile/features/activation/events/onboarding_events.dart';
import 'package:archiveme_mobile/features/activation/events/paywall_events.dart';
import 'package:archiveme_mobile/features/activation/events/tier4_funnel_events.dart' show Tier4FunnelEvents;
import 'package:archiveme_mobile/features/onboarding/experiment_h_events.dart';
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show ActivationTracker;

/// v1-scoped event names accepted by [ActivationTracker.trackEvent].
///
/// Funnel and monetization analytics (e.g. [Tier4FunnelEvents]) are Tier 4
/// and must not appear here — they remain in deferred QA export only.
abstract final class V1EventRegistry {
  static const Set<String> allowed = {
    ..._onboarding,
    ..._core,
    ..._paywall,
  };

  static const Set<String> _onboarding = {
    OnboardingEvents.trialAppOpened,
    OnboardingEvents.trialRecordCtaTapped,
    OnboardingEvents.trialMicPermissionRequested,
    OnboardingEvents.trialMicPermissionDenied,
    OnboardingEvents.trialRecordingStarted,
    OnboardingEvents.trialRecordingCancelled,
    OnboardingEvents.trialSaveStarted,
    OnboardingEvents.trialSaveCompleted,
    OnboardingEvents.trialClosedBeforeWatchForAccepted,
    OnboardingEvents.trialExportCopied,
    ExperimentHEvents.onboardingShown,
    ExperimentHEvents.toggleInteracted,
    ExperimentHEvents.firstInsightVerified,
  };

  static const Set<String> _core = {
    CoreEvidenceEvents.firstReflectionSaved,
    CoreEvidenceEvents.secondReflectionSaved,
    CoreEvidenceEvents.thirdReflectionSaved,
    CoreEvidenceEvents.firstPatternShown,
    CoreEvidenceEvents.firstPatternCorrected,
    CoreEvidenceEvents.watchForPromptShown,
    CoreEvidenceEvents.watchForPromptAccepted,
    CoreEvidenceEvents.returnedNextDay,
    CoreEvidenceEvents.usefulnessYes,
    CoreEvidenceEvents.usefulnessSortOf,
    CoreEvidenceEvents.usefulnessNotReally,
    CoreEvidenceEvents.activationFirstRecordCardShown,
    CoreEvidenceEvents.activationFirstRecordCtaTapped,
    CoreEvidenceEvents.activationStarterPromptSelected,
    CoreEvidenceEvents.activationFirstSaveCompleted,
  };

  static const Set<String> _paywall = {
    PaywallEvents.paywallShown,
    PaywallEvents.paywallDismissed,
    PaywallEvents.paywallContinueTapped,
    PaywallEvents.restoreTapped,
    PaywallEvents.annualPlanShown,
    PaywallEvents.monthlyPlanShown,
    PaywallEvents.annualPlanSelected,
    PaywallEvents.monthlyPlanSelected,
    PaywallEvents.proValuePreviewShown,
    PaywallEvents.proValuePreviewUnlockTapped,
    PaywallEvents.proValuePreviewDismissed,
  };
}