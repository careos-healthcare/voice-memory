import 'dart:io';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_scope_provider.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/security/account_session_guard.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/features/reflections/local_ai_pipeline.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_facade.dart';
import 'package:archiveme_mobile/storage/capture_token_cache.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

class FixedScopeProvider implements ProofScopeProvider {
  const FixedScopeProvider({
    this.activeOwnerScope = 'test_owner',
    this.activeArchiveScope = 'test_archive',
  });

  @override
  final String activeOwnerScope;

  @override
  final String activeArchiveScope;
}

class AnalyzeCaptureApi implements CaptureApiClient {
  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600),
    );
  }

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      RawModelResponse(
        payload: {
          'reflection': {
            'mood': 'thoughtful',
            'emotionalIntensity': 2,
            'recurringThemes': ['work'],
            'exactLanguagePattern': 'balance',
            'concreteObservation': transcript,
            'repeatedSignal': 'pattern',
          },
        },
        receivedAt: DateTime.utc(2026, 8, 18),
      ),
    );
  }

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postTranscribe');
  }

  @override
  Future<ApiResult<VaultRecoveryServerResult>> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postVaultRecovery');
  }
}

class FakeDeviceIdStore implements DeviceIdStore {
  @override
  Future<String> getDeviceId() async => 'device-test';

  @override
  Future<String> getOrCreate() async => 'device-test';
}

Future<({CapturePipelineFacade facade, JournalStore journal, Directory dir})>
buildCapturePipelineFacade({
  required MobilePrefsStore prefs,
  required JournalStore journal,
  required RemoteProcessingConsentStore consentStore,
  CaptureApiClient? api,
  ApiUsageGuard? usageGuard,
}) async {
  final captureRepository = CaptureRepository(
    api: api ?? AnalyzeCaptureApi(),
    requestScope: NetworkRequestScope(),
  );
  final attest = CaptureAttestService(
    captureRepository: captureRepository,
    deviceIds: FakeDeviceIdStore(),
    tokenCache: CaptureTokenCache()
      ..setToken('capture-token', expiresInSeconds: 3600),
  );
  final dependencies = CapturePipelineDependencies(
    captureRepository: captureRepository,
    attest: attest,
    journalStore: journal,
    consentStore: consentStore,
    usageGuard: usageGuard ?? ApiUsageGuard.shared,
    proofAdmission: CanonicalProofAdmissionService(),
    scopeProvider: const FixedScopeProvider(),
    sessionGuardFactory: AccountSessionGuard.capture,
    localAiPipeline: LocalAiPipeline.heuristic(),
  );
  return (
    facade: CapturePipelineFacade.standard(dependencies),
    journal: journal,
    dir: journal.file.parent,
  );
}
