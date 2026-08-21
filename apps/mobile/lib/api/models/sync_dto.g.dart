// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$SyncBlobPushDtoToJson(SyncBlobPushDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'encrypted': instance.encrypted.toJson(),
      'updatedAt': instance.updatedAt,
      'byteLength': instance.byteLength,
      'binding': instance.binding,
    };

Map<String, dynamic> _$SyncPushRequestDtoToJson(SyncPushRequestDto instance) =>
    <String, dynamic>{'blobs': instance.blobs.map((e) => e.toJson()).toList()};

Map<String, dynamic> _$SyncManifestBlobSummaryDtoToJson(
  SyncManifestBlobSummaryDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'updatedAt': instance.updatedAt,
  'byteLength': instance.byteLength,
};

Map<String, dynamic> _$SyncManifestDtoToJson(SyncManifestDto instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'version': instance.version,
      'updatedAt': instance.updatedAt,
      'latestSequence': instance.latestSequence,
      'blobs': instance.blobs,
    };

Map<String, dynamic> _$SyncPushResponseDtoToJson(
  SyncPushResponseDto instance,
) => <String, dynamic>{'ok': instance.ok, 'manifest': instance.manifest};

Map<String, dynamic> _$SyncManifestResponseDtoToJson(
  SyncManifestResponseDto instance,
) => <String, dynamic>{'ok': instance.ok, 'manifest': instance.manifest};

Map<String, dynamic> _$SyncBlobRecordDtoToJson(SyncBlobRecordDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'encrypted': instance.encrypted.toJson(),
      'updatedAt': instance.updatedAt,
      'byteLength': instance.byteLength,
    };

Map<String, dynamic> _$SyncPullResponseDtoToJson(
  SyncPullResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'blobs': instance.blobs.map((e) => e.toJson()).toList(),
};

Map<String, dynamic> _$SyncChangeRecordDtoToJson(
  SyncChangeRecordDto instance,
) => <String, dynamic>{
  'sequence': instance.sequence,
  'blobType': instance.blobType,
  'blobId': instance.blobId,
  'changeKind': instance.changeKind,
  'updatedAt': instance.updatedAt,
  'tombstone': instance.tombstone,
};

Map<String, dynamic> _$SyncChangesResponseDtoToJson(
  SyncChangesResponseDto instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'latestSequence': instance.latestSequence,
  'changes': instance.changes.map((e) => e.toJson()).toList(),
  'blobs': instance.blobs.map((e) => e.toJson()).toList(),
};
