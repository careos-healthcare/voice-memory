/// Wire-format encrypted blob for sync APIs — AES-GCM ciphertext + IV.
///
/// Matches server `encryptJsonPayload` envelopes (`ciphertext`, `iv`, `version`).
import 'package:archiveme_mobile/core/json/json_converters.dart';

class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.iv,
    this.version = 1,
  });

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      ciphertext: JsonConverters.stringOrEmpty(json['ciphertext']),
      iv: JsonConverters.stringOrEmpty(json['iv']),
      version: JsonConverters.nullableInt(json['version']) ?? 1,
    );
  }

  final String ciphertext;
  final String iv;
  final int version;

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertext,
        'iv': iv,
        'version': version,
      };
}

class EncryptedPayloadDto {
  const EncryptedPayloadDto({
    required this.ciphertext,
    required this.iv,
    this.version = 1,
  });

  factory EncryptedPayloadDto.fromJson(Map<String, dynamic> json) {
    return EncryptedPayloadDto(
      ciphertext: JsonConverters.stringOrEmpty(json['ciphertext']),
      iv: JsonConverters.stringOrEmpty(json['iv']),
      version: JsonConverters.nullableInt(json['version']) ?? 1,
    );
  }

  final String ciphertext;
  final String iv;
  final int version;

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertext,
        'iv': iv,
        'version': version,
      };

  EncryptedPayload toDomain() => EncryptedPayload(
        ciphertext: ciphertext,
        iv: iv,
        version: version,
      );

  factory EncryptedPayloadDto.fromDomain(EncryptedPayload payload) =>
      EncryptedPayloadDto(
        ciphertext: payload.ciphertext,
        iv: payload.iv,
        version: payload.version,
      );
}
