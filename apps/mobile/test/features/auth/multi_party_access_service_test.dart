import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiPartyAccessService', () {
    late MobilePrefsStore prefs;

    setUp(() async {
      prefs = await MobilePrefsStore.open(
        'test/tmp/multi_party_access/prefs.json',
      );
      await ConsentRevocationStore.resetForTest();
    });

    test('loads caregiver grant from stored token prefs', () async {
      await prefs.writeJsonMap(MultiPartyAccessService.caregiverTokenKey, {
        'tokenId': 'token-care-1',
        'caregiverId': 'caregiver-ada',
        'subjectAccountId': 'subject-1',
        'issuedAt': '2026-06-01T12:00:00.000Z',
        'expiresAt': '2027-06-01T12:00:00.000Z',
        'policyVersion': 1,
        'signature': 'hmac-server-signature',
        'permissions': {
          'evidenceStreamIds': ['journal'],
          'reviewSummaries': true,
          'thresholdAlerts': false,
        },
      });

      final service = MultiPartyAccessService(prefs: prefs);
      final grants = await service.loadActiveGrants(
        now: DateTime.utc(2026, 7, 1),
      );

      expect(grants.length, 1);
      expect(grants.first.grantId, 'token-care-1');
      expect(grants.first.partyId, 'caregiver-ada');
      expect(grants.first.role, MultiPartyAccessRole.caregiver);
    });

    test('revokeGrant persists revocation and clears matching token', () async {
      await prefs.writeJsonMap(MultiPartyAccessService.caregiverTokenKey, {
        'tokenId': 'token-care-2',
        'caregiverId': 'caregiver-ada',
        'issuedAt': '2026-06-01T12:00:00.000Z',
        'expiresAt': '2027-06-01T12:00:00.000Z',
      });

      final service = MultiPartyAccessService(prefs: prefs);
      final grants = await service.loadActiveGrants(
        now: DateTime.utc(2026, 7, 1),
      );
      await service.revokeGrant(grants.first);

      final after = await service.loadActiveGrants(
        now: DateTime.utc(2026, 7, 1),
      );
      expect(after, isEmpty);

      final cleared = await prefs.readJsonMap(
        MultiPartyAccessService.caregiverTokenKey,
      );
      expect(cleared, isEmpty);
    });
  });
}
