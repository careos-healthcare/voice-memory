import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/widgets/privacy/privacy_summary_section.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

/// In-app privacy summary — product-centered, not provider-branded.
///
/// The prominent "What can leave this phone" callout lives on
/// [PrivacySummarySection], which this screen and `/privacy-trust-centre`
/// both render. `/privacy` itself redirects to the trust centre.
///
/// No longer routed. `/privacy` redirects to `/privacy-trust-centre`, which
/// renders [PrivacySummarySection] — the body this screen used to own — so the
/// processing-provider disclosure and the remote-processing consent control
/// stay reachable from the one destination Settings and Account now point at.
///
/// The class survives the redirect because a handful of gates still name it:
/// `V1ProductionAllowlist`, `ProductionRouteLinkGate.scanRoots`,
/// `PrivacyCopyPolicy.consumerPrivacySources`, and the brand-exposure audits
/// all key off `lib/screens/privacy_screen.dart`. Retiring it is a separate
/// change that has to update those together; leaving it as an alias for the
/// section keeps it from drifting away from what actually ships in the
/// meantime, because there is nothing here to drift.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, RemoteProcessingConsentStore? consentStore})
    : _consentStoreOverride = consentStore;

  final RemoteProcessingConsentStore? _consentStoreOverride;

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: PrivacyScreenCopy.screenTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: PrivacySummarySection(consentStore: _consentStoreOverride),
      ),
    );
  }
}
