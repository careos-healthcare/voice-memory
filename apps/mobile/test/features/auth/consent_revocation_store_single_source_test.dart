import 'dart:io';

import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/auth/infrastructure/consent_revocation_store.dart'
    as auth_store;
// Deliberately the second import path for the same store. Two byte-identical
// declarations of `ConsentRevocationStore` used to live behind these two URIs,
// each with its own static `_revoked` set, while both persisted whole-set
// snapshots to `consent_revoked_tokens_v1`. A revoke through one was invisible
// to the other and could be erased by it, so access the user had withdrawn came
// back. Keeping both imports here is the regression guard: if the duplicate
// returns, these tests fail.
import 'package:archiveme_mobile/features/consent_audit/consent_revocation_store.dart'
    as consent_audit_store;
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late MobilePrefsStore prefs;

  setUp(() async {
    sandbox = Directory.systemTemp.createTempSync('consent_revocation_store_');
    prefs = await MobilePrefsStore.open('${sandbox.path}/prefs.json');
    await auth_store.ConsentRevocationStore.resetForTest();
    auth_store.ConsentRevocationStore.debugPrefsOverride = prefs;
  });

  tearDown(() async {
    await auth_store.ConsentRevocationStore.resetForTest();
    sandbox.deleteSync(recursive: true);
  });

  group('ConsentRevocationStore has one source of truth', () {
    test('revoke through the auth path is visible on the consent-audit path',
        () async {
      await auth_store.ConsentRevocationStore.ensureLoaded();
      await consent_audit_store.ConsentRevocationStore.ensureLoaded();

      await auth_store.ConsentRevocationStore.revoke('token-shared-1');

      expect(
        consent_audit_store.ConsentRevocationStore.isRevoked('token-shared-1'),
        isTrue,
        reason: 'caregiver/coach verification reads the consent_audit URI, so a '
            'revoke recorded through MultiPartyAccessService must reach it',
      );
    });

    test('revoke through the consent-audit path is visible on the auth path',
        () async {
      await consent_audit_store.ConsentRevocationStore.ensureLoaded();
      await auth_store.ConsentRevocationStore.ensureLoaded();

      await consent_audit_store.ConsentRevocationStore.revoke('token-shared-2');

      expect(
        auth_store.ConsentRevocationStore.isRevoked('token-shared-2'),
        isTrue,
        reason: 'the active-grants list reads the auth URI, so a revoke '
            'recorded by ConsentAuditService must hide the grant there too',
      );
    });

    test('both URIs name the same prefs key', () {
      expect(
        consent_audit_store.ConsentRevocationStore.prefsKey,
        auth_store.ConsentRevocationStore.prefsKey,
      );
    });

    test('a revoke on one path lands in the shared prefs key exactly once',
        () async {
      await auth_store.ConsentRevocationStore.ensureLoaded();
      await auth_store.ConsentRevocationStore.revoke('token-shared-3');
      await consent_audit_store.ConsentRevocationStore.revoke('token-shared-4');

      expect(
        await _storedIds(prefs),
        containsAll(<String>['token-shared-3', 'token-shared-4']),
      );
    });
  });

  group('persistence never shrinks the stored set', () {
    test('a revoke made with a stale in-memory set keeps stored revocations',
        () async {
      // `ensureLoaded` marks itself done without reading anything when no prefs
      // store is available, so the in-memory set is not always a superset of the
      // file. Persisting that set verbatim wiped the file.
      auth_store.ConsentRevocationStore.debugPrefsOverride = null;
      await auth_store.ConsentRevocationStore.ensureLoaded();
      await prefs.writeJsonMap(auth_store.ConsentRevocationStore.prefsKey, {
        'tokenIds': ['token-already-revoked'],
      });
      auth_store.ConsentRevocationStore.debugPrefsOverride = prefs;

      await auth_store.ConsentRevocationStore.revoke('token-newly-revoked');

      expect(
        await _storedIds(prefs),
        containsAll(<String>['token-already-revoked', 'token-newly-revoked']),
        reason: 'writing the in-memory set verbatim would reinstate access the '
            'user had already withdrawn',
      );
    });

    test('a write by another holder of the key survives the next revoke',
        () async {
      await auth_store.ConsentRevocationStore.ensureLoaded();
      await auth_store.ConsentRevocationStore.revoke('token-first');

      await _revokeOutOfBand(prefs, 'token-out-of-band');
      await auth_store.ConsentRevocationStore.revoke('token-second');

      expect(
        await _storedIds(prefs),
        containsAll(<String>[
          'token-first',
          'token-out-of-band',
          'token-second',
        ]),
      );
    });

    test('a stored revoke is loaded back on both paths', () async {
      await prefs.writeJsonMap(auth_store.ConsentRevocationStore.prefsKey, {
        'tokenIds': ['token-round-trip'],
      });

      await consent_audit_store.ConsentRevocationStore.ensureLoaded();

      expect(
        auth_store.ConsentRevocationStore.isRevoked('token-round-trip'),
        isTrue,
      );
      expect(
        consent_audit_store.ConsentRevocationStore.isRevoked(
          'token-round-trip',
        ),
        isTrue,
      );
    });
  });

  group('MultiPartyAccessService revocation reaches verification', () {
    test('a grant revoked in settings is revoked for consent verification',
        () async {
      await prefs.writeJsonMap(MultiPartyAccessService.caregiverTokenKey, {
        'tokenId': 'token-cross-path',
        'caregiverId': 'caregiver-ada',
        'issuedAt': '2026-06-01T12:00:00.000Z',
        'expiresAt': '2027-06-01T12:00:00.000Z',
      });

      final service = MultiPartyAccessService(prefs: prefs);
      final grants = await service.loadActiveGrants(now: DateTime.utc(2026, 7));
      expect(grants.single.role, MultiPartyAccessRole.caregiver);

      await service.revokeGrant(grants.single);

      expect(
        consent_audit_store.ConsentRevocationStore.isRevoked(
          'token-cross-path',
        ),
        isTrue,
        reason: 'ConsentVerificationService.verify consults the consent_audit '
            'URI; if it cannot see this revoke, a caregiver whose access was '
            'revoked in Settings still passes local verification',
      );
      expect(
        await service.loadActiveGrants(now: DateTime.utc(2026, 7)),
        isEmpty,
      );
    });
  });
}

/// Adds a revocation straight to the prefs key, bypassing the store's caches.
///
/// Stands in for any other holder of the key — a second isolate, or the
/// duplicate class this test exists to keep from returning.
Future<void> _revokeOutOfBand(MobilePrefsStore prefs, String tokenId) async {
  final ids = await _storedIds(prefs);
  ids.add(tokenId);
  await prefs.writeJsonMap(auth_store.ConsentRevocationStore.prefsKey, {
    'tokenIds': ids.toList(),
  });
}

Future<Set<String>> _storedIds(MobilePrefsStore prefs) async {
  final raw = await prefs.readJsonMap(
    auth_store.ConsentRevocationStore.prefsKey,
  );
  final ids = raw?['tokenIds'];
  if (ids is! List) return <String>{};
  return ids.whereType<String>().toSet();
}
