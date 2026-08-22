// Every case here is about one thing: a scope the owner *declined* at the
// consent prompt must not be readable. Two of the five choices —
// `thresholdAlerts` and `reviewSummaries` — were signed into the token and then
// never consulted by any gate, so declining them changed nothing.
import 'dart:io';

import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_read_service.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Echoes whatever permissions the token carries into the session, so a test
/// declining a scope produces a session that declines it too.
class _EchoConsentApi implements CaregiverConsentApiClient {
  @override
  Future<ApiResult<MonitoringConsentToken>> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(_token(permissions));
  }

  @override
  Future<ApiResult<CaregiverTokenVerificationResult>> verifyToken({
    required MonitoringConsentToken token,
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      CaregiverTokenVerificationResult(
        valid: true,
        session: CaregiverSession(
          sessionId: 'session-scope-1',
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
  }) async {
    return ApiSuccess(
      ConsentRevocationConfirmation(
        tokenId: tokenId,
        revoked: true,
        alreadyRevoked: false,
      ),
    );
  }
}

MonitoringConsentToken _token(CaregiverPermissions permissions) =>
    MonitoringConsentToken(
      tokenId: 'token-scope-1',
      subjectAccountId: 'subject-1',
      caregiverId: 'caregiver-ada',
      permissions: permissions,
      issuedAt: DateTime.utc(2026, 2),
      expiresAt: DateTime.utc(2026, 12, 31),
      policyVersion: ConsentVerificationService.currentPolicyVersion,
      signature: 'server-signature',
    );

/// Every evidence stream shared, both boolean choices declined.
const _declinedBothBooleans = CaregiverPermissions(
  evidenceStreamIds: [
    CaregiverPermissions.journalStream,
    CaregiverPermissions.proofTrailStream,
    CaregiverPermissions.timelineStream,
  ],
  reviewSummaries: false,
  thresholdAlerts: false,
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('caregiver_scope_');
    CaregiverFeatureFlags.debugOverride = true;
    CaregiverModeController.resetForTest();
  });

  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverModeController.resetForTest();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<CaregiverModeController> activate(
    CaregiverPermissions permissions,
  ) async {
    final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    CaregiverModeController.configure(
      prefs,
      verification: ConsentVerificationService(consentApi: _EchoConsentApi()),
    );
    final controller = CaregiverModeController.instance;
    await controller.activateWithToken(_token(permissions));
    return controller;
  }

  Future<bool> readAllowed(
    CaregiverModeController controller,
    String streamId,
  ) =>
      controller.ensureReadAllowed(
        streamId: streamId,
        auditAction: CaregiverAuditAction.evidenceStreamRead,
      );

  group('permission model', () {
    test('boolean choices resolve through allowsStream, not list membership',
        () {
      // `insight_alerts` and `review_summaries` are never written into
      // `evidenceStreamIds` by any caller, so a membership test alone could
      // only ever deny them — which is why they were exempted instead.
      expect(
        CaregiverPermissions.defaultScopes.evidenceStreamIds,
        isNot(contains(CaregiverPermissions.insightAlertsStream)),
      );
      expect(
        CaregiverPermissions.defaultScopes.evidenceStreamIds,
        isNot(contains(CaregiverPermissions.reviewSummariesStream)),
      );

      expect(
        CaregiverPermissions.defaultScopes
            .allowsStream(CaregiverPermissions.insightAlertsStream),
        isTrue,
      );
      expect(
        _declinedBothBooleans
            .allowsStream(CaregiverPermissions.insightAlertsStream),
        isFalse,
      );
      expect(
        _declinedBothBooleans
            .allowsStream(CaregiverPermissions.reviewSummariesStream),
        isFalse,
      );
    });

    test('a declined boolean outranks the stream id appearing in the list', () {
      // The boolean is the answer the owner gave to the prompt. A token that
      // also lists the pseudo-stream must not be able to talk past it.
      const contradictory = CaregiverPermissions(
        evidenceStreamIds: [
          CaregiverPermissions.journalStream,
          CaregiverPermissions.insightAlertsStream,
          CaregiverPermissions.reviewSummariesStream,
        ],
        reviewSummaries: false,
        thresholdAlerts: false,
      );

      expect(
        contradictory.allowsStream(CaregiverPermissions.insightAlertsStream),
        isFalse,
      );
      expect(
        contradictory.allowsStream(CaregiverPermissions.reviewSummariesStream),
        isFalse,
      );
    });

    test('an unknown stream id denies', () {
      expect(
        CaregiverPermissions.defaultScopes.allowsStream('anything_else'),
        isFalse,
      );
    });
  });

  group('ensureReadAllowed', () {
    // MUST FAIL against the pre-fix controller: the gate carried
    // `&& streamId != CaregiverPermissions.insightAlertsStream`, which let the
    // alerts stream through for every session regardless of the answer given.
    test('a session that declined alerts cannot read the alerts stream',
        () async {
      final controller = await activate(_declinedBothBooleans);

      expect(
        await readAllowed(
          controller,
          CaregiverPermissions.insightAlertsStream,
        ),
        isFalse,
      );

      await controller.auditStore.ensureLoaded();
      expect(
        controller.auditStore.entries.where(
          (e) =>
              e.action == CaregiverAuditAction.accessDenied &&
              e.resourceType == CaregiverPermissions.insightAlertsStream,
        ),
        isNotEmpty,
      );
    });

    // MUST FAIL against the pre-fix controller: nothing anywhere read
    // `permissions.reviewSummaries`, so the choice had no gate to fail.
    test('a session that declined review summaries cannot read them', () async {
      final controller = await activate(_declinedBothBooleans);

      expect(
        await readAllowed(
          controller,
          CaregiverPermissions.reviewSummariesStream,
        ),
        isFalse,
      );
    });

    test('a session that granted both booleans can read both', () async {
      final controller = await activate(CaregiverPermissions.defaultScopes);

      expect(
        await readAllowed(
          controller,
          CaregiverPermissions.insightAlertsStream,
        ),
        isTrue,
      );
      expect(
        await readAllowed(
          controller,
          CaregiverPermissions.reviewSummariesStream,
        ),
        isTrue,
      );
    });

    test('a declined evidence stream still denies', () async {
      const journalOnly = CaregiverPermissions(
        evidenceStreamIds: [CaregiverPermissions.journalStream],
        reviewSummaries: true,
        thresholdAlerts: true,
      );
      final controller = await activate(journalOnly);

      expect(
        await readAllowed(controller, CaregiverPermissions.journalStream),
        isTrue,
      );
      expect(
        await readAllowed(controller, CaregiverPermissions.timelineStream),
        isFalse,
      );
      expect(
        await readAllowed(controller, CaregiverPermissions.proofTrailStream),
        isFalse,
      );
    });
  });

  group('dashboard snapshot', () {
    Future<JournalStore> seededJournal() async {
      final store = await JournalStore.open(
        '${tempDir.path}/entries.json',
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      );
      for (var i = 0; i < 4; i++) {
        await store.save(
          JournalEntry(
            id: 'entry-$i',
            createdAt: DateTime.utc(2026, 1, i + 1),
            transcript: 'Moment $i',
            durationSeconds: 12,
            reflection: const Reflection(
              mood: 'calm',
              emotionalIntensity: 3,
              recurringThemes: ['focus'],
              exactLanguagePattern: 'pattern',
              concreteObservation: 'observation',
              repeatedSignal: 'signal',
            ),
          ),
        );
      }
      return store;
    }

    // MUST FAIL against the pre-fix read service, which called the gate and
    // then discarded the result — the alerts and summaries were attached to the
    // snapshot either way.
    test('declining both booleans withholds alerts and summaries', () async {
      final controller = await activate(_declinedBothBooleans);
      final service = CaregiverReadService(
        journalStore: await seededJournal(),
        modeController: controller,
      );

      final snapshot = await service.loadDashboardSnapshot();

      expect(snapshot, isNotNull);
      expect(snapshot!.evidenceCount, 4, reason: 'journal stream was granted');
      expect(snapshot.priorityAlerts, isEmpty);
      expect(snapshot.timelineSummaries, isEmpty);
    });

    test('granting everything still returns alerts and summaries', () async {
      final controller = await activate(CaregiverPermissions.defaultScopes);
      final service = CaregiverReadService(
        journalStore: await seededJournal(),
        modeController: controller,
      );

      final snapshot = await service.loadDashboardSnapshot();

      expect(snapshot, isNotNull);
      expect(snapshot!.priorityAlerts, isNotEmpty);
      expect(snapshot.timelineSummaries, isNotEmpty);
    });

    test('declining the timeline stream withholds summaries on its own',
        () async {
      const noTimeline = CaregiverPermissions(
        evidenceStreamIds: [
          CaregiverPermissions.journalStream,
          CaregiverPermissions.proofTrailStream,
        ],
        reviewSummaries: true,
        thresholdAlerts: true,
      );
      final controller = await activate(noTimeline);
      final service = CaregiverReadService(
        journalStore: await seededJournal(),
        modeController: controller,
      );

      final snapshot = await service.loadDashboardSnapshot();

      expect(snapshot!.timelineSummaries, isEmpty);
      expect(snapshot.priorityAlerts, isNotEmpty);
    });

    test('no valid session returns nothing at all', () async {
      final controller = await activate(CaregiverPermissions.defaultScopes);
      await controller.switchToSelfReflection();
      final service = CaregiverReadService(
        journalStore: await seededJournal(),
        modeController: controller,
      );

      expect(await service.loadDashboardSnapshot(), isNull);
    });
  });
}
