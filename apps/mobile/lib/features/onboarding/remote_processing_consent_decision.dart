import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';

/// Persists the first-run remote-processing decision.
///
/// Extracted from `OnboardingScreen` so the part that matters — that a grant
/// also clears the on-device-only switch, and a decline changes nothing — can be
/// tested without driving the first-run widget steps through `AppServices`.
///
/// Only reachable from onboarding screen 2's two buttons. Nothing calls it on
/// launch, on upgrade, on /record, or on account switch, which is what keeps
/// existing installs unmigrated: a customer who granted consent under the old
/// behaviour keeps whatever on-device-only value they have until they choose
/// otherwise.
abstract final class OnboardingRemoteProcessingDecision {
  OnboardingRemoteProcessingDecision._();

  static Future<void> record({
    required bool allow,
    required RemoteProcessingConsentStore consentStore,
  }) async {
    if (!allow) {
      await consentStore.withdraw();
      return;
    }

    await consentStore.grant();
    // Consent alone permits nothing — `RemoteProcessingConsentGate` requires
    // both — so without this the customer who just agreed would get no remote
    // processing. First-run does not lecture this; Privacy settings do.
    await OnDeviceProcessingStore.clearForGrantedRemoteConsent();
  }
}
