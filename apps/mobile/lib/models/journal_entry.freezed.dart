// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JournalEntry {

 String get id; DateTime get createdAt; String get transcript; int get durationSeconds; Reflection get reflection; String? get localAudioPath; TranscriptStatus get transcriptStatus; TranscriptProvenance get transcriptProvenance; String? get ownerKey; JournalSyncMetadata get sync; JournalDisplayMetadata get display; JournalProofData get proof;







}




/// Adds pattern-matching-related methods to [JournalEntry].
extension JournalEntryPatterns on JournalEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _JournalEntry value)?  stored,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JournalEntry() when stored != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _JournalEntry value)  stored,}){
final _that = this;
switch (_that) {
case _JournalEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _JournalEntry value)?  stored,}){
final _that = this;
switch (_that) {
case _JournalEntry() when stored != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  DateTime createdAt,  String transcript,  int durationSeconds,  Reflection reflection,  String? localAudioPath,  TranscriptStatus transcriptStatus,  TranscriptProvenance transcriptProvenance,  String? ownerKey,  JournalSyncMetadata sync,  JournalDisplayMetadata display,  JournalProofData proof)?  stored,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JournalEntry() when stored != null:
return stored(_that.id,_that.createdAt,_that.transcript,_that.durationSeconds,_that.reflection,_that.localAudioPath,_that.transcriptStatus,_that.transcriptProvenance,_that.ownerKey,_that.sync,_that.display,_that.proof);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  DateTime createdAt,  String transcript,  int durationSeconds,  Reflection reflection,  String? localAudioPath,  TranscriptStatus transcriptStatus,  TranscriptProvenance transcriptProvenance,  String? ownerKey,  JournalSyncMetadata sync,  JournalDisplayMetadata display,  JournalProofData proof)  stored,}) {final _that = this;
switch (_that) {
case _JournalEntry():
return stored(_that.id,_that.createdAt,_that.transcript,_that.durationSeconds,_that.reflection,_that.localAudioPath,_that.transcriptStatus,_that.transcriptProvenance,_that.ownerKey,_that.sync,_that.display,_that.proof);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  DateTime createdAt,  String transcript,  int durationSeconds,  Reflection reflection,  String? localAudioPath,  TranscriptStatus transcriptStatus,  TranscriptProvenance transcriptProvenance,  String? ownerKey,  JournalSyncMetadata sync,  JournalDisplayMetadata display,  JournalProofData proof)?  stored,}) {final _that = this;
switch (_that) {
case _JournalEntry() when stored != null:
return stored(_that.id,_that.createdAt,_that.transcript,_that.durationSeconds,_that.reflection,_that.localAudioPath,_that.transcriptStatus,_that.transcriptProvenance,_that.ownerKey,_that.sync,_that.display,_that.proof);case _:
  return null;

}
}

}

/// @nodoc


class _JournalEntry extends JournalEntry {
  const _JournalEntry({required this.id, required this.createdAt, required this.transcript, required this.durationSeconds, required this.reflection, this.localAudioPath, this.transcriptStatus = TranscriptStatus.finalTranscript, this.transcriptProvenance = TranscriptProvenance.unknownLegacy, this.ownerKey, required this.sync, required this.display, required this.proof}): super._();
  

@override final  String id;
@override final  DateTime createdAt;
@override final  String transcript;
@override final  int durationSeconds;
@override final  Reflection reflection;
@override final  String? localAudioPath;
@override@JsonKey() final  TranscriptStatus transcriptStatus;
@override@JsonKey() final  TranscriptProvenance transcriptProvenance;
@override final  String? ownerKey;
@override final  JournalSyncMetadata sync;
@override final  JournalDisplayMetadata display;
@override final  JournalProofData proof;








}




// dart format on
