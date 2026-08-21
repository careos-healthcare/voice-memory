import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'account_dto.g.dart';

@JsonSerializable(createFactory: false)
class AccountDeleteStoreResultDto {
  const AccountDeleteStoreResultDto({
    required this.store,
    required this.mode,
    required this.ok,
    this.count,
    this.error,
  });

  factory AccountDeleteStoreResultDto.fromJson(Map<String, dynamic> json) =>
      AccountDeleteStoreResultDto(
        store: JsonConverters.string(json['store'], field: 'store'),
        mode: JsonConverters.string(json['mode'], field: 'mode'),
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        count: JsonConverters.nullableInt(json['count']),
        error: JsonConverters.nullableString(json['error']),
      );

  final String store;
  final String mode;
  final bool ok;
  final int? count;
  final String? error;

  Map<String, dynamic> toJson() => _$AccountDeleteStoreResultDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class AccountDeleteResponseDto {
  const AccountDeleteResponseDto({
    required this.ok,
    required this.stores,
    required this.message,
    this.sessionRevokeError,
    this.error,
  });

  factory AccountDeleteResponseDto.fromJson(Map<String, dynamic> json) =>
      AccountDeleteResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        stores: JsonConverters.objectList(
          json['stores'],
          AccountDeleteStoreResultDto.fromJson,
          field: 'stores',
        ),
        sessionRevokeError:
            JsonConverters.nullableString(json['sessionRevokeError']),
        error: JsonConverters.nullableString(json['error']),
        message: JsonConverters.string(json['message'], field: 'message'),
      );

  final bool ok;
  final List<AccountDeleteStoreResultDto> stores;
  final String? sessionRevokeError;
  final String? error;
  final String message;

  Map<String, dynamic> toJson() => _$AccountDeleteResponseDtoToJson(this);
}
