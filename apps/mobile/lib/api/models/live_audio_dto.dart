import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'live_audio_dto.g.dart';

/// Wire response for `POST /api/live-audio/session`.
@JsonSerializable(createFactory: false)
class LiveAudioSessionResponseDto {
  const LiveAudioSessionResponseDto({
    required this.ok,
    required this.sessionId,
    required this.sessionToken,
    required this.expiresAt,
    required this.expiresInSeconds,
    required this.proxyWebSocketUrl,
    required this.model,
    required this.inputAudioMimeType,
    required this.outputAudioMimeType,
    this.vaultRecoverySecret,
  });

  factory LiveAudioSessionResponseDto.fromJson(Map<String, dynamic> json) =>
      LiveAudioSessionResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        sessionId: JsonConverters.string(json['sessionId'], field: 'sessionId'),
        sessionToken:
            JsonConverters.string(json['sessionToken'], field: 'sessionToken'),
        expiresAt: _readExpiresAt(json['expiresAt']),
        expiresInSeconds: JsonConverters.intValue(
          json['expiresInSeconds'],
          field: 'expiresInSeconds',
        ),
        proxyWebSocketUrl: JsonConverters.string(
          json['proxyWebSocketUrl'],
          field: 'proxyWebSocketUrl',
        ),
        model: JsonConverters.string(json['model'], field: 'model'),
        inputAudioMimeType: JsonConverters.string(
          json['inputAudioMimeType'],
          field: 'inputAudioMimeType',
        ),
        outputAudioMimeType: JsonConverters.string(
          json['outputAudioMimeType'],
          field: 'outputAudioMimeType',
        ),
        vaultRecoverySecret:
            JsonConverters.nullableString(json['vaultRecoverySecret']),
      );

  final bool ok;
  final String sessionId;
  final String sessionToken;

  /// Unix epoch milliseconds (server `payload.exp`).
  final int expiresAt;
  final int expiresInSeconds;
  final String proxyWebSocketUrl;
  final String model;
  final String inputAudioMimeType;
  final String outputAudioMimeType;
  final String? vaultRecoverySecret;

  Map<String, dynamic> toJson() => _$LiveAudioSessionResponseDtoToJson(this);

  static int _readExpiresAt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return DateTime.parse(value).millisecondsSinceEpoch;
    }
    throw FormatException(
      'Expected expiresAt int or ISO-8601 string, got ${value.runtimeType}',
    );
  }
}

/// Wire response for `POST /api/live-audio/recover`.
@JsonSerializable(createFactory: false)
class LiveAudioRecoverResponseDto {
  const LiveAudioRecoverResponseDto({
    required this.ok,
    required this.recoveryAckId,
    required this.duplicate,
    required this.transcript,
    required this.reflection,
    required this.durationSeconds,
    required this.frameCount,
  });

  factory LiveAudioRecoverResponseDto.fromJson(Map<String, dynamic> json) =>
      LiveAudioRecoverResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        recoveryAckId: JsonConverters.string(
          json['recoveryAckId'],
          field: 'recoveryAckId',
        ),
        duplicate: JsonConverters.boolValue(json['duplicate'], field: 'duplicate'),
        transcript: JsonConverters.string(json['transcript'], field: 'transcript'),
        reflection: JsonConverters.requiredStringMap(
          json['reflection'],
          field: 'reflection',
        ),
        durationSeconds: JsonConverters.intValue(
          json['durationSeconds'],
          field: 'durationSeconds',
        ),
        frameCount: JsonConverters.intValue(json['frameCount'], field: 'frameCount'),
      );

  final bool ok;
  final String recoveryAckId;
  final bool duplicate;
  final String transcript;
  final Map<String, dynamic> reflection;
  final int durationSeconds;
  final int frameCount;

  Map<String, dynamic> toJson() => _$LiveAudioRecoverResponseDtoToJson(this);
}
