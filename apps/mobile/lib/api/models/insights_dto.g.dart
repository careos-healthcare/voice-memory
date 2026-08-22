// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insights_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$InsightPayloadDtoToJson(InsightPayloadDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'insightText': instance.insightText,
      'confidenceBand': instance.confidenceBand,
      'kind': instance.kind,
      'citedEntryIds': instance.citedEntryIds,
    };

Map<String, dynamic> _$EvidenceInsightResponseDtoToJson(
  EvidenceInsightResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'entryId': instance.entryId,
  'insight': instance.insight,
};

Map<String, dynamic> _$InsightCorrectionResponseDtoToJson(
  InsightCorrectionResponseDto instance,
) => <String, dynamic>{'ok': instance.ok};

Map<String, dynamic> _$WeeklyStoryPayloadDtoToJson(
  WeeklyStoryPayloadDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'storyText': instance.storyText,
  'confidenceBand': instance.confidenceBand,
  'citedEntryIds': instance.citedEntryIds,
  'weekStart': instance.weekStart,
  'weekEnd': instance.weekEnd,
  'entryCountThisWeek': instance.entryCountThisWeek,
  'usableEntryCountThisWeek': instance.usableEntryCountThisWeek,
};

Map<String, dynamic> _$WeeklyStoryResponseDtoToJson(
  WeeklyStoryResponseDto instance,
) => <String, dynamic>{'ok': instance.ok, 'story': instance.story};

Map<String, dynamic> _$ComparisonPeriodDtoToJson(
  ComparisonPeriodDto instance,
) => <String, dynamic>{
  'from': instance.from,
  'to': instance.to,
  'totalEntryCount': instance.totalEntryCount,
  'usableEntryCount': instance.usableEntryCount,
};

Map<String, dynamic> _$ComparisonPayloadDtoToJson(
  ComparisonPayloadDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'evolutionText': instance.evolutionText,
  'confidenceLabel': instance.confidenceLabel,
  'whatRepeated': instance.whatRepeated,
  'whatChanged': instance.whatChanged,
  'thinEvidencePhrase': instance.thinEvidencePhrase,
  'citedEntryIds': instance.citedEntryIds,
  'periodA': instance.periodA,
  'periodB': instance.periodB,
};

Map<String, dynamic> _$ComparisonResponseDtoToJson(
  ComparisonResponseDto instance,
) => <String, dynamic>{'ok': instance.ok, 'comparison': instance.comparison};
