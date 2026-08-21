// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_audio_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$LiveAudioSessionResponseDtoToJson(
  LiveAudioSessionResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'sessionId': instance.sessionId,
  'sessionToken': instance.sessionToken,
  'expiresAt': instance.expiresAt,
  'expiresInSeconds': instance.expiresInSeconds,
  'proxyWebSocketUrl': instance.proxyWebSocketUrl,
  'model': instance.model,
  'inputAudioMimeType': instance.inputAudioMimeType,
  'outputAudioMimeType': instance.outputAudioMimeType,
  'vaultRecoverySecret': instance.vaultRecoverySecret,
};

Map<String, dynamic> _$LiveAudioRecoverResponseDtoToJson(
  LiveAudioRecoverResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'recoveryAckId': instance.recoveryAckId,
  'duplicate': instance.duplicate,
  'transcript': instance.transcript,
  'reflection': instance.reflection,
  'durationSeconds': instance.durationSeconds,
  'frameCount': instance.frameCount,
};
