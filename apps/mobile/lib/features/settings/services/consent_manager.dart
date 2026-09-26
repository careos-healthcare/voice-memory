import 'package:archiveme_mobile/features/onboarding/cloud_consent_modal.dart';
import 'package:flutter/material.dart';

/// The one place that may turn Cloud AI processing on.
class ConsentManager {
  const ConsentManager();

  /// Shows the plain-language Cloud AI consent modal.
  ///
  /// Returns true only when the person accepts. Cancel and dismiss stay off.
  Future<bool> requestCloudAiConsent(BuildContext context) {
    return CloudConsentModal.ask(context);
  }
}
