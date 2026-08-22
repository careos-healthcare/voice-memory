import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_consent_form.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_disclosure_screen.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_issuer.dart';
import 'package:flutter/material.dart';

/// Runs disclosure then the form, in that order.
///
/// Pushed on the root [Navigator] rather than registered as a route: adding a
/// path would mean editing `lib/router/app_router.dart`, and this flow ships as
/// self-contained widgets until its Settings entry is wired up.
abstract final class CaregiverGrantFlow {
  CaregiverGrantFlow._();

  /// Returns true only when a grant was issued.
  ///
  /// Cancelling at either step returns false, and the form is not reached
  /// unless the disclosure screen was accepted.
  static Future<bool> start(
    BuildContext context, {
    CaregiverGrantIssuer issuer = const UnwiredCaregiverGrantIssuer(),
  }) async {
    if (!V1CapabilityRegistry.caregiverMonitoring) return false;

    final navigator = Navigator.of(context);
    final understood = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const CaregiverDisclosureScreen(),
      ),
    );
    if (understood != true) return false;

    final granted = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CaregiverConsentForm(issuer: issuer),
      ),
    );
    return granted ?? false;
  }
}
