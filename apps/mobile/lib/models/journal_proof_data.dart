import 'package:archiveme_mobile/core/copy_with_unset.dart';
import 'package:archiveme_mobile/core/json/json_converters.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'journal_proof_data.freezed.dart';

/// Proof, evidence, and clinical biomarker data attached to a journal entry.
@Freezed(fromJson: false, toJson: false, copyWith: false)
abstract class JournalProofData with _$JournalProofData {
  const JournalProofData._();

  static const _deepEquality = DeepCollectionEquality();

  const factory JournalProofData({
    ImageEvidence? imageEvidence,
    CognitiveBiomarkers? biomarkers,
    String? parentHookId,
    @Default(false) bool wasGrounded,
    VerifiedProof? verifiedProof,
    bool? processingUsedOnnx,
    bool? processingUsedLocalStt,
    bool? processingUsedGenerativeLlm,
  }) = _JournalProofData;

  factory JournalProofData.fromJson(Map<String, dynamic> json) {
    return JournalProofData(
      imageEvidence: JsonConverters.nullableObject(
        json['imageEvidence'],
        ImageEvidence.fromJson,
      ),
      biomarkers: CognitiveBiomarkers.fromJson(json['biomarkers']),
      parentHookId: JsonConverters.nullableString(json['parentHookId']),
      wasGrounded: json['wasGrounded'] == true,
      verifiedProof: JsonConverters.nullableObject(
        json['verifiedProof'],
        VerifiedProof.fromJson,
      ),
      processingUsedOnnx: json['processingUsedOnnx'] as bool?,
      processingUsedLocalStt: json['processingUsedLocalStt'] as bool?,
      processingUsedGenerativeLlm: json['processingUsedGenerativeLlm'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (imageEvidence != null) 'imageEvidence': imageEvidence!.toJson(),
    if (biomarkers != null) 'biomarkers': biomarkers!.toJson(),
    if (parentHookId != null) 'parentHookId': parentHookId,
    if (wasGrounded) 'wasGrounded': true,
    if (verifiedProof != null) 'verifiedProof': verifiedProof!.toJson(),
    if (processingUsedOnnx != null) 'processingUsedOnnx': processingUsedOnnx,
    if (processingUsedLocalStt != null)
      'processingUsedLocalStt': processingUsedLocalStt,
    if (processingUsedGenerativeLlm != null)
      'processingUsedGenerativeLlm': processingUsedGenerativeLlm,
  };

  JournalProofData copyWith({
    Object? imageEvidence = copyWithUnset,
    Object? biomarkers = copyWithUnset,
    Object? parentHookId = copyWithUnset,
    bool? wasGrounded,
    Object? verifiedProof = copyWithUnset,
    Object? processingUsedOnnx = copyWithUnset,
    Object? processingUsedLocalStt = copyWithUnset,
    Object? processingUsedGenerativeLlm = copyWithUnset,
  }) => JournalProofData(
    imageEvidence: identical(imageEvidence, copyWithUnset)
        ? this.imageEvidence
        : imageEvidence as ImageEvidence?,
    biomarkers: identical(biomarkers, copyWithUnset)
        ? this.biomarkers
        : biomarkers as CognitiveBiomarkers?,
    parentHookId: identical(parentHookId, copyWithUnset)
        ? this.parentHookId
        : parentHookId as String?,
    wasGrounded: wasGrounded ?? this.wasGrounded,
    verifiedProof: identical(verifiedProof, copyWithUnset)
        ? this.verifiedProof
        : verifiedProof as VerifiedProof?,
    processingUsedOnnx: identical(processingUsedOnnx, copyWithUnset)
        ? this.processingUsedOnnx
        : processingUsedOnnx as bool?,
    processingUsedLocalStt: identical(processingUsedLocalStt, copyWithUnset)
        ? this.processingUsedLocalStt
        : processingUsedLocalStt as bool?,
    processingUsedGenerativeLlm: identical(processingUsedGenerativeLlm, copyWithUnset)
        ? this.processingUsedGenerativeLlm
        : processingUsedGenerativeLlm as bool?,
  );

  static bool _verifiedProofsEqual(VerifiedProof? a, VerifiedProof? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return _deepEquality.equals(a.toJson(), b.toJson());
  }

  static int _verifiedProofHash(VerifiedProof? proof) =>
      proof == null ? 0 : _deepEquality.hash(proof.toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalProofData &&
          other.imageEvidence == imageEvidence &&
          other.biomarkers == biomarkers &&
          other.parentHookId == parentHookId &&
          other.wasGrounded == wasGrounded &&
          _verifiedProofsEqual(other.verifiedProof, verifiedProof) &&
          other.processingUsedOnnx == processingUsedOnnx &&
          other.processingUsedLocalStt == processingUsedLocalStt &&
          other.processingUsedGenerativeLlm == processingUsedGenerativeLlm;

  @override
  int get hashCode => Object.hash(
        imageEvidence,
        biomarkers,
        parentHookId,
        wasGrounded,
        _verifiedProofHash(verifiedProof),
        processingUsedOnnx,
        processingUsedLocalStt,
        processingUsedGenerativeLlm,
      );
}
