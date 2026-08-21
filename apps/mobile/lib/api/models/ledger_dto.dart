import 'package:archiveme_mobile/api/models/insights_dto.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ledger_dto.g.dart';

@JsonSerializable(createFactory: false)
class LedgerBulkImportResponseDto {
  const LedgerBulkImportResponseDto({
    required this.ok,
    required this.imported,
    required this.failed,
    this.errors = const [],
    this.insight,
    this.entryId,
    this.sourceFile,
  });

  factory LedgerBulkImportResponseDto.fromJson(Map<String, dynamic> json) =>
      LedgerBulkImportResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        imported: JsonConverters.intValue(json['imported'], field: 'imported'),
        failed: JsonConverters.intValue(json['failed'], field: 'failed'),
        errors: JsonConverters.stringList(json['errors']),
        insight: JsonConverters.nullableObject(
          json['insight'],
          InsightPayloadDto.fromJson,
        ),
        entryId: JsonConverters.nullableString(json['entryId']),
        sourceFile: JsonConverters.nullableString(json['sourceFile']),
      );

  final bool ok;
  final int imported;
  final int failed;
  final List<String> errors;
  final InsightPayloadDto? insight;
  final String? entryId;
  final String? sourceFile;

  Map<String, dynamic> toJson() => _$LedgerBulkImportResponseDtoToJson(this);
}
