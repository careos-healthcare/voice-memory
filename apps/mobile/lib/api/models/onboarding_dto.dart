import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'onboarding_dto.g.dart';

/// Wire response for `POST /api/onboarding/brain-dump`.
@JsonSerializable(createFactory: false)
class BrainDumpResponseDto {
  const BrainDumpResponseDto({
    required this.ok,
    required this.entryId,
  });

  factory BrainDumpResponseDto.fromJson(Map<String, dynamic> json) =>
      BrainDumpResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        entryId: JsonConverters.string(json['entryId'], field: 'entryId'),
      );

  final bool ok;
  final String entryId;

  Map<String, dynamic> toJson() => _$BrainDumpResponseDtoToJson(this);
}
