import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'archive_synthesis_dto.g.dart';

/// Wire response for `POST /api/archive-synthesis`.
@JsonSerializable(createFactory: false)
class ArchiveSynthesisResponseDto {
  const ArchiveSynthesisResponseDto({
    this.synthesisType,
    this.cached,
    this.review,
  });

  factory ArchiveSynthesisResponseDto.fromJson(Map<String, dynamic> json) =>
      ArchiveSynthesisResponseDto(
        synthesisType: JsonConverters.nullableString(json['synthesisType']),
        cached: JsonConverters.nullableBool(json['cached']),
        review: JsonConverters.nullableStringMap(json['review']),
      );

  final String? synthesisType;
  final bool? cached;
  final Map<String, dynamic>? review;

  Map<String, dynamic> toJson() => _$ArchiveSynthesisResponseDtoToJson(this);
}
