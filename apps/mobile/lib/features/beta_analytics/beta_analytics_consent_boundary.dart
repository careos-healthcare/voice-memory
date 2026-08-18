import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_tracker.dart';
import 'package:archiveme_mobile/features/proof_admission/archive_correction.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:flutter/foundation.dart';

/// Consent and remote-processing audit boundary for beta analytics.
///
/// **Boundary:** [consent_decision] records [RemoteProcessingPurpose] choices
/// only. Product analytics (this registry) is not part of remote processing
/// consent. Declining transcription/reflection:
/// - does not block local beta analytics writes;
/// - does not itself perform any remote network call;
/// - only gates capture pipeline remote stages.
abstract final class BetaAnalyticsConsentBoundary {
  BetaAnalyticsConsentBoundary._();

  static Future<void> recordConsentDecision({
    required RemoteProcessingPurpose purpose,
    required String decision,
  }) async {
    await BetaAnalyticsTracker.track(
      'consent_decision',
      parameters: {
        'purpose': purpose.storageKey,
        'decision': decision,
      },
    );
  }

  /// Called when onboarding grants or declines all remote purposes.
  static Future<void> recordOnboardingConsent({required bool granted}) async {
    final decision = granted ? 'grant' : 'decline';
    for (final purpose in RemoteProcessingPurposeStorage.onboardingGrant) {
      await recordConsentDecision(purpose: purpose, decision: decision);
    }
  }

  /// Audit hook immediately before remote network I/O.
  ///
  /// Emits [prohibited_remote_attempt_after_decline] when consent is not
  /// granted — this should never happen in correct code paths.
  static Future<void> auditRemoteAttempt({
    required RemoteProcessingPurpose purpose,
    required bool permitted,
  }) async {
    if (permitted) return;
    await BetaAnalyticsTracker.track(
      'prohibited_remote_attempt_after_decline',
      parameters: {'purpose': purpose.storageKey},
    );
  }

  static String reviewOutcomeFor(ArchiveCorrectionChoice choice) {
    return switch (choice) {
      ArchiveCorrectionChoice.exactlyRight => 'fits',
      ArchiveCorrectionChoice.partlyRight => 'partly_fits',
      ArchiveCorrectionChoice.wrong ||
      ArchiveCorrectionChoice.wrongWording => 'not_for_me',
      ArchiveCorrectionChoice.wrongEvidence => 'corrected',
      ArchiveCorrectionChoice.ignoreForever => 'hidden',
    };
  }
}
