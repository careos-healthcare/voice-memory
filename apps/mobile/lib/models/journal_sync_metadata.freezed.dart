// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_sync_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JournalSyncMetadata {

 SyncStatus get syncStatus; DateTime get updatedAt; int get revision; String get changeId; DateTime? get deletedAt; int get schemaVersion;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalSyncMetadata&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.changeId, changeId) || other.changeId == changeId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}


@override
int get hashCode => Object.hash(runtimeType,syncStatus,updatedAt,revision,changeId,deletedAt,schemaVersion);

@override
String toString() {
  return 'JournalSyncMetadata(syncStatus: $syncStatus, updatedAt: $updatedAt, revision: $revision, changeId: $changeId, deletedAt: $deletedAt, schemaVersion: $schemaVersion)';
}


}




/// Adds pattern-matching-related methods to [JournalSyncMetadata].
extension JournalSyncMetadataPatterns on JournalSyncMetadata {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _JournalSyncMetadata value)?  stored,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JournalSyncMetadata() when stored != null:
return stored(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _JournalSyncMetadata value)  stored,}){
final _that = this;
switch (_that) {
case _JournalSyncMetadata():
return stored(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _JournalSyncMetadata value)?  stored,}){
final _that = this;
switch (_that) {
case _JournalSyncMetadata() when stored != null:
return stored(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( SyncStatus syncStatus,  DateTime updatedAt,  int revision,  String changeId,  DateTime? deletedAt,  int schemaVersion)?  stored,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JournalSyncMetadata() when stored != null:
return stored(_that.syncStatus,_that.updatedAt,_that.revision,_that.changeId,_that.deletedAt,_that.schemaVersion);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( SyncStatus syncStatus,  DateTime updatedAt,  int revision,  String changeId,  DateTime? deletedAt,  int schemaVersion)  stored,}) {final _that = this;
switch (_that) {
case _JournalSyncMetadata():
return stored(_that.syncStatus,_that.updatedAt,_that.revision,_that.changeId,_that.deletedAt,_that.schemaVersion);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( SyncStatus syncStatus,  DateTime updatedAt,  int revision,  String changeId,  DateTime? deletedAt,  int schemaVersion)?  stored,}) {final _that = this;
switch (_that) {
case _JournalSyncMetadata() when stored != null:
return stored(_that.syncStatus,_that.updatedAt,_that.revision,_that.changeId,_that.deletedAt,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc


class _JournalSyncMetadata extends JournalSyncMetadata {
  const _JournalSyncMetadata({this.syncStatus = SyncStatus.localOnly, required this.updatedAt, required this.revision, required this.changeId, this.deletedAt, this.schemaVersion = JournalSyncMetadata.currentSchemaVersion}): super._();
  

@override@JsonKey() final  SyncStatus syncStatus;
@override final  DateTime updatedAt;
@override final  int revision;
@override final  String changeId;
@override final  DateTime? deletedAt;
@override@JsonKey() final  int schemaVersion;




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JournalSyncMetadata&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.changeId, changeId) || other.changeId == changeId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}


@override
int get hashCode => Object.hash(runtimeType,syncStatus,updatedAt,revision,changeId,deletedAt,schemaVersion);

@override
String toString() {
  return 'JournalSyncMetadata.stored(syncStatus: $syncStatus, updatedAt: $updatedAt, revision: $revision, changeId: $changeId, deletedAt: $deletedAt, schemaVersion: $schemaVersion)';
}


}




// dart format on
