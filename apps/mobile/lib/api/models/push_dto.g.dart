// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PushRegisterResponseDtoToJson(
  PushRegisterResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'userId': instance.userId,
  'pruned': instance.pruned,
};

Map<String, dynamic> _$SendTestPushResponseDtoToJson(
  SendTestPushResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'messageId': instance.messageId,
  'deviceId': instance.deviceId,
  'targetRoute': instance.targetRoute,
  'delivery': instance.delivery,
};
