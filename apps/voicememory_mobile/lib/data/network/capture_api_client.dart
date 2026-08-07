import 'dart:io';

import '../../models/attest_result.dart';
import '../../core/network/api_result.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/live_audio/domain/models/offline_vault_manifest.dart';
import '../../features/proof_admission/proof_admission_models.dart';

/// Capture HTTP boundary — attestation, analysis, transcribe, vault recovery.
abstract interface class CaptureApiClient {
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  });

  Future<ApiResult<VaultRecoveryServerResult>> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
    NetworkCancelToken? cancelToken,
  });
}
