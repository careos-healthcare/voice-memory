import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'capture_dto.g.dart';

@JsonSerializable(createFactory: false)
class CaptureAttestResponseDto {
  const CaptureAttestResponseDto({
    required this.ok,
    this.via,
    this.userId,
    this.deviceId,
    this.token,
    this.expiresInSeconds,
  });

  factory CaptureAttestResponseDto.fromJson(Map<String, dynamic> json) =>
      CaptureAttestResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        via: JsonConverters.nullableString(json['via']),
        userId: JsonConverters.nullableString(json['userId']),
        deviceId: JsonConverters.nullableString(json['deviceId']),
        token: JsonConverters.nullableString(json['token']),
        expiresInSeconds: JsonConverters.nullableInt(json['expiresInSeconds']),
      );

  final bool ok;
  final String? via;
  final String? userId;
  final String? deviceId;
  final String? token;
  final int? expiresInSeconds;

  Map<String, dynamic> toJson() => _$CaptureAttestResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class ReflectionDto {
  const ReflectionDto({
    required this.mood,
    required this.emotionalIntensity,
    this.recurringThemes = const [],
    this.hiddenConcern = '',
    this.positiveSignal = '',
    this.recommendation = '',
    this.exactLanguagePattern,
    this.concreteObservation,
    this.repeatedSignal,
    this.tensionOrContradiction,
    this.avoidedOrVagueArea,
    this.nextSmallAction,
    this.patternObservations = const [],
  });

  factory ReflectionDto.fromJson(Map<String, dynamic> json) => ReflectionDto(
        mood: JsonConverters.string(json['mood'], field: 'mood'),
        emotionalIntensity: JsonConverters.intValue(
          json['emotionalIntensity'],
          field: 'emotionalIntensity',
        ),
        recurringThemes: JsonConverters.stringList(json['recurringThemes']),
        hiddenConcern: JsonConverters.stringOrEmpty(json['hiddenConcern']),
        positiveSignal: JsonConverters.stringOrEmpty(json['positiveSignal']),
        recommendation: JsonConverters.stringOrEmpty(json['recommendation']),
        exactLanguagePattern:
            JsonConverters.nullableString(json['exactLanguagePattern']),
        concreteObservation:
            JsonConverters.nullableString(json['concreteObservation']),
        repeatedSignal: JsonConverters.nullableString(json['repeatedSignal']),
        tensionOrContradiction:
            JsonConverters.nullableString(json['tensionOrContradiction']),
        avoidedOrVagueArea:
            JsonConverters.nullableString(json['avoidedOrVagueArea']),
        nextSmallAction: JsonConverters.nullableString(json['nextSmallAction']),
        patternObservations:
            JsonConverters.stringList(json['patternObservations']),
      );

  final String mood;
  final int emotionalIntensity;
  final List<String> recurringThemes;
  final String hiddenConcern;
  final String positiveSignal;
  final String recommendation;
  final String? exactLanguagePattern;
  final String? concreteObservation;
  final String? repeatedSignal;
  final String? tensionOrContradiction;
  final String? avoidedOrVagueArea;
  final String? nextSmallAction;
  final List<String> patternObservations;

  Map<String, dynamic> toJson() => _$ReflectionDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class AnalyzeResponseDto {
  const AnalyzeResponseDto({required this.reflection});

  factory AnalyzeResponseDto.fromJson(Map<String, dynamic> json) =>
      AnalyzeResponseDto(
        reflection: JsonConverters.requiredObject(
          json['reflection'],
          ReflectionDto.fromJson,
          field: 'reflection',
        ),
      );

  final ReflectionDto reflection;

  Map<String, dynamic> toJson() => _$AnalyzeResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class TranscribeResponseDto {
  const TranscribeResponseDto({required this.transcript});

  factory TranscribeResponseDto.fromJson(Map<String, dynamic> json) =>
      TranscribeResponseDto(
        transcript: JsonConverters.string(json['transcript'], field: 'transcript'),
      );

  final String transcript;

  Map<String, dynamic> toJson() => _$TranscribeResponseDtoToJson(this);
}
