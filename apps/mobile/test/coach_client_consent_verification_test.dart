import 'package:archiveme_mobile/features/coach/client_consent_verification_service.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('issues and verifies coach client consent token', () async {
    const secret = 'coach-test-signing-secret';
    final service = ClientConsentVerificationService(
      signingSecretOverride: secret,
    );

    const permissions = CoachSharingPermissions.defaults;
    const affirmationHash = 'abc123';

    final token = await service.issueToken(
      relationshipId: 'rel-1',
      clientAccountId: 'client-1',
      coachId: 'coach-1',
      permissions: permissions,
      clientAffirmationHash: affirmationHash,
    );

    final result = await service.verify(token);
    expect(result.valid, isTrue);
    expect(result.session, isNotNull);
    expect(result.session!.coachId, 'coach-1');
    expect(result.session!.relationshipId, 'rel-1');
  });

  test('rejects tampered coach consent signature', () async {
    const secret = 'coach-test-signing-secret';
    final service = ClientConsentVerificationService(
      signingSecretOverride: secret,
    );

    final token = await service.issueToken(
      relationshipId: 'rel-1',
      clientAccountId: 'client-1',
      coachId: 'coach-1',
      permissions: CoachSharingPermissions.defaults,
      clientAffirmationHash: 'hash',
    );

    final tampered = CoachConsentToken(
      tokenId: token.tokenId,
      relationshipId: token.relationshipId,
      clientAccountId: token.clientAccountId,
      coachId: token.coachId,
      permissions: token.permissions,
      issuedAt: token.issuedAt,
      expiresAt: token.expiresAt,
      policyVersion: token.policyVersion,
      clientAffirmationHash: token.clientAffirmationHash,
      signature: 'deadbeef',
    );

    final result = await service.verify(tampered);
    expect(result.valid, isFalse);
    expect(result.reason, isNotNull);
  });
}