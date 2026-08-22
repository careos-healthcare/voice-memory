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
  });

  final ConsentVerificationService? verificationService;

  final CaregiverGrantContactStore? contactStore;

  @override
  Future<CaregiverGrantOutcome> issue(CaregiverGrantRequest request) async {
    final store = contactStore ?? await CaregiverGrantContactStore.open();
    await store.save(
      caregiverId: request.caregiverId,
      contact: request.contact,
    );

    final subjectAccountId =
        AppServices.instance.auth.currentSession?.userId ?? 'local_guest';

    try {
      final token =
          await (verificationService ?? ConsentVerificationService()).issueToken(
        subjectAccountId: subjectAccountId,
        caregiverId: request.caregiverId,
        permissions: CaregiverPermissions.defaultScopes,
      );
      return CaregiverGrantGranted(
        tokenId: token.tokenId,
        expiresAt: token.expiresAt,
      );
      // issueToken signals "backend not configured" by throwing StateError, so
      // a consent screen has to surface it as a failed grant rather than crash.
      // ignore: avoid_catching_errors
    } on StateError catch (error) {
      await store.remove(request.caregiverId);
      return CaregiverGrantFailed(error.message);
    }
  }
}
