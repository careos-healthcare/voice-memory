import 'dart:io';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/attest_result.dart';

/// Capture pipeline HTTP with typed [ApiResult] boundaries and cancellation.
class CaptureRepository {
  CaptureRepository({
    required this._api,
    required this._requestScope,
  });

  final CaptureApiClient _api;
  final NetworkRequestScope _requestScope;

  Future<ApiResult<AttestResult>> postCaptureAttest(String deviceId) async {
    final token = _requestScope.register();
    try {
      return await _api.postCaptureAttest(deviceId, cancelToken: token);
    } finally {
      _requestScope.release(token);
    }
  }

  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? _requestScope.register();
    final owned = cancelToken == null;
    try {
      return await _api.postAnalyzeRaw(
        transcript: transcript,
        captureToken: captureToken,
        priorEvidence: priorEvidence,
        idempotencyKey: idempotencyKey,
        cancelToken: token,
      );
    } finally {
      if (owned) {
        _requestScope.release(token);
      }
    }
  }

  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? _requestScope.register();
    final owned = cancelToken == null;
    try {
      return await _api.postTranscribe(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureToken: captureToken,
        idempotencyKey: idempotencyKey,
        cancelToken: token,
      );
    } finally {
      if (owned) {
        _requestScope.release(token);
      }
    }
  }

  Future<ApiResult<VaultRecoveryServerResult>> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
    NetworkCancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? _requestScope.register();
    final owned = cancelToken == null;
    try {
      return await _api.postVaultRecovery(
        vaultFile: vaultFile,
        sessionId: sessionId,
        durationSeconds: durationSeconds,
        captureToken: captureToken,
        idempotencyKey: idempotencyKey,
        recoverySecretKeyBytes: recoverySecretKeyBytes,
        cancelToken: token,
      );
    } finally {
      if (owned) {
        _requestScope.release(token);
      }
    }
  }
}