import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'push_dto.g.dart';

/// Wire response for `POST /api/push/register`.
@JsonSerializable(createFactory: false)
class PushRegisterResponseDto {
  const PushRegisterResponseDto({
    required this.ok,
    required this.userId,
    required this.pruned,
  });

  factory PushRegisterResponseDto.fromJson(Map<String, dynamic> json) =>
      PushRegisterResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        userId: JsonConverters.string(json['userId'], field: 'userId'),
        pruned: JsonConverters.intValue(json['pruned'], field: 'pruned'),
      );

  final bool ok;
  final String userId;
  final int pruned;

  Map<String, dynamic> toJson() => _$PushRegisterResponseDtoToJson(this);
}

/// Wire response for `POST /api/internal/send-test-push`.
@JsonSerializable(createFactory: false)
class SendTestPushResponseDto {
  const SendTestPushResponseDto({
    required this.ok,
    required this.messageId,
    required this.deviceId,
    required this.targetRoute,
    required this.delivery,
  });

  factory SendTestPushResponseDto.fromJson(Map<String, dynamic> json) =>
      SendTestPushResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        messageId: JsonConverters.string(json['messageId'], field: 'messageId'),
        deviceId: JsonConverters.string(json['deviceId'], field: 'deviceId'),
        targetRoute:
            JsonConverters.string(json['targetRoute'], field: 'targetRoute'),
        delivery: JsonConverters.string(json['delivery'], field: 'delivery'),
      );

  final bool ok;
  final String messageId;
  final String deviceId;
  final String targetRoute;
  final String delivery;

  Map<String, dynamic> toJson() => _$SendTestPushResponseDtoToJson(this);
}
