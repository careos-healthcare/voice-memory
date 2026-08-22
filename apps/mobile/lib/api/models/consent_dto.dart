import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'consent_dto.g.dart';

/// Wire response for `POST /api/coach/consent/issue`.
@JsonSerializable(createFactory: false)
class ConsentIssueResponseDto {
  const ConsentIssueResponseDto({
    required this.token,
    this.ok,
  });

  factory ConsentIssueResponseDto.fromJson(Map<String, dynamic> json) =>
      ConsentIssueResponseDto(
        ok: JsonConverters.nullableBool(json['ok']),
        token: JsonConverters.requiredStringMap(json['token'], field: 'token'),
      );

  final bool? ok;
  final Map<String, dynamic> token;

  Map<String, dynamic> toJson() => _$ConsentIssueResponseDtoToJson(this);
}

/// Wire response for `POST /api/coach/consent/verify`.
@JsonSerializable(createFactory: false)
class ConsentVerifyResponseDto {
  const ConsentVerifyResponseDto({
    required this.valid,
    this.reason,
    this.session,
  });

  factory ConsentVerifyResponseDto.fromJson(Map<String, dynamic> json) =>
      ConsentVerifyResponseDto(
        valid: JsonConverters.boolValue(json['valid'], field: 'valid'),
        reason: JsonConverters.nullableString(json['reason']),
        session: JsonConverters.nullableStringMap(json['session']),
      );

  final bool valid;
  final String? reason;
  final Map<String, dynamic>? session;

  Map<String, dynamic> toJson() => _$ConsentVerifyResponseDtoToJson(this);
}

/// Wire response for `POST /api/coach/consent/revoke`.
///
/// Hand-rolled rather than `@JsonSerializable` so this addition does not
/// require regenerating `consent_dto.g.dart`.
class ConsentRevokeResponseDto {
  const ConsentRevokeResponseDto({
    required this.tokenId,
    required this.revoked,
    required this.alreadyRevoked,
    this.ok,
    this.revokedAt,
  });

  factory ConsentRevokeResponseDto.fromJson(Map<String, dynamic> json) =>
      ConsentRevokeResponseDto(
        ok: JsonConverters.nullableBool(json['ok']),
        tokenId: JsonConverters.stringOrEmpty(json['tokenId']),
        revoked: JsonConverters.boolOrFalse(json['revoked']),
        alreadyRevoked: JsonConverters.boolOrFalse(json['alreadyRevoked']),
        revokedAt: JsonConverters.nullableString(json['revokedAt']),
      );

  final bool? ok;
  final String tokenId;
  final bool revoked;
  final bool alreadyRevoked;
  final String? revokedAt;

  Map<String, dynamic> toJson() => {
    if (ok != null) 'ok': ok,
    'tokenId': tokenId,
    'revoked': revoked,
    'alreadyRevoked': alreadyRevoked,
    if (revokedAt != null) 'revokedAt': revokedAt,
  };
}

/// Wire response for `POST /api/coach/consent/renew`.
///
/// Hand-rolled for the same reason as [ConsentRevokeResponseDto]: it keeps the
/// addition out of `consent_dto.g.dart`.
///
/// [previousRevokedAt] is part of the contract rather than a courtesy. A
/// renewal that returned only the successor would leave the client unable to
/// tell whether the predecessor had actually been withdrawn, which is the one
/// thing a caller needs to know before it stops tracking the old grant.
class ConsentRenewResponseDto {
  const ConsentRenewResponseDto({
    required this.token,
    required this.previousTokenId,
    this.ok,
    this.renewed,
    this.previousRevokedAt,
    this.ownerConfirmedAt,
  });

  factory ConsentRenewResponseDto.fromJson(Map<String, dynamic> json) =>
      ConsentRenewResponseDto(
        ok: JsonConverters.nullableBool(json['ok']),
        renewed: JsonConverters.nullableBool(json['renewed']),
        token: JsonConverters.requiredStringMap(json['token'], field: 'token'),
        previousTokenId: JsonConverters.stringOrEmpty(json['previousTokenId']),
        previousRevokedAt: JsonConverters.nullableString(
          json['previousRevokedAt'],
        ),
        ownerConfirmedAt: JsonConverters.nullableString(
          json['ownerConfirmedAt'],
        ),
      );

  final bool? ok;
  final bool? renewed;
  final Map<String, dynamic> token;
  final String previousTokenId;
  final String? previousRevokedAt;
  final String? ownerConfirmedAt;

  Map<String, dynamic> toJson() => {
    if (ok != null) 'ok': ok,
    if (renewed != null) 'renewed': renewed,
    'token': token,
    'previousTokenId': previousTokenId,
    if (previousRevokedAt != null) 'previousRevokedAt': previousRevokedAt,
    if (ownerConfirmedAt != null) 'ownerConfirmedAt': ownerConfirmedAt,
  };
}
