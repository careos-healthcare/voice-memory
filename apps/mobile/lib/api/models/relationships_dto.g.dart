// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relationships_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$UserRelationshipDtoToJson(
  UserRelationshipDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'clientId': instance.clientId,
  'professionalId': instance.professionalId,
  'relationshipType': instance.relationshipType,
  'consentStatus': instance.consentStatus,
  'agreedScope': instance.agreedScope,
  'activeConsentTokenId': instance.activeConsentTokenId,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

Map<String, dynamic> _$UserRelationshipsListResponseDtoToJson(
  UserRelationshipsListResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'relationships': instance.relationships,
};

Map<String, dynamic> _$UserRelationshipResponseDtoToJson(
  UserRelationshipResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'relationship': instance.relationship,
};
