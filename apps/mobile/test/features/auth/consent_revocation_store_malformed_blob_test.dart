import 'dart:io';

import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A caregiver token that is otherwise perfectly valid.
MonitoringConsentToken _token() => MonitoringConsentToken(
  tokenId: 'token-live',
  subjectAccountId: 'subject-1',
  caregiverId: 'caregiver-1',
  permissions: CaregiverPermissions.defaultScopes,
  issuedAt: DateTime.utc(2026),
  expiresAt: DateTime.utc(2026, 12, 31),
  policyVersion: ConsentVerificationService.currentPolicyVersion,
  signature: 'server-signature',
);

void main() {
  late Directory sandbox;
  late MobilePrefsStore prefs;

  setUp(() async {
    sandbox = Directory.systemTemp.createTempSync('consent_revocation_broken_');
    prefs = await MobilePrefsStore.open('${sandbox.path}/prefs.json');
    await ConsentRevocationStore.resetForTest();
    ConsentRevocationStore.debugPrefsOverride = prefs;
  });

  tearDown(() async {
    await ConsentRevocationStore.resetForTest();
    sandbox.deleteSync(recursive: true);
  });

  group('an unreadable revocation blob denies instead of emptying', () {
    // The cost of getting this backwards is asymmetric. Denying on a store we
    // cannot read costs a caregiver access the user did grant, and they can
    // grant it again. Allowing on a store we cannot read costs a caregiver the
    // user *revoked* silently getting back in, which is the failure this whole
    // feature exists to prevent.

    test('a tokenIds field of the wrong type denies every token', () async {
      await prefs.writeJsonMap(ConsentRevocationStore.prefsKey, {
        'tokenIds': 'not-a-list',
      });

      await ConsentRevocationStore.ensureLoaded();

      expect(
        ConsentRevocationStore.isRevoked('any-token-at-all'),
        isTrue,
        reason: 'a tokenIds field we cannot parse used to read as an empty '
            'revocation list, which reinstates every revoked grant',
      );
    });

    test('a tokenIds list holding a non-string denies every token', () async {
      await prefs.writeJsonMap(ConsentRevocationStore.prefsKey, {
        'tokenIds': ['token-revoked-earlier', 42],
      });

      await ConsentRevocationStore.ensureLoaded();

      expect(ConsentRevocationStore.isRevoked('token-revoked-earlier'), isTrue);
      expect(
        ConsentRevocationStore.isRevoked('some-other-token'),
        isTrue,
        reason: 'one unreadable entry means the list is not trustworthy; '
            'dropping it silently loses a revocation',
      );
    });

    test('a blob that is not a map at all denies every token', () async {
      await prefs.writeString(ConsentRevocationStore.prefsKey, 'corrupted');

      await ConsentRevocationStore.ensureLoaded();

      expect(ConsentRevocationStore.isRevoked('any-token-at-all'), isTrue);
    });

    test('an absent blob stays legitimately empty', () async {
      await ConsentRevocationStore.ensureLoaded();

      expect(
        ConsentRevocationStore.isRevoked('any-token-at-all'),
        isFalse,
        reason: 'a first run has revoked nothing; denying here would break '
            'every grant on every fresh install',
      );
    });

    test('a blob with no tokenIds field stays legitimately empty', () async {
      // What `resetForTest` writes, and what a store that has never recorded a
      // revocation looks like.
      await prefs.writeJsonMap(ConsentRevocationStore.prefsKey, {});

      await ConsentRevocationStore.ensureLoaded();

      expect(ConsentRevocationStore.isRevoked('any-token-at-all'), isFalse);
    });

    test('a well-formed blob still discriminates', () async {
      await prefs.writeJsonMap(ConsentRevocationStore.prefsKey, {
        'tokenIds': ['token-revoked'],
      });

      await ConsentRevocationStore.ensureLoaded();

      expect(ConsentRevocationStore.isRevoked('token-revoked'), isTrue);
      expect(ConsentRevocationStore.isRevoked('token-still-live'), isFalse);
    });
  });

  group('the synchronous callers inherit the deny', () {
    test('consent verification rejects a live token', () async {
      await prefs.writeJsonMap(ConsentRevocationStore.prefsKey, {
        'tokenIds': 'not-a-list',
      });

      final result = await ConsentVerificationService().verify(
        _token(),
        now: DateTime.utc(2026, 2),
      );

      expect(result.valid, isFalse);
      expect(result.reason, 'Consent token revoked');
    });

    test('the active grants list hides grants it cannot vouch for', () async {
      await prefs.writeJsonMap(MultiPartyAccessService.caregiverTokenKey, {
        'tokenId': 'token-live',
        'caregiverId': 'caregiver-ada',
        'issuedAt': '2026-06-01T12:00:00.000Z',
        'expiresAt': '2027-06-01T12:00:00.000Z',
      });
      await prefs.writeJsonMap(ConsentRevocationStore.prefsKey, {
        'tokenIds': 'not-a-list',
      });

      final grants = await MultiPartyAccessService(
        prefs: prefs,
      ).loadActiveGrants(now: DateTime.utc(2026, 7));

      expect(grants, isEmpty);
    });
  });
}
