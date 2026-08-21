import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/api/models/live_audio_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_headers.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/multipart_file_part.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/voice_capture/analysis/analysis_log.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_capture_diagnostics.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_diag_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/ai_prompt_boundary.dart';
import 'package:archiveme_mobile/security/private_log.dart';
import 'package:archiveme_mobile/security/user_content_safety.dart';
import 'package:http_parser/http_parser.dart';

class HttpCaptureApiClient implements CaptureApiClient {
  HttpCaptureApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.captureAttest.path,
      body: {'deviceId': deviceId},
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeEnvelope<CaptureAttestResponseDto, AttestResult>(
          response,
          parseData: CaptureAttestResponseDto.fromJson,
          toDomain: _mapAttestResult,
          missingDataMessage: 'Attest failed',
        );
      },
      onFailure: ApiFailureResult.new,
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
    final prepared = AiPromptBoundary.prepareUserReflectionForApi(transcript);
    PrivateLog.apiPayload(
      tag: 'HttpCaptureApiClient:',
      operation: 'analyze',
      preparedText: prepared,
    );

    final headers = <String, String>{
      ApiHeaders.captureToken: captureToken,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        ApiHeaders.idempotencyKey: idempotencyKey,
    };

    AnalysisLog.request(url: VoiceMemoryApiRoutes.analyze.path);
    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.analyze.path,
      headers: headers,
      body: {'transcript': prepared, 'priorEvidence': priorEvidence},
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        AnalysisLog.response(
          status: response.statusCode,
          contentType: response.headers['content-type'] ?? 'unknown',
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          String? code;
          var reason = 'Request failed (${response.statusCode})';
          try {
            final body = jsonDecode(response.body) as Map<String, dynamic>;
            reason = body['error'] as String? ?? reason;
            code = body['code'] as String?;
          } catch (e, stackTrace) {
            AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
            }
          AnalysisLog.failed(
            status: response.statusCode,
            code: code,
            reason: reason,
          );
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeEnvelope<Map<String, dynamic>, RawModelResponse>(
          response,
          parseData: (json) => json,
          toDomain: (body) {
            final reflection = body['reflection'] as Map<String, dynamic>?;
            if (reflection == null) {
              AnalysisLog.failed(
                status: response.statusCode,
                reason: 'No reflection in response',
              );
              throw const FormatException('No reflection in response');
            }
            final parsed = Reflection.fromJson(reflection);
            AnalysisLog.success(
              observationLength: parsed.concreteObservation.trim().length,
            );
            return RawModelResponse(
              payload: body,
              receivedAt: DateTime.now().toUtc(),
              providerResponseId:
                  response.headers['x-request-id'] ??
                  response.headers['request-id'],
            );
          },
          missingDataMessage: 'No reflection in response',
        );
      },
      onFailure: (failure) {
        AnalysisLog.failed(reason: failure.message);
        return ApiFailureResult(failure);
      },
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
    TranscriptionLog.request(url: VoiceMemoryApiRoutes.transcribe.path);
    final fileName = _audioFilename(audioFile.path);
    final uploadBytes = audioFile.existsSync() ? audioFile.lengthSync() : 0;
    final contentTypeString = AudioCaptureDiagnostics.uploadContentTypeForPath(
      audioFile.path,
    );
    final contentType = MediaType.parse(contentTypeString);
    AudioDiagLog.upload(
      fileName: fileName,
      contentType: contentTypeString,
      bytes: uploadBytes,
    );

    final headers = <String, String>{
      ApiHeaders.captureToken: captureToken,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        ApiHeaders.idempotencyKey: idempotencyKey,
    };

    final responseResult = await _transport.postMultipart(
      VoiceMemoryApiRoutes.transcribe.path,
      fields: {'durationSeconds': durationSeconds.toString()},
      files: [
        MultipartFilePart.fromPath(
          field: 'audio',
          path: audioFile.path,
          filename: fileName,
          contentType: contentType,
        ),
      ],
      headers: headers,
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        TranscriptionLog.response(
          status: response.statusCode,
          contentType: response.headers['content-type'] ?? 'unknown',
        );
        return _transport.decodeEnvelope(
          response,
          parseData: TranscribeResponseDto.fromJson,
          toDomain: (dto) {
            final transcript = dto.transcript.trim();
            if (transcript.isEmpty) {
              throw const FormatException('No transcript returned');
            }
            final sanitized = UserContentSafety.sanitizePlainText(transcript);
            PrivateLog.userTextField(
              tag: 'HttpCaptureApiClient:',
              field: 'transcribe',
              text: sanitized,
            );
            return sanitized;
          },
          missingDataMessage: 'No transcript returned',
        );
      },
      onFailure: ApiFailureResult.new,
    );
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
    final fields = <String, String>{'session_id': sessionId};
    if (recoverySecretKeyBytes != null && recoverySecretKeyBytes.length == 32) {
      fields['recovery_secret'] = base64Url.encode(recoverySecretKeyBytes);
    }

    final headers = <String, String>{
      'Authorization': 'Bearer $captureToken',
      ApiHeaders.captureToken: captureToken,
      ApiHeaders.idempotencyKey: idempotencyKey,
    };

    final responseResult = await _transport.postMultipart(
      VoiceMemoryApiRoutes.liveAudioRecover.path,
      fields: fields,
      files: [
        MultipartFilePart.fromPath(
          field: 'vault',
          path: vaultFile.path,
          filename: vaultFile.uri.pathSegments.last,
          contentType: MediaType('application', 'octet-stream'),
        ),
      ],
      headers: headers,
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeEnvelope(
          response,
          parseData: LiveAudioRecoverResponseDto.fromJson,
          toDomain: _mapVaultRecoveryResult,
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  AttestResult _mapAttestResult(CaptureAttestResponseDto dto) {
    if (dto.via == 'session') {
      return AttestResult.session(userId: dto.userId ?? '');
    }
    final token = dto.token;
    if (token == null || token.isEmpty) {
      throw const FormatException('Attest failed');
    }
    return AttestResult.capture(
      token: token,
      expiresInSeconds: dto.expiresInSeconds ?? 3600,
    );
  }

  VaultRecoveryServerResult _mapVaultRecoveryResult(
    LiveAudioRecoverResponseDto dto,
  ) {
    return VaultRecoveryServerResult(
      recoveryAckId: dto.recoveryAckId,
      transcript: dto.transcript,
      reflectionJson: dto.reflection,
      durationSeconds: dto.durationSeconds,
      duplicate: dto.duplicate,
      frameCount: dto.frameCount,
    );
  }

  static String _audioFilename(String path) {
    final parts = path.split('.');
    final ext = parts.length > 1 ? parts.last : 'm4a';
    return 'recording.$ext';
  }
}