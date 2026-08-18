import 'package:archiveme_mobile/core/copy_with_unset.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'journal_proof_data.freezed.dart';

/// Proof, evidence, and clinical biomarker data attached to a journal entry.
@Freezed(fromJson: false, toJson: false, copyWith: false)
abstract class JournalProofData with _$JournalProofData {
  const JournalProofData._();

  const factory JournalProofData({
    ImageEvidence? imageEvidence,
    CognitiveBiomarkers? biomarkers,
    String? parentHookId,
    @Default(false) bool wasGrounded,
    VerifiedProof? verifiedProof,
  }) = _JournalProofData;

  factory JournalProofData.fromJson(Map<String, dynamic> json) {
    final proofJson = json['verifiedProof'];
    final verifiedProof = proofJson is Map
        ? VerifiedProof.fromJson(Map<String, dynamic>.from(proofJson))
        : null;
    return JournalProofData(
      imageEvidence: json['imageEvidence'] is Map<String, dynamic>
          ? ImageEvidence.fromJson(
              Map<String, dynamic>.from(json['imageEvidence'] as Map),
            )
          : null,
      biomarkers: CognitiveBiomarkers.fromJson(json['biomarkers']),
      parentHookId: json['parentHookId'] is String
          ? json['parentHookId'] as String
          : null,
      wasGrounded: json['wasGrounded'] == true,
      verifiedProof: verifiedProof,
    );
  }

  Map<String, dynamic> toJson() => {
    if (imageEvidence != null) 'imageEvidence': imageEvidence!.toJson(),
    if (biomarkers != null) 'biomarkers': biomarkers!.toJson(),
    if (parentHookId != null) 'parentHookId': parentHookId,
    if (wasGrounded) 'wasGrounded': true,
    if (verifiedProof != null) 'verifiedProof': verifiedProof!.toJson(),
  };

  JournalProofData copyWith({
    Object? imageEvidence = copyWithUnset,
    Object? biomarkers = copyWithUnset,
    Object? parentHookId = copyWithUnset,
    bool? wasGrounded,
    Object? verifiedProof = copyWithUnset,
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
  );
}
