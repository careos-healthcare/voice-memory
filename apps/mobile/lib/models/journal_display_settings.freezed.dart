// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_display_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JournalDisplaySettings {

 bool get treatAsNew; bool get connectionApproved; bool get keepExactDetails; bool get keepSeparate; String? get archiveThreadId; String? get archivePackId; bool get isPinned; DateTime? get pinnedAt; bool get isArchived; DateTime? get archivedAt; String get entryAboutness; String get memorySurfacing; bool get preserveOriginal; String? get captureContextTag; String? get captureSource;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalDisplaySettings&&(identical(other.treatAsNew, treatAsNew) || other.treatAsNew == treatAsNew)&&(identical(other.connectionApproved, connectionApproved) || other.connectionApproved == connectionApproved)&&(identical(other.keepExactDetails, keepExactDetails) || other.keepExactDetails == keepExactDetails)&&(identical(other.keepSeparate, keepSeparate) || other.keepSeparate == keepSeparate)&&(identical(other.archiveThreadId, archiveThreadId) || other.archiveThreadId == archiveThreadId)&&(identical(other.archivePackId, archivePackId) || other.archivePackId == archivePackId)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.entryAboutness, entryAboutness) || other.entryAboutness == entryAboutness)&&(identical(other.memorySurfacing, memorySurfacing) || other.memorySurfacing == memorySurfacing)&&(identical(other.preserveOriginal, preserveOriginal) || other.preserveOriginal == preserveOriginal)&&(identical(other.captureContextTag, captureContextTag) || other.captureContextTag == captureContextTag)&&(identical(other.captureSource, captureSource) || other.captureSource == captureSource));
}


@override
int get hashCode => Object.hash(runtimeType,treatAsNew,connectionApproved,keepExactDetails,keepSeparate,archiveThreadId,archivePackId,isPinned,pinnedAt,isArchived,archivedAt,entryAboutness,memorySurfacing,preserveOriginal,captureContextTag,captureSource);

@override
String toString() {
  return 'JournalDisplaySettings(treatAsNew: $treatAsNew, connectionApproved: $connectionApproved, keepExactDetails: $keepExactDetails, keepSeparate: $keepSeparate, archiveThreadId: $archiveThreadId, archivePackId: $archivePackId, isPinned: $isPinned, pinnedAt: $pinnedAt, isArchived: $isArchived, archivedAt: $archivedAt, entryAboutness: $entryAboutness, memorySurfacing: $memorySurfacing, preserveOriginal: $preserveOriginal, captureContextTag: $captureContextTag, captureSource: $captureSource)';
}


}




/// Adds pattern-matching-related methods to [JournalDisplaySettings].
extension JournalDisplaySettingsPatterns on JournalDisplaySettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JournalDisplaySettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JournalDisplaySettings() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JournalDisplaySettings value)  $default,){
final _that = this;
switch (_that) {
case _JournalDisplaySettings():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JournalDisplaySettings value)?  $default,){
final _that = this;
switch (_that) {
case _JournalDisplaySettings() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool treatAsNew,  bool connectionApproved,  bool keepExactDetails,  bool keepSeparate,  String? archiveThreadId,  String? archivePackId,  bool isPinned,  DateTime? pinnedAt,  bool isArchived,  DateTime? archivedAt,  String entryAboutness,  String memorySurfacing,  bool preserveOriginal,  String? captureContextTag,  String? captureSource)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JournalDisplaySettings() when $default != null:
return $default(_that.treatAsNew,_that.connectionApproved,_that.keepExactDetails,_that.keepSeparate,_that.archiveThreadId,_that.archivePackId,_that.isPinned,_that.pinnedAt,_that.isArchived,_that.archivedAt,_that.entryAboutness,_that.memorySurfacing,_that.preserveOriginal,_that.captureContextTag,_that.captureSource);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool treatAsNew,  bool connectionApproved,  bool keepExactDetails,  bool keepSeparate,  String? archiveThreadId,  String? archivePackId,  bool isPinned,  DateTime? pinnedAt,  bool isArchived,  DateTime? archivedAt,  String entryAboutness,  String memorySurfacing,  bool preserveOriginal,  String? captureContextTag,  String? captureSource)  $default,) {final _that = this;
switch (_that) {
case _JournalDisplaySettings():
return $default(_that.treatAsNew,_that.connectionApproved,_that.keepExactDetails,_that.keepSeparate,_that.archiveThreadId,_that.archivePackId,_that.isPinned,_that.pinnedAt,_that.isArchived,_that.archivedAt,_that.entryAboutness,_that.memorySurfacing,_that.preserveOriginal,_that.captureContextTag,_that.captureSource);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool treatAsNew,  bool connectionApproved,  bool keepExactDetails,  bool keepSeparate,  String? archiveThreadId,  String? archivePackId,  bool isPinned,  DateTime? pinnedAt,  bool isArchived,  DateTime? archivedAt,  String entryAboutness,  String memorySurfacing,  bool preserveOriginal,  String? captureContextTag,  String? captureSource)?  $default,) {final _that = this;
switch (_that) {
case _JournalDisplaySettings() when $default != null:
return $default(_that.treatAsNew,_that.connectionApproved,_that.keepExactDetails,_that.keepSeparate,_that.archiveThreadId,_that.archivePackId,_that.isPinned,_that.pinnedAt,_that.isArchived,_that.archivedAt,_that.entryAboutness,_that.memorySurfacing,_that.preserveOriginal,_that.captureContextTag,_that.captureSource);case _:
  return null;

}
}

}

/// @nodoc


class _JournalDisplaySettings extends JournalDisplaySettings {
  const _JournalDisplaySettings({this.treatAsNew = false, this.connectionApproved = false, this.keepExactDetails = false, this.keepSeparate = false, this.archiveThreadId, this.archivePackId, this.isPinned = false, this.pinnedAt, this.isArchived = false, this.archivedAt, this.entryAboutness = 'about_me', this.memorySurfacing = 'normal', this.preserveOriginal = false, this.captureContextTag, this.captureSource}): super._();
  

@override@JsonKey() final  bool treatAsNew;
@override@JsonKey() final  bool connectionApproved;
@override@JsonKey() final  bool keepExactDetails;
@override@JsonKey() final  bool keepSeparate;
@override final  String? archiveThreadId;
@override final  String? archivePackId;
@override@JsonKey() final  bool isPinned;
@override final  DateTime? pinnedAt;
@override@JsonKey() final  bool isArchived;
@override final  DateTime? archivedAt;
@override@JsonKey() final  String entryAboutness;
@override@JsonKey() final  String memorySurfacing;
@override@JsonKey() final  bool preserveOriginal;
@override final  String? captureContextTag;
@override final  String? captureSource;




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JournalDisplaySettings&&(identical(other.treatAsNew, treatAsNew) || other.treatAsNew == treatAsNew)&&(identical(other.connectionApproved, connectionApproved) || other.connectionApproved == connectionApproved)&&(identical(other.keepExactDetails, keepExactDetails) || other.keepExactDetails == keepExactDetails)&&(identical(other.keepSeparate, keepSeparate) || other.keepSeparate == keepSeparate)&&(identical(other.archiveThreadId, archiveThreadId) || other.archiveThreadId == archiveThreadId)&&(identical(other.archivePackId, archivePackId) || other.archivePackId == archivePackId)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.pinnedAt, pinnedAt) || other.pinnedAt == pinnedAt)&&(identical(other.isArchived, isArchived) || other.isArchived == isArchived)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.entryAboutness, entryAboutness) || other.entryAboutness == entryAboutness)&&(identical(other.memorySurfacing, memorySurfacing) || other.memorySurfacing == memorySurfacing)&&(identical(other.preserveOriginal, preserveOriginal) || other.preserveOriginal == preserveOriginal)&&(identical(other.captureContextTag, captureContextTag) || other.captureContextTag == captureContextTag)&&(identical(other.captureSource, captureSource) || other.captureSource == captureSource));
}


@override
int get hashCode => Object.hash(runtimeType,treatAsNew,connectionApproved,keepExactDetails,keepSeparate,archiveThreadId,archivePackId,isPinned,pinnedAt,isArchived,archivedAt,entryAboutness,memorySurfacing,preserveOriginal,captureContextTag,captureSource);

@override
String toString() {
  return 'JournalDisplaySettings(treatAsNew: $treatAsNew, connectionApproved: $connectionApproved, keepExactDetails: $keepExactDetails, keepSeparate: $keepSeparate, archiveThreadId: $archiveThreadId, archivePackId: $archivePackId, isPinned: $isPinned, pinnedAt: $pinnedAt, isArchived: $isArchived, archivedAt: $archivedAt, entryAboutness: $entryAboutness, memorySurfacing: $memorySurfacing, preserveOriginal: $preserveOriginal, captureContextTag: $captureContextTag, captureSource: $captureSource)';
}


}




// dart format on
