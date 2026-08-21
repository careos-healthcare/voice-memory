import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:archiveme_mobile/models/encrypted_payload_dto.dart';
import 'package:json_annotation/json_annotation.dart';

export 'package:archiveme_mobile/models/encrypted_payload_dto.dart';

part 'sync_dto.g.dart';

@JsonSerializable(createFactory: false, explicitToJson: true)
class SyncBlobPushDto {
  const SyncBlobPushDto({
    required this.id,
    required this.type,
    required this.encrypted,
    required this.updatedAt,
    required this.byteLength,
    this.binding,
  });

  factory SyncBlobPushDto.fromJson(Map<String, dynamic> json) =>
      SyncBlobPushDto(
        id: JsonConverters.string(json['id'], field: 'id'),
        type: JsonConverters.string(json['type'], field: 'type'),
        encrypted: JsonConverters.requiredObject(
          json['encrypted'],
          EncryptedPayloadDto.fromJson,
          field: 'encrypted',
        ),
        updatedAt: JsonConverters.string(json['updatedAt'], field: 'updatedAt'),
        byteLength: JsonConverters.intValue(json['byteLength'], field: 'byteLength'),
        binding: JsonConverters.nullableString(json['binding']),
      );

  final String id;
  final String type;
  final EncryptedPayloadDto encrypted;
  final String updatedAt;
  final int byteLength;
  final String? binding;

  Map<String, dynamic> toJson() => _$SyncBlobPushDtoToJson(this);
}

@JsonSerializable(createFactory: false, explicitToJson: true)
class SyncPushRequestDto {
  const SyncPushRequestDto({required this.blobs});

  factory SyncPushRequestDto.fromJson(Map<String, dynamic> json) =>
      SyncPushRequestDto(
        blobs: JsonConverters.objectList(
          json['blobs'],
          SyncBlobPushDto.fromJson,
          field: 'blobs',
        ),
      );

  final List<SyncBlobPushDto> blobs;

  Map<String, dynamic> toJson() => _$SyncPushRequestDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class SyncManifestBlobSummaryDto {
  const SyncManifestBlobSummaryDto({
    required this.id,
    required this.type,
    required this.updatedAt,
    required this.byteLength,
  });

  factory SyncManifestBlobSummaryDto.fromJson(Map<String, dynamic> json) =>
      SyncManifestBlobSummaryDto(
        id: JsonConverters.string(json['id'], field: 'id'),
        type: JsonConverters.string(json['type'], field: 'type'),
        updatedAt: JsonConverters.string(json['updatedAt'], field: 'updatedAt'),
        byteLength: JsonConverters.intValue(json['byteLength'], field: 'byteLength'),
      );

  final String id;
  final String type;
  final String updatedAt;
  final int byteLength;

  Map<String, dynamic> toJson() => _$SyncManifestBlobSummaryDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class SyncManifestDto {
  const SyncManifestDto({
    required this.userId,
    required this.version,
    required this.updatedAt,
    required this.latestSequence,
    required this.blobs,
  });

  factory SyncManifestDto.fromJson(Map<String, dynamic> json) => SyncManifestDto(
        userId: JsonConverters.string(json['userId'], field: 'userId'),
        version: JsonConverters.intValue(json['version'], field: 'version'),
        updatedAt: JsonConverters.string(json['updatedAt'], field: 'updatedAt'),
        latestSequence: JsonConverters.intValue(
          json['latestSequence'],
          field: 'latestSequence',
        ),
        blobs: JsonConverters.objectList(
          json['blobs'],
          SyncManifestBlobSummaryDto.fromJson,
          field: 'blobs',
        ),
      );

  final String userId;
  final int version;
  final String updatedAt;
  final int latestSequence;
  final List<SyncManifestBlobSummaryDto> blobs;

  Map<String, dynamic> toJson() => _$SyncManifestDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class SyncPushResponseDto {
  const SyncPushResponseDto({required this.ok, required this.manifest});

  factory SyncPushResponseDto.fromJson(Map<String, dynamic> json) =>
      SyncPushResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        manifest: JsonConverters.requiredObject(
          json['manifest'],
          SyncManifestDto.fromJson,
          field: 'manifest',
        ),
      );

  final bool ok;
  final SyncManifestDto manifest;

  Map<String, dynamic> toJson() => _$SyncPushResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false)
class SyncManifestResponseDto {
  const SyncManifestResponseDto({required this.ok, required this.manifest});

  factory SyncManifestResponseDto.fromJson(Map<String, dynamic> json) =>
      SyncManifestResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        manifest: JsonConverters.requiredObject(
          json['manifest'],
          SyncManifestDto.fromJson,
          field: 'manifest',
        ),
      );

  final bool ok;
  final SyncManifestDto manifest;

  Map<String, dynamic> toJson() => _$SyncManifestResponseDtoToJson(this);
}

@JsonSerializable(createFactory: false, explicitToJson: true)
class SyncBlobRecordDto {
  const SyncBlobRecordDto({
    required this.id,
    required this.type,
    required this.encrypted,
    required this.updatedAt,
    required this.byteLength,
  });

  factory SyncBlobRecordDto.fromJson(Map<String, dynamic> json) =>
      SyncBlobRecordDto(
        id: JsonConverters.string(json['id'], field: 'id'),
        type: JsonConverters.string(json['type'], field: 'type'),
        encrypted: JsonConverters.requiredObject(
          json['encrypted'],
          EncryptedPayloadDto.fromJson,
          field: 'encrypted',
        ),
        updatedAt: JsonConverters.string(json['updatedAt'], field: 'updatedAt'),
        byteLength: JsonConverters.intValue(json['byteLength'], field: 'byteLength'),
      );

  final String id;
  final String type;
  final EncryptedPayloadDto encrypted;
  final String updatedAt;
  final int byteLength;

  Map<String, dynamic> toJson() => _$SyncBlobRecordDtoToJson(this);

  Map<String, dynamic> toEncryptedSyncMap() => {
        'id': id,
        'type': type,
        'encrypted': encrypted.toJson(),
        'updatedAt': updatedAt,
        'byteLength': byteLength,
      };
}

@JsonSerializable(createFactory: false, explicitToJson: true)
class SyncPullResponseDto {
  const SyncPullResponseDto({required this.ok, required this.blobs});

  factory SyncPullResponseDto.fromJson(Map<String, dynamic> json) =>
      SyncPullResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        blobs: JsonConverters.objectList(
          json['blobs'],
          SyncBlobRecordDto.fromJson,
          field: 'blobs',
        ),
      );

  final bool ok;
  final List<SyncBlobRecordDto> blobs;

  Map<String, dynamic> toJson() => _$SyncPullResponseDtoToJson(this);

  List<Map<String, dynamic>> blobMaps() =>
      blobs.map((blob) => blob.toEncryptedSyncMap()).toList();
}

@JsonSerializable(createFactory: false)
class SyncChangeRecordDto {
  const SyncChangeRecordDto({
    required this.sequence,
    required this.blobType,
    required this.blobId,
    required this.changeKind,
    required this.updatedAt,
    required this.tombstone,
  });

  factory SyncChangeRecordDto.fromJson(Map<String, dynamic> json) =>
      SyncChangeRecordDto(
        sequence: JsonConverters.intValue(json['sequence'], field: 'sequence'),
        blobType: JsonConverters.string(json['blobType'], field: 'blobType'),
        blobId: JsonConverters.string(json['blobId'], field: 'blobId'),
        changeKind:
            JsonConverters.string(json['changeKind'], field: 'changeKind'),
        updatedAt: JsonConverters.string(json['updatedAt'], field: 'updatedAt'),
        tombstone: JsonConverters.boolValue(json['tombstone'], field: 'tombstone'),
      );

  final int sequence;
  final String blobType;
  final String blobId;
  final String changeKind;
  final String updatedAt;
  final bool tombstone;

  Map<String, dynamic> toJson() => _$SyncChangeRecordDtoToJson(this);
}

@JsonSerializable(createFactory: false, explicitToJson: true)
class SyncChangesResponseDto {
  const SyncChangesResponseDto({
    required this.ok,
    required this.latestSequence,
    required this.changes,
    required this.blobs,
  });

  factory SyncChangesResponseDto.fromJson(Map<String, dynamic> json) =>
      SyncChangesResponseDto(
        ok: JsonConverters.boolValue(json['ok'], field: 'ok'),
        latestSequence: JsonConverters.intValue(
          json['latestSequence'],
          field: 'latestSequence',
        ),
        changes: JsonConverters.objectList(
          json['changes'],
          SyncChangeRecordDto.fromJson,
          field: 'changes',
        ),
        blobs: JsonConverters.objectList(
          json['blobs'],
          SyncBlobRecordDto.fromJson,
          field: 'blobs',
        ),
      );

  final bool ok;
  final int latestSequence;
  final List<SyncChangeRecordDto> changes;
  final List<SyncBlobRecordDto> blobs;

  Map<String, dynamic> toJson() => _$SyncChangesResponseDtoToJson(this);

  List<Map<String, dynamic>> blobMaps() =>
      blobs.map((blob) => blob.toEncryptedSyncMap()).toList();
}
