import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_contact_store.dart';

/// One grant, as the form collects it.
///
/// [caregiverId] is an opaque local id, not the email. The consent-issue route
/// (`apps/api/app/api/coach/consent/issue/route.ts:88`) takes a `caregiverId`
/// string and signs it into the token, and that token is neither revocable nor
/// scoped to an account, so putting a third party's address in it would put
/// their email into an artefact this app cannot withdraw.
class CaregiverGrantRequest {
  const CaregiverGrantRequest({
    required this.caregiverId,
    required this.contact,
    this.shareJournal = false,
    this.shareProofTrail = false,
    this.shareTimeline = false,
    this.shareReviewSummaries = false,
  });

  final String caregiverId;
  final CaregiverGrantContact contact;

  // Plain booleans, not a CaregiverPermissions field: this file deliberately
  // does not import lib/features/caregiver/ (see the class comment on
  // CaregiverGrantIssuer below), so the actual permissions model gets built
  // from these in CaregiverGrantConsentAdapter, the one file allowed to cross
  // that boundary.
  final bool shareJournal;
  final bool shareProofTrail;
  final bool shareTimeline;
  final bool shareReviewSummaries;
}

/// Result of trying to issue a grant.
sealed class CaregiverGrantOutcome {
  const CaregiverGrantOutcome();
}

class CaregiverGrantGranted extends CaregiverGrantOutcome {
  const CaregiverGrantGranted({required this.tokenId, required this.expiresAt});

  final String tokenId;
  final DateTime expiresAt;
}

class CaregiverGrantFailed extends CaregiverGrantOutcome {
  const CaregiverGrantFailed(this.reason);

  final String reason;
}

/// The seam between this flow and whatever issues a consent token.
///
/// Kept abstract so the flow does not compile against
/// `lib/features/caregiver/`, which is analyzer-excluded and under active
/// rewrite. `CaregiverGrantConsentAdapter` is the real implementation.
// A seam with two implementations, not a stand-in for a function: the flow
// picks between the wired adapter and [UnwiredCaregiverGrantIssuer].
// ignore: one_member_abstracts
abstract interface class CaregiverGrantIssuer {
  Future<CaregiverGrantOutcome> issue(CaregiverGrantRequest request);
}

/// Refuses every grant, with a reason.
///
/// The default while the flow is behind an off feature flag: the form can be
/// exercised end to end without a token being minted by accident.
class UnwiredCaregiverGrantIssuer implements CaregiverGrantIssuer {
  const UnwiredCaregiverGrantIssuer();

  @override
  Future<CaregiverGrantOutcome> issue(CaregiverGrantRequest request) async {
    return const CaregiverGrantFailed('Caregiver access is not turned on.');
  }
}
