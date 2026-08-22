import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_proof_analyzer.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';

/// Shared attestation, consent, usage-guard, and analyze-with-auth-retry logic.
class CapturePipelineMiddleware {
  CapturePipelineMiddleware(
    this._deps,
    this._analyzer, {
    PipelineStageEmitter stageEmitter = noopPipelineStage,
  }) : _stageEmitter = stageEmitter;

  final CapturePipelineDependencies _deps;
  final CaptureProofAnalyzer _analyzer;
  final PipelineStageEmitter _stageEmitter;

  Future<bool> isPurposeGranted(RemoteProcessingPurpose purpose) =>
      _analyzer.isPurposeGranted(purpose);

  Future<String> ensureCaptureToken({bool forceRefresh = false}) =>
      _deps.attest.ensureCaptureToken(forceRefresh: forceRefresh);

  void clearCaptureToken() => _deps.attest.clearToken();

  ApiUsageCheckResult checkUsage({
    required String scopeKey,
    required ApiUsageOperation operation,
  }) =>
      _deps.usageGuard.checkAttempt(
        scopeKey: scopeKey,
        operation: operation,
      );

  String idempotencyKey({
    required String scopeKey,
    required ApiUsageOperation operation,
  }) =>
      _deps.usageGuard.idempotencyKey(
        scopeKey: scopeKey,
        operation: operation,
      );

  void recordUsageAttempt({
    required String scopeKey,
    required ApiUsageOperation operation,
    required bool success,
  }) {
    _deps.usageGuard.recordAttempt(
      scopeKey: scopeKey,
      operation: operation,
      success: success,
    );
  }

  void logApiGuardBlocked({
    required String operation,
    required String reason,
  }) {
    RecordPipelineLog.apiGuardBlocked(operation: operation, reason: reason);
  }

  /// Runs analyze + proof admission with optional attestation and auth retry.
  ///
  /// Voice capture attests before transcription; pass [attestFirst: false] when
  /// continuing to analyze an already-transcribed recording.
  Future<VerifiedProof> analyzeWithAuthRetry({
    required String transcript,
    required String scopeKey,
    required String entryId,
    required ProofSourceType sourceType,
    
    bool attestFirst = true,
  }) async {
    if (attestFirst) {
      _stageEmitter(PipelineStage.attesting);
    }
    var token = await ensureCaptureToken();

    _stageEmitter(PipelineStage.analyzing);
    final analyzeCheck = checkUsage(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.analyze,
    );
    if (!analyzeCheck.allowed) {
      final reason = analyzeCheck.reason ?? 'blocked';
      logApiGuardBlocked(operation: 'analyze', reason: reason);
      throw AnalyzeBlockedException(reason);
    }

    final analyzeIdempotency = idempotencyKey(
      scopeKey: scopeKey,
      operation: ApiUsageOperation.analyze,
    );
    try {
      final proof = await _analyzer.postAndAdmit(
        transcript: transcript,
        captureToken: token,
        idempotencyKey: analyzeIdempotency,
        entryId: entryId,
        sourceType: sourceType,
      );
      recordUsageAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
        success: true,
      );
      return proof;
    } on AuthRequiredException {
      token = await ensureCaptureToken(forceRefresh: true);
      final proof = await _analyzer.postAndAdmit(
        transcript: transcript,
        captureToken: token,
        idempotencyKey: analyzeIdempotency,
        entryId: entryId,
        sourceType: sourceType,
      );
      recordUsageAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
        success: true,
      );
      return proof;
    } catch (e, stackTrace) {
      recordUsageAttempt(
        scopeKey: scopeKey,
        operation: ApiUsageOperation.analyze,
        success: false,
      );
      rethrow;
    }
  }
}

/// Thrown when [ApiUsageGuard] blocks an analyze attempt.
class AnalyzeBlockedException implements Exception {
  AnalyzeBlockedException(this.reason);

  final String reason;

  @override
  String toString() => reason;
}