import 'package:archiveme_mobile/api/models/api_error_dto.dart';
import 'package:archiveme_mobile/api/models/api_response.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'billing_dto.g.dart';

/// Payload for `GET /api/billing/entitlements`.
@JsonSerializable(createFactory: false)
class BillingEntitlementsDataDto {
  const BillingEntitlementsDataDto({
    required this.tier,
    required this.entitlements,
    required this.source,
    required this.billingConnected,
    this.previewMode = false,
    this.founderPreview = false,
  });

  factory BillingEntitlementsDataDto.fromJson(Map<String, dynamic> json) =>
      BillingEntitlementsDataDto(
        tier: JsonConverters.string(json['tier'], field: 'tier'),
        entitlements: JsonConverters.stringList(json['entitlements']),
        source: JsonConverters.string(json['source'], field: 'source'),
        billingConnected: JsonConverters.boolValue(
          json['billingConnected'],
          field: 'billingConnected',
        ),
        previewMode: JsonConverters.boolOrFalse(json['previewMode']),
        founderPreview: JsonConverters.boolOrFalse(json['founderPreview']),
      );

  final String tier;
  final List<String> entitlements;
  final String source;
  final bool billingConnected;
  final bool previewMode;
  final bool founderPreview;

  Map<String, dynamic> toJson() => _$BillingEntitlementsDataDtoToJson(this);
}

/// Payload for `POST /api/billing/checkout`.
@JsonSerializable(createFactory: false)
class BillingCheckoutDataDto {
  const BillingCheckoutDataDto({
    required this.url,
    this.sessionId,
  });

  factory BillingCheckoutDataDto.fromJson(Map<String, dynamic> json) =>
      BillingCheckoutDataDto(
        url: JsonConverters.string(json['url'], field: 'url'),
        sessionId: JsonConverters.nullableString(json['sessionId']),
      );

  final String url;
  final String? sessionId;

  Map<String, dynamic> toJson() => _$BillingCheckoutDataDtoToJson(this);
}

/// Retrofit envelope for `GET /api/billing/entitlements`.
class BillingEntitlementsApiResponse {
  const BillingEntitlementsApiResponse(this.envelope);

  final ApiResponse<BillingEntitlementsDataDto> envelope;

  bool get ok => envelope.ok;
  ApiErrorDto? get error => envelope.error;
  BillingEntitlementsDataDto? get data => envelope.data;

  factory BillingEntitlementsApiResponse.fromJson(Map<String, dynamic> json) =>
      BillingEntitlementsApiResponse(
        ApiResponse.fromJson(json, BillingEntitlementsDataDto.fromJson),
      );
}

/// Retrofit envelope for `POST /api/billing/checkout`.
class BillingCheckoutApiResponse {
  const BillingCheckoutApiResponse(this.envelope);

  final ApiResponse<BillingCheckoutDataDto> envelope;

  bool get ok => envelope.ok;
  ApiErrorDto? get error => envelope.error;
  BillingCheckoutDataDto? get data => envelope.data;

  factory BillingCheckoutApiResponse.fromJson(Map<String, dynamic> json) =>
      BillingCheckoutApiResponse(
        ApiResponse.fromJson(json, BillingCheckoutDataDto.fromJson),
      );
}

// Legacy aliases — prefer *DataDto / *ApiResponse in new code.
typedef BillingEntitlementsResponseDto = BillingEntitlementsDataDto;
typedef BillingCheckoutResponseDto = BillingCheckoutDataDto;
