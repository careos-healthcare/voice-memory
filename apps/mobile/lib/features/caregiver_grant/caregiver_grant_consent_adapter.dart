import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_contact_store.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_issuer.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Issues a grant through the existing server consent path.
///
/// Isolated in its own file on purpose: it is the only thing in
/// `caregiver_grant/` that imports `lib/features/caregiver/`, which another
/// change is rewriting. If that import breaks, the flow, its copy, and its
/// tests keep building.
///
/// The contact details are written to [CaregiverGrantContactStore] before the
/// token request goes out, and only the opaque caregiver id is put on the wire.
class CaregiverGrantConsentAdapter implements CaregiverGrantIssuer {
  const CaregiverGrantConsentAdapter({
    this.verificationService,
    this.contactStore,
    this.multiPartyAccessService,
  });
  final ConsentVerificationService? verificationService;
  final CaregiverGrantContactStore? contactStore;
  final MultiPartyAccessService? multiPartyAccessService;
  @override
  Future<CaregiverGrantOutcome> issue(CaregiverGrantRequest request) async {
    final store = contactStore ?? await CaregiverGrantContactStore.open();
    await store.save(
      caregiverId: request.caregiverId,
      contact: request.contact,
    );
    final subjectAccountId =
        AppServices.instance.auth.currentSession?.userId ?? 'local_guest';
    final MonitoringConsentToken token;
    try {
      token =
          await (verificationService ?? ConsentVerificationService()).issueToken(
        subjectAccountId: subjectAccountId,
        caregiverId: request.caregiverId,
        permissions: CaregiverPermissions(
          evidenceStreamIds: [
            if (request.shareJournal) CaregiverPermissions.journalStream,
            if (request.shareProofTrail) CaregiverPermissions.proofTrailStream,
            if (request.shareTimeline) CaregiverPermissions.timelineStream,
          ],
          reviewSummaries: request.shareReviewSummaries,
          thresholdAlerts: false,
        ),
      );
      // issueToken signals "backend not configured" by throwing StateError, so
      // a consent screen has to surface it as a failed grant rather than crash.
      // ignore: avoid_catching_errors
    } on StateError catch (error) {
      await store.remove(request.caregiverId);
      return CaregiverGrantFailed(error.message);
    }

    // The server grant already succeeded at this point — record it locally so
    // MultiPartyAccessService.loadActiveGrants() can find it. Deliberately
    // outside the try/catch above: recordIssuedGrant has its own unrelated
    // StateError case (prefs unavailable), and catching that here would
    // misreport a real, already-issued grant as failed.
    await (multiPartyAccessService ?? MultiPartyAccessService()).recordIssuedGrant(
      role: MultiPartyAccessRole.caregiver,
      partyId: request.contact.name,
      tokenId: token.tokenId,
      issuedAt: token.issuedAt,
      expiresAt: token.expiresAt,
    );

    return CaregiverGrantGranted(
      tokenId: token.tokenId,
      expiresAt: token.expiresAt,
    );
  }
}
