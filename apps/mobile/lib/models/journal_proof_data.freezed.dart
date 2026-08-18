// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journal_proof_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JournalProofData {

 ImageEvidence? get imageEvidence; CognitiveBiomarkers? get biomarkers; String? get parentHookId; bool get wasGrounded; VerifiedProof? get verifiedProof;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalProofData&&(identical(other.imageEvidence, imageEvidence) || other.imageEvidence == imageEvidence)&&(identical(other.biomarkers, biomarkers) || other.biomarkers == biomarkers)&&(identical(other.parentHookId, parentHookId) || other.parentHookId == parentHookId)&&(identical(other.wasGrounded, wasGrounded) || other.wasGrounded == wasGrounded)&&(identical(other.verifiedProof, verifiedProof) || other.verifiedProof == verifiedProof));
}


@override
int get hashCode => Object.hash(runtimeType,imageEvidence,biomarkers,parentHookId,wasGrounded,verifiedProof);

@override
String toString() {
  return 'JournalProofData(imageEvidence: $imageEvidence, biomarkers: $biomarkers, parentHookId: $parentHookId, wasGrounded: $wasGrounded, verifiedProof: $verifiedProof)';
}


}




/// Adds pattern-matching-related methods to [JournalProofData].
extension JournalProofDataPatterns on JournalProofData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JournalProofData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JournalProofData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JournalProofData value)  $default,){
final _that = this;
switch (_that) {
case _JournalProofData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JournalProofData value)?  $default,){
final _that = this;
switch (_that) {
case _JournalProofData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ImageEvidence? imageEvidence,  CognitiveBiomarkers? biomarkers,  String? parentHookId,  bool wasGrounded,  VerifiedProof? verifiedProof)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JournalProofData() when $default != null:
return $default(_that.imageEvidence,_that.biomarkers,_that.parentHookId,_that.wasGrounded,_that.verifiedProof);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ImageEvidence? imageEvidence,  CognitiveBiomarkers? biomarkers,  String? parentHookId,  bool wasGrounded,  VerifiedProof? verifiedProof)  $default,) {final _that = this;
switch (_that) {
case _JournalProofData():
return $default(_that.imageEvidence,_that.biomarkers,_that.parentHookId,_that.wasGrounded,_that.verifiedProof);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ImageEvidence? imageEvidence,  CognitiveBiomarkers? biomarkers,  String? parentHookId,  bool wasGrounded,  VerifiedProof? verifiedProof)?  $default,) {final _that = this;
switch (_that) {
case _JournalProofData() when $default != null:
return $default(_that.imageEvidence,_that.biomarkers,_that.parentHookId,_that.wasGrounded,_that.verifiedProof);case _:
  return null;

}
}

}

/// @nodoc


class _JournalProofData extends JournalProofData {
  const _JournalProofData({this.imageEvidence, this.biomarkers, this.parentHookId, this.wasGrounded = false, this.verifiedProof}): super._();
  

@override final  ImageEvidence? imageEvidence;
@override final  CognitiveBiomarkers? biomarkers;
@override final  String? parentHookId;
@override@JsonKey() final  bool wasGrounded;
@override final  VerifiedProof? verifiedProof;




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JournalProofData&&(identical(other.imageEvidence, imageEvidence) || other.imageEvidence == imageEvidence)&&(identical(other.biomarkers, biomarkers) || other.biomarkers == biomarkers)&&(identical(other.parentHookId, parentHookId) || other.parentHookId == parentHookId)&&(identical(other.wasGrounded, wasGrounded) || other.wasGrounded == wasGrounded)&&(identical(other.verifiedProof, verifiedProof) || other.verifiedProof == verifiedProof));
}


@override
int get hashCode => Object.hash(runtimeType,imageEvidence,biomarkers,parentHookId,wasGrounded,verifiedProof);

@override
String toString() {
  return 'JournalProofData(imageEvidence: $imageEvidence, biomarkers: $biomarkers, parentHookId: $parentHookId, wasGrounded: $wasGrounded, verifiedProof: $verifiedProof)';
}


}




// dart format on
