import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'insights_dto.g.dart';

@JsonSerializable(createFactory: false)
class InsightPayloadDto {
  const InsightPayloadDto({
    required this.id,
    required this.insightText,
    required this.confidenceBand,
    this.kind,
    this.citedEntryIds = const [],
  });

  factory InsightPayloadDto.fromJson(Map<String, dynamic> json) =>
      InsightPayloadDto(
        id: JsonConverters.string(json['id'], field: 'id'),
        insightText:
            JsonConverters.string(json['insightText'], field: 'insightText'),
        confidenceBand: JsonConverters.string(
          json['confidenceBand'],
          field: 'confidenceBand',
        ),
        kind: JsonConverters.nullableString(json['kind']),
        citedEntryIds: JsonConverters.stringList(json['citedEntryIds']),
      );

  final String id;
  final String insightText;
  final String confidenceBand;
  final String? kind;
  final List<String> citedEntryIds;

  Map<String, dynamic> toJson() => _$InsightPayloadDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class EvidenceInsightResponseDto {
  const EvidenceInsightResponseDto({
    required this.ok,
    required this.entryId,
    required this.insight,
  });

  factory EvidenceInsightResponseDto.fromJson(Map<String, dynamic> json) =>
      EvidenceInsightResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        entryId: JsonConverters.string(json['entryId'], field: 'entryId'),
        insight: JsonConverters.requiredObject(
          json['insight'],
          InsightPayloadDto.fromJson,
          field: 'insight',
        ),
      );

  final bool ok;
  final String entryId;
  final InsightPayloadDto insight;

  Map<String, dynamic> toJson() => _$EvidenceInsightResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class InsightCorrectionResponseDto {
  const InsightCorrectionResponseDto({required this.ok});

  factory InsightCorrectionResponseDto.fromJson(Map<String, dynamic> json) =>
      InsightCorrectionResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
      );

  final bool ok;

  Map<String, dynamic> toJson() => _$InsightCorrectionResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class WeeklyStoryPayloadDto {
  const WeeklyStoryPayloadDto({
    required this.id,
    required this.storyText,
    required this.confidenceBand,
    required this.weekStart,
    required this.weekEnd,
    required this.entryCountThisWeek,
    required this.usableEntryCountThisWeek,
    this.citedEntryIds = const [],
  });

  factory WeeklyStoryPayloadDto.fromJson(Map<String, dynamic> json) =>
      WeeklyStoryPayloadDto(
        id: JsonConverters.string(json['id'], field: 'id'),
        storyText: JsonConverters.string(json['storyText'], field: 'storyText'),
        confidenceBand: JsonConverters.string(
          json['confidenceBand'],
          field: 'confidenceBand',
        ),
        citedEntryIds: JsonConverters.stringList(json['citedEntryIds']),
        weekStart: JsonConverters.string(json['weekStart'], field: 'weekStart'),
        weekEnd: JsonConverters.string(json['weekEnd'], field: 'weekEnd'),
        entryCountThisWeek: JsonConverters.intValue(
          json['entryCountThisWeek'],
          field: 'entryCountThisWeek',
        ),
        usableEntryCountThisWeek: JsonConverters.intValue(
          json['usableEntryCountThisWeek'],
          field: 'usableEntryCountThisWeek',
        ),
      );

  final String id;
  final String storyText;
  final String confidenceBand;
  final List<String> citedEntryIds;
  final String weekStart;
  final String weekEnd;
  final int entryCountThisWeek;
  final int usableEntryCountThisWeek;

  Map<String, dynamic> toJson() => _$WeeklyStoryPayloadDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class WeeklyStoryResponseDto {
  const WeeklyStoryResponseDto({
    required this.ok,
    required this.story,
  });

  factory WeeklyStoryResponseDto.fromJson(Map<String, dynamic> json) =>
      WeeklyStoryResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        story: JsonConverters.requiredObject(
          json['story'],
          WeeklyStoryPayloadDto.fromJson,
          field: 'story',
        ),
      );

  final bool ok;
  final WeeklyStoryPayloadDto story;

  Map<String, dynamic> toJson() => _$WeeklyStoryResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class ComparisonPeriodDto {
  const ComparisonPeriodDto({
    required this.from,
    required this.to,
    required this.totalEntryCount,
    required this.usableEntryCount,
  });

  factory ComparisonPeriodDto.fromJson(Map<String, dynamic> json) =>
      ComparisonPeriodDto(
        from: JsonConverters.string(json['from'], field: 'from'),
        to: JsonConverters.string(json['to'], field: 'to'),
        totalEntryCount: JsonConverters.intValue(
          json['totalEntryCount'],
          field: 'totalEntryCount',
        ),
        usableEntryCount: JsonConverters.intValue(
          json['usableEntryCount'],
          field: 'usableEntryCount',
        ),
      );

  final String from;
  final String to;
  final int totalEntryCount;
  final int usableEntryCount;

  Map<String, dynamic> toJson() => _$ComparisonPeriodDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class ComparisonPayloadDto {
  const ComparisonPayloadDto({
    required this.id,
    required this.evolutionText,
    required this.confidenceLabel,
    required this.whatRepeated,
    required this.whatChanged,
    required this.periodA,
    required this.periodB,
    this.thinEvidencePhrase,
    this.citedEntryIds = const [],
  });

  factory ComparisonPayloadDto.fromJson(Map<String, dynamic> json) =>
      ComparisonPayloadDto(
        id: JsonConverters.string(json['id'], field: 'id'),
        evolutionText:
            JsonConverters.string(json['evolutionText'], field: 'evolutionText'),
        confidenceLabel: JsonConverters.string(
          json['confidenceLabel'],
          field: 'confidenceLabel',
        ),
        whatRepeated:
            JsonConverters.string(json['whatRepeated'], field: 'whatRepeated'),
        whatChanged:
            JsonConverters.string(json['whatChanged'], field: 'whatChanged'),
        thinEvidencePhrase:
            JsonConverters.nullableString(json['thinEvidencePhrase']),
        citedEntryIds: JsonConverters.stringList(json['citedEntryIds']),
        periodA: JsonConverters.requiredObject(
          json['periodA'],
          ComparisonPeriodDto.fromJson,
          field: 'periodA',
        ),
        periodB: JsonConverters.requiredObject(
          json['periodB'],
          ComparisonPeriodDto.fromJson,
          field: 'periodB',
        ),
      );

  final String id;
  final String evolutionText;
  final String confidenceLabel;
  final String whatRepeated;
  final String whatChanged;
  final String? thinEvidencePhrase;
  final List<String> citedEntryIds;
  final ComparisonPeriodDto periodA;
  final ComparisonPeriodDto periodB;

  Map<String, dynamic> toJson() => _$ComparisonPayloadDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class ComparisonResponseDto {
  const ComparisonResponseDto({
    required this.ok,
    required this.comparison,
  });

  factory ComparisonResponseDto.fromJson(Map<String, dynamic> json) =>
      ComparisonResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        comparison: JsonConverters.requiredObject(
          json['comparison'],
          ComparisonPayloadDto.fromJson,
          field: 'comparison',
        ),
      );

  final bool ok;
  final ComparisonPayloadDto comparison;

  Map<String, dynamic> toJson() => _$ComparisonResponseDtoToJson(this);
}
