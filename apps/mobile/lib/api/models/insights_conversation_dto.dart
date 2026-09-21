import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

/// One `{role, content}` turn in `POST /api/insights/conversation` history.
///
/// Hand-rolled rather than generated so this addition does not require
/// regenerating a `.g.dart` file.
class InsightsConversationTurnDto {
  const InsightsConversationTurnDto({
    required this.role,
    required this.content,
  });

  factory InsightsConversationTurnDto.fromJson(Map<String, dynamic> json) =>
      InsightsConversationTurnDto(
        role: JsonConverters.string(json['role'], field: 'role'),
        content: JsonConverters.string(json['content'], field: 'content'),
      );

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
  };
}

/// Wire response for `POST /api/insights/conversation`.
///
/// `@JsonSerializable(createFactory: false)` matches other consent/insights
/// DTOs. `fromJson` is hand-rolled and `toJson` is omitted so this file does
/// not need a generated `.g.dart`.
@JsonSerializable(createFactory: false)
class InsightsConversationResponseDto {
  const InsightsConversationResponseDto({
    required this.reply,
    required this.citedEntryIds,
    required this.groundedness,
    this.ok,
  });

  factory InsightsConversationResponseDto.fromJson(Map<String, dynamic> json) =>
      InsightsConversationResponseDto(
        ok: JsonConverters.nullableBool(json['ok']),
        reply: JsonConverters.string(json['reply'], field: 'reply'),
        citedEntryIds: JsonConverters.stringList(json['citedEntryIds']),
        groundedness: JsonConverters.string(
          json['groundedness'],
          field: 'groundedness',
        ),
      );

  final bool? ok;
  final String reply;
  final List<String> citedEntryIds;
  final String groundedness;
}
