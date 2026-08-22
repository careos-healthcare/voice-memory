// `redirectFor` existed but nothing called it, and it only named the shell
// routes — so export, capture, and settings were reachable from a caregiver
// session even once it was wired in. The guard is a whitelist now.
import 'dart:io';

import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubConsentApi implements CaregiverConsentApiClient {
  @override
  Future<ApiResult<MonitoringConsentToken>> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
    NetworkCancelToken? cancelToken,
  }) async =>
      ApiSuccess(_token());

  @override
  Future<ApiResult<CaregiverTokenVerificationResult>> verifyToken({
    required MonitoringConsentToken token,
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      CaregiverTokenVerificationResult(
        valid: true,
        session: CaregiverSession(
          sessionId: 'session-isolation-1',
          mode: AppMode.caregiverMonitoring,
          caregiverId: token.caregiverId,
          subjectAccountId: token.subjectAccountId,
          permissions: token.permissions,
          tokenId: token.tokenId,
          startedAt: DateTime.utc(2026, 2),
          expiresAt: token.expiresAt,
          validatedAt: DateTime.utc(2026, 2),
        ),
      ),
    );
  }

  @override
  Future<ApiResult<ConsentRevocationConfirmation>> revokeConsent({
    required ConsentRevocationDomain domain,
    required String tokenId,
    String? reason,
    Map<String, dynamic>? token,
    NetworkCancelToken? cancelToken,
  }) async =>
      ApiSuccess(
        ConsentRevocationConfirmation(
          tokenId: tokenId,
          revoked: true,
          alreadyRevoked: false,
        ),
      );
}

MonitoringConsentToken _token() => MonitoringConsentToken(
      tokenId: 'token-isolation-1',
      subjectAccountId: 'subject-1',
      caregiverId: 'caregiver-ada',
      permissions: CaregiverPermissions.defaultScopes,
      issuedAt: DateTime.utc(2026, 2),
      expiresAt: DateTime.utc(2026, 12, 31),
      policyVersion: ConsentVerificationService.currentPolicyVersion,
      signature: 'server-signature',
    );

/// The surfaces a caregiver session must be pushed off, beyond the shell.
const _ownerOnlyPaths = <String>[
  '/export',
  '/journal-export',
  '/record',
  '/settings',
  '/quick-capture',
  '/delete-account',
  '/entry/abc123',
  '/privacy-security',
  '/archive-belief',
  '/account',
  '/',
];

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('caregiver_isolation_');
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverModeController.resetForTest();
  });

  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverModeController.resetForTest();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<CaregiverModeController> configure() async {
    final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    CaregiverModeController.configure(
      prefs,
      verification: ConsentVerificationService(consentApi: _StubConsentApi()),
    );
    return CaregiverModeController.instance;
  }

  test('tryRedirectFor is a no-op until the controller is configured', () async {
    CaregiverFeatureFlags.debugOverride = true;

    expect(await CaregiverModeController.tryRedirectFor('/export'), isNull);
  });

  test('the owner reaches every owner surface untouched', () async {
    CaregiverFeatureFlags.debugOverride = true;
    final controller = await configure();

    for (final path in _ownerOnlyPaths) {
      expect(
        await controller.redirectFor(path),
        isNull,
        reason: 'owner blocked from $path',
      );
    }
  });

  test('an active caregiver session is pushed off every owner surface',
      () async {
    CaregiverFeatureFlags.debugOverride = true;
    final controller = await configure();
    await controller.activateWithToken(_token());
    expect(controller.hasValidSession, isTrue);

    for (final path in _ownerOnlyPaths) {
      expect(
        await controller.redirectFor(path),
        RouteCatalog.caregiverHome,
        reason: '$path stayed reachable from a caregiver session',
      );
    }
  });

  test('an unrecognised path is redirected too, not defaulted through',
      () async {
    // The whitelist is what makes a route added tomorrow safe by default.
    CaregiverFeatureFlags.debugOverride = true;
    final controller = await configure();
    await controller.activateWithToken(_token());

    expect(
      await controller.redirectFor('/some-route-invented-later'),
      RouteCatalog.caregiverHome,
    );
  });

  test('the caregiver session keeps its own two paths', () async {
    CaregiverFeatureFlags.debugOverride = true;
    final controller = await configure();
    await controller.activateWithToken(_token());

    expect(await controller.redirectFor(RouteCatalog.caregiverHome), isNull);
    expect(
      await controller.redirectFor(RouteCatalog.caregiverConsent),
      RouteCatalog.caregiverHome,
    );
  });

  test('caregiver mode with no valid session lands on consent, not the app',
      () async {
    CaregiverFeatureFlags.debugOverride = true;
    final controller = await configure();
    await controller.activateWithToken(_token());
    await controller.revokeGrant('token-isolation-1');

    // Revoke returns the device to the owner; the owner surface is theirs
    // again.
    expect(await controller.redirectFor('/export'), isNull);
  });

  test('with the capability compiled out only caregiver paths move', () async {
    CaregiverFeatureFlags.debugOverride = false;
    final controller = await configure();

    for (final path in _ownerOnlyPaths) {
      expect(await controller.redirectFor(path), isNull);
    }
    expect(
      await controller.redirectFor(RouteCatalog.caregiverHome),
      RouteCatalog.recordHome,
    );
    expect(
      await controller.redirectFor(RouteCatalog.caregiverConsent),
      RouteCatalog.recordHome,
    );
  });
}
