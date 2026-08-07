import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';

import '../../models/attest_result.dart';
import '../../core/network/api_headers.dart';
import '../../features/voice_capture/audio/audio_capture_diagnostics.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/multipart_file_part.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/live_audio/domain/models/offline_vault_manifest.dart';
import '../../features/proof_admission/proof_admission_models.dart';
import '../../features/voice_capture/analysis/analysis_log.dart';
import '../../features/voice_capture/audio/audio_diag_log.dart';
import '../../features/voice_capture/transcription/transcription_log.dart';
import '../../models/reflection.dart';
import '../../security/ai_prompt_boundary.dart';
import '../../security/private_log.dart';
import '../../security/user_content_safety.dart';
import 'capture_api_client.dart';

class HttpCaptureApiClient implements CaptureApiClient {
  HttpCaptureApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    final responseResult = await _transport.post(
      '/api/capture/attest',
      body: {'deviceId': deviceId},
      cancelToken: cancelToken,
    );
    return responseResult.when(
      success: (response) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(
            ApiFailureMapper.fromResponse(response),
          );
        }
        return _transport.decodeSuccess(response, (body) {
          if (body['via'] == 'session') {
            return AttestResult.session(
              userId: body['userId'] as String? ?? '',
            );
          }
          final token = body['token'] as String?;
          if (token == null || body['ok'] != true) {
            throw FormatException('Attest failed');
          }
          return AttestResult.capture(
            token: token,
            expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 3600,
          );
        });
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

    AnalysisLog.request(url: '/api/analyze');
    final responseResult = await _transport.post(
      '/api/analyze',
      headers: headers,
      body: {
        'transcript': prepared,
        'priorEvidence': priorEvidence,
      },
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
          } catch (_) {}
          AnalysisLog.failed(
            status: response.statusCode,
            code: code,
            reason: reason,
          );
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeSuccess(response, (body) {
          final reflection = body['reflection'] as Map<String, dynamic>?;
          if (reflection == null) {
            AnalysisLog.failed(
              status: response.statusCode,
              reason: 'No reflection in response',
            );
            throw FormatException('No reflection in response');
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
        });
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
    TranscriptionLog.request(url: '/api/transcribe');
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
      '/api/transcribe',
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
        return _transport.decodeSuccess(response, (body) {
          final transcript = body['transcript'] as String?;
          if (transcript == null || transcript.trim().isEmpty) {
            throw FormatException(
              body['error'] as String? ?? 'No transcript returned',
            );
          }
          final sanitized = UserContentSafety.sanitizePlainText(
            transcript.trim(),
          );
          PrivateLog.userTextField(
            tag: 'HttpCaptureApiClient:',
            field: 'transcribe',
            text: sanitized,
          );
          return sanitized;
        });
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
      '/api/live-audio/recover',
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
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['ok'] != true) {
            return ApiFailureResult(
              ApiFailureMapper.fromResponse(response),
            );
          }
          return ApiSuccess(VaultRecoveryServerResult.fromJson(body));
        } on FormatException catch (error) {
          return ApiFailureResult(ApiFailureMapper.fromException(error));
        }
      },
      onFailure: ApiFailureResult.new,
    );
  }

  static String _audioFilename(String path) {
    final parts = path.split('.');
    final ext = parts.length > 1 ? parts.last : 'm4a';
    return 'recording.$ext';
  }
}
