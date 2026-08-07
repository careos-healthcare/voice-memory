import 'dart:convert';

import '../../api/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_mapper.dart';
import '../../core/network/api_result.dart';
import '../../core/network/http_transport.dart';
import '../../core/network/network_cancel_token.dart';
import '../../features/proof_admission/proof_admission_models.dart';
import '../../features/voice_capture/analysis/analysis_log.dart';
import '../../models/reflection.dart';
import '../../security/ai_prompt_boundary.dart';
import '../../security/private_log.dart';
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
      ApiClient.captureTokenHeader: captureToken,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        ApiClient.idempotencyHeader: idempotencyKey,
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
}
