import 'package:archiveme_mobile/api/models/consent_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/coach_consent_api_client.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';

class HttpCoachConsentApiClient implements CoachConsentApiClient {
  HttpCoachConsentApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<CoachConsentToken>> issueToken({
    required String relationshipId,
    required String coachId,
    required CoachSharingPermissions permissions,
    required String clientAffirmationHash,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.coachConsentIssue.path) == null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.coachConsentIssue.path,
      body: {
        'relationshipId': relationshipId,
        'coachId': coachId,
        'permissions': permissions.toJson(),
        'clientAffirmationHash': clientAffirmationHash,
      },
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return const ApiFailureResult(ApiFailureAuthRequired());
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeEnvelope(
          response,
          parseData: ConsentIssueResponseDto.fromJson,
          toDomain: (dto) => CoachConsentToken.fromJson(dto.token),
          missingDataMessage: 'Coach consent token missing',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<CoachTokenVerificationResult>> verifyToken({
    required CoachConsentToken token,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.coachConsentVerify.path) == null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.coachConsentVerify.path,
      body: {'token': token.toJson()},
      cancelToken: cancelToken,
    );

    return responseResult.when(
      success: (response) {
        if (response.statusCode == 401) {
          return const ApiFailureResult(ApiFailureAuthRequired());
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return ApiFailureResult(ApiFailureMapper.fromResponse(response));
        }
        return _transport.decodeEnvelope(
          response,
          parseData: ConsentVerifyResponseDto.fromJson,
          toDomain: _mapVerificationResult,
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  CoachTokenVerificationResult _mapVerificationResult(
    ConsentVerifyResponseDto dto,
  ) {
    CoachSession? session;
    final sessionRaw = dto.session;
    if (sessionRaw != null) {
      session = CoachSession.fromJson(sessionRaw);
    }
    return CoachTokenVerificationResult(
      valid: dto.valid,
      reason: dto.reason,
      session: session,
    );
  }
}
