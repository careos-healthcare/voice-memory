import 'package:archiveme_mobile/api/models/relationships_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/http_transport.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/core/network/voice_memory_api_routes.dart';
import 'package:archiveme_mobile/data/network/user_relationship_api_client.dart';
import 'package:archiveme_mobile/features/relationships/user_relationship.dart';

class HttpUserRelationshipApiClient implements UserRelationshipApiClient {
  HttpUserRelationshipApiClient(this._transport);

  final HttpTransport _transport;

  @override
  Future<ApiResult<List<UserRelationship>>> listForCurrentUser({
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.userRelationships.path) == null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.get(
      VoiceMemoryApiRoutes.userRelationships.path,
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
          parseData: UserRelationshipsListResponseDto.fromJson,
          toDomain: (dto) => dto.relationships
              .map((item) => UserRelationship.fromJson(item.toJson()))
              .toList(),
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<UserRelationship>> upsert({
    required UserRelationship relationship,
    String? activeConsentTokenId,
    NetworkCancelToken? cancelToken,
  }) async {
    if (_transport.tryUri(VoiceMemoryApiRoutes.userRelationships.path) == null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.post(
      VoiceMemoryApiRoutes.userRelationships.path,
      body: {
        'id': relationship.id,
        'clientId': relationship.clientId,
        'professionalId': relationship.professionalId,
        'relationshipType': relationship.relationshipType.wireValue,
        'consentStatus': relationship.consentStatus.wireValue,
        'agreedScope': relationship.agreedScope,
        'activeConsentTokenId': ?activeConsentTokenId,
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
          parseData: UserRelationshipResponseDto.fromJson,
          toDomain: (dto) => UserRelationship.fromJson(dto.relationship.toJson()),
          missingDataMessage: 'Relationship missing from response',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }

  @override
  Future<ApiResult<UserRelationship>> updateConsentStatus({
    required String relationshipId,
    required ConsentStatus consentStatus,
    NetworkCancelToken? cancelToken,
  }) async {
    final path = VoiceMemoryApiRoutes.userRelationship(relationshipId);
    if (_transport.tryUri(path) == null) {
      return const ApiFailureResult(ApiFailureBackendNotConfigured());
    }

    final responseResult = await _transport.patch(
      path,
      body: {'consentStatus': consentStatus.wireValue},
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
          parseData: UserRelationshipResponseDto.fromJson,
          toDomain: (dto) => UserRelationship.fromJson(dto.relationship.toJson()),
          missingDataMessage: 'Relationship missing from response',
        );
      },
      onFailure: ApiFailureResult.new,
    );
  }
}
