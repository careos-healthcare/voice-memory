import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'relationships_dto.g.dart';

@JsonSerializable(createFactory: false)
class UserRelationshipDto {
  const UserRelationshipDto({
    required this.id,
    required this.clientId,
    required this.professionalId,
    required this.relationshipType,
    required this.consentStatus,
    required this.agreedScope,
    required this.createdAt,
    required this.updatedAt,
    this.activeConsentTokenId,
  });

  factory UserRelationshipDto.fromJson(Map<String, dynamic> json) =>
      UserRelationshipDto(
        id: JsonConverters.string(json['id'], field: 'id'),
        clientId: JsonConverters.string(json['clientId'], field: 'clientId'),
        professionalId: JsonConverters.string(
          json['professionalId'],
          field: 'professionalId',
        ),
        relationshipType: JsonConverters.string(
          json['relationshipType'],
          field: 'relationshipType',
        ),
        consentStatus: JsonConverters.string(
          json['consentStatus'],
          field: 'consentStatus',
        ),
        agreedScope: JsonConverters.requiredStringMap(
          json['agreedScope'],
          field: 'agreedScope',
        ),
        activeConsentTokenId:
            JsonConverters.nullableString(json['activeConsentTokenId']),
        createdAt: JsonConverters.string(json['createdAt'], field: 'createdAt'),
        updatedAt: JsonConverters.string(json['updatedAt'], field: 'updatedAt'),
      );

  final String id;
  final String clientId;
  final String professionalId;
  final String relationshipType;
  final String consentStatus;
  final Map<String, dynamic> agreedScope;
  final String? activeConsentTokenId;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toJson() => _$UserRelationshipDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class UserRelationshipsListResponseDto {
  const UserRelationshipsListResponseDto({
    required this.ok,
    required this.relationships,
  });

  factory UserRelationshipsListResponseDto.fromJson(
    Map<String, dynamic> json,
  ) =>
      UserRelationshipsListResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        relationships: JsonConverters.objectList(
          json['relationships'],
          UserRelationshipDto.fromJson,
          field: 'relationships',
        ),
      );

  final bool ok;
  final List<UserRelationshipDto> relationships;

  Map<String, dynamic> toJson() =>
      _$UserRelationshipsListResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class UserRelationshipResponseDto {
  const UserRelationshipResponseDto({
    required this.ok,
    required this.relationship,
  });

  factory UserRelationshipResponseDto.fromJson(Map<String, dynamic> json) =>
      UserRelationshipResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        relationship: JsonConverters.requiredObject(
          json['relationship'],
          UserRelationshipDto.fromJson,
          field: 'relationship',
        ),
      );

  final bool ok;
  final UserRelationshipDto relationship;

  Map<String, dynamic> toJson() => _$UserRelationshipResponseDtoToJson(this);
}
