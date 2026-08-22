// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capture_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$CaptureAttestResponseDtoToJson(
  CaptureAttestResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'via': instance.via,
  'userId': instance.userId,
  'deviceId': instance.deviceId,
  'token': instance.token,
  'expiresInSeconds': instance.expiresInSeconds,
};

Map<String, dynamic> _$ReflectionDtoToJson(ReflectionDto instance) =>
    <String, dynamic>{
      'mood': instance.mood,
      'emotionalIntensity': instance.emotionalIntensity,
      'recurringThemes': instance.recurringThemes,
      'hiddenConcern': instance.hiddenConcern,
      'positiveSignal': instance.positiveSignal,
      'recommendation': instance.recommendation,
      'exactLanguagePattern': instance.exactLanguagePattern,
      'concreteObservation': instance.concreteObservation,
      'repeatedSignal': instance.repeatedSignal,
      'tensionOrContradiction': instance.tensionOrContradiction,
      'avoidedOrVagueArea': instance.avoidedOrVagueArea,
      'nextSmallAction': instance.nextSmallAction,
      'patternObservations': instance.patternObservations,
    };

Map<String, dynamic> _$AnalyzeResponseDtoToJson(AnalyzeResponseDto instance) =>
    <String, dynamic>{'reflection': instance.reflection};

Map<String, dynamic> _$TranscribeResponseDtoToJson(
  TranscribeResponseDto instance,
) => <String, dynamic>{'transcript': instance.transcript};
