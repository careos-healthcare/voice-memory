import 'package:archiveme_mobile/api/models/consent_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/caregiver_consent_api_client.dart';
import 'package:archiveme_mobile/data/network/consent_renewal_api_client.dart';
import 'package:archiveme_mobile/data/network/consent_revocation_api_client.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';

class HttpCaregiverConsentApiClient
    implements CaregiverConsentApiClient, ConsentRenewalApiClient {
  HttpCaregiverConsentApiClient(this._transport);

  final HttpTransport _transport;

  static const _consentDomain = 'caregiverMonitoring';

  @override
  Future<ApiResult<MonitoringConsentToken>> issueToken({
    required String subjectAccountId,
    required String caregiverId,
    required CaregiverPermissions permissions,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.coachConsentIssue.path) == null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.coachConsentIssue.path,
      body: {
        'consentDomain': _consentDomain,
        'caregiverId': caregiverId,
        'permissions': permissions.toJson(),
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
          toDomain: (dto) => MonitoringConsentToken.fromJson(dto.token),
          missingDataMessage: 'Caregiver consent token missing',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<CaregiverTokenVerificationResult>> verifyToken({
    required MonitoringConsentToken token,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.coachConsentVerify.path) == null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.coachConsentVerify.path,
      body: {
        'consentDomain': _consentDomain,
        'token': token.toJson(),
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
          parseData: ConsentVerifyResponseDto.fromJson,
          toDomain: _mapVerificationResult,
        );
      },
      onFailure: ApiFailureResult.new,
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
    if (_transport.tryUri(VoiceMemoryApiRoutes.coachConsentRevoke.path) ==
        null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.coachConsentRevoke.path,
      body: {
        'consentDomain': domain.wireValue,
        'tokenId': tokenId,
        'reason': reason ?? ConsentRevocationReason.userRevoked,
        'token': ?token,
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
          parseData: ConsentRevokeResponseDto.fromJson,
          toDomain: (dto) => ConsentRevocationConfirmation(
            tokenId: dto.tokenId.isEmpty ? tokenId : dto.tokenId,
            revoked: dto.revoked,
            alreadyRevoked: dto.alreadyRevoked,
            revokedAt: DateTime.tryParse(dto.revokedAt ?? '')?.toUtc(),
          ),
          missingDataMessage: 'Consent revocation result missing',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<ConsentRenewalConfirmation>> renewCaregiverConsent({
    required String tokenId,
    required Map<String, dynamic> token,
    required DateTime ownerConfirmedAt,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.coachConsentRenew.path) == null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.coachConsentRenew.path,
      body: {
        'consentDomain': _consentDomain,
        'tokenId': tokenId,
        'token': token,
        'ownerConfirmation': {
          'confirmedTokenId': tokenId,
          'acknowledgedAt': ownerConfirmedAt.toUtc().toIso8601String(),
        },
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
          parseData: ConsentRenewResponseDto.fromJson,
          toDomain: (dto) => ConsentRenewalConfirmation(
            token: MonitoringConsentToken.fromJson(dto.token),
            previousTokenId: dto.previousTokenId.isEmpty
                ? tokenId
                : dto.previousTokenId,
            previousRevokedAt: DateTime.tryParse(
              dto.previousRevokedAt ?? '',
            )?.toUtc(),
            ownerConfirmedAt: DateTime.tryParse(
              dto.ownerConfirmedAt ?? '',
            )?.toUtc(),
          ),
          missingDataMessage: 'Consent renewal result missing',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  CaregiverTokenVerificationResult _mapVerificationResult(
    ConsentVerifyResponseDto dto,
  ) {
    CaregiverSession? session;
    final sessionRaw = dto.session;
    if (sessionRaw != null) {
      session = CaregiverSession.fromJson(sessionRaw);
    }
    return CaregiverTokenVerificationResult(
      valid: dto.valid,
      reason: dto.reason,
      session: session,
    );
  }
}
