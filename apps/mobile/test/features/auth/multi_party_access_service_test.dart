import 'dart:io';

import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiPartyAccessService', () {
    late MobilePrefsStore prefs;

    setUp(() async {
      const path = 'test/tmp/multi_party_access/prefs.json';
      final file = File(path);
      if (await file.exists()) {
        await file.writeAsString('{}');
      }
      prefs = await MobilePrefsStore.open(path);
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

    test('recordIssuedGrant lists caregiver and coach by role', () async {
      final service = MultiPartyAccessService(prefs: prefs);
      await service.recordIssuedGrant(
        role: MultiPartyAccessRole.caregiver,
        partyId: 'caregiver-ada',
        tokenId: 'token-issued-care',
        issuedAt: DateTime.utc(2026, 6, 1),
        expiresAt: DateTime.utc(2027, 6, 1),
      );
      await service.recordIssuedGrant(
        role: MultiPartyAccessRole.coach,
        partyId: 'coach-lee',
        tokenId: 'token-issued-coach',
        issuedAt: DateTime.utc(2026, 6, 2),
        expiresAt: DateTime.utc(2027, 6, 2),
      );

      final grants = await service.loadActiveGrants(
        now: DateTime.utc(2026, 7, 1),
      );
      expect(grants.map((g) => g.grantId), containsAll([
        'token-issued-care',
        'token-issued-coach',
      ]));
      expect(
        grants.firstWhere((g) => g.grantId == 'token-issued-care').role,
        MultiPartyAccessRole.caregiver,
      );
      expect(
        grants.firstWhere((g) => g.grantId == 'token-issued-coach').role,
        MultiPartyAccessRole.coach,
      );
      expect(
        grants.firstWhere((g) => g.grantId == 'token-issued-coach').partyId,
        'coach-lee',
      );
    });

    test('recordIssuedGrant rejects observer before any write', () async {
      final service = MultiPartyAccessService(prefs: prefs);
      expect(
        () => service.recordIssuedGrant(
          role: MultiPartyAccessRole.observer,
          partyId: 'observer-1',
          tokenId: 'token-observer',
          issuedAt: DateTime.utc(2026, 6, 1),
          expiresAt: DateTime.utc(2027, 6, 1),
        ),
        throwsUnsupportedError,
      );
      expect(
        await service.loadActiveGrants(now: DateTime.utc(2026, 7, 1)),
        isEmpty,
      );
      expect(await prefs.readJsonMap(MultiPartyAccessService.caregiverAuditKey), isNull);
    });

    test('recordIssuedGrant rejects missing prefs', () async {
      final noPrefs = MultiPartyAccessService();
      expect(
        () => noPrefs.recordIssuedGrant(
          role: MultiPartyAccessRole.caregiver,
          partyId: 'caregiver-ada',
          tokenId: 'token-no-prefs',
          issuedAt: DateTime.utc(2026, 6, 1),
          expiresAt: DateTime.utc(2027, 6, 1),
        ),
        throwsStateError,
      );
    });

    test('loadActiveGrants reads partyId from legacy caregiverId audit rows',
        () async {
      await prefs.writeJsonMap(MultiPartyAccessService.caregiverAuditKey, {
        'entries': [
          {
            'action': 'consent_granted',
            'resourceId': 'token-legacy',
            'timestamp': '2026-06-01T12:00:00.000Z',
            'metadata': {
              'caregiverId': 'caregiver-ada',
              'expiresAt': '2027-06-01T12:00:00.000Z',
            },
          },
        ],
      });

      final service = MultiPartyAccessService(prefs: prefs);
      final grants = await service.loadActiveGrants(
        now: DateTime.utc(2026, 7, 1),
      );
      expect(grants, hasLength(1));
      expect(grants.first.grantId, 'token-legacy');
      expect(grants.first.partyId, 'caregiver-ada');
      expect(grants.first.role, MultiPartyAccessRole.caregiver);
    });
  });
}
