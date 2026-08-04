import 'archive_correction.dart';

/// Structural values supplied by the caller while migrating legacy JSON.
///
/// Legacy feedback did not carry all canonical correction fields, so migration
/// is only possible when the caller can safely identify the archive and proof.
class ArchiveCorrectionMigrationSeed {
  const ArchiveCorrectionMigrationSeed({
    required this.correctionId,
    required this.archiveScope,
    required this.targetProofId,
    required this.targetProofFingerprint,
    required this.semanticFramingFingerprint,
    required this.wordingFingerprint,
    required this.affectedEvidenceRefs,
    required this.createdAt,
    required this.sourceSurface,
  });

  final String correctionId;
  final String archiveScope;
  final String targetProofId;
  final String targetProofFingerprint;
  final String semanticFramingFingerprint;
  final String wordingFingerprint;
  final List<String> affectedEvidenceRefs;
  final DateTime createdAt;
  final String sourceSurface;
}

abstract final class ArchiveCorrectionMigration {
  ArchiveCorrectionMigration._();

  /// Migrates the JSON representation of `InsightFeedbackChoice`.
  ///
  /// `saveAsWatchTheme` returns null because it is a curation action, not a
  /// statement about proof correctness.
  static ArchiveCorrection? fromInsightFeedbackJson(
    Map<String, dynamic> json, {
    required ArchiveCorrectionMigrationSeed seed,
  }) {
    final raw = json['choice'];
    final mapping = switch (raw) {
      'fits' => const _ChoiceMapping(ArchiveCorrectionChoice.exactlyRight),
      'notQuite' => const _ChoiceMapping(ArchiveCorrectionChoice.partlyRight),
      'tooEarly' => const _ChoiceMapping(
        ArchiveCorrectionChoice.partlyRight,
        ArchiveCorrectionQualifier.tooEarly,
      ),
      _ => null,
    };
    return mapping == null ? null : _build(seed, mapping, json);
  }

  /// Migrates active proof-quality feedback JSON where it has correction
  /// semantics. Unknown states and non-correction states return null.
  static ArchiveCorrection? fromProofQualityJson(
    Map<String, dynamic> json, {
    required ArchiveCorrectionMigrationSeed seed,
  }) {
    final raw = json['feedbackState'] ?? json['feedback'];
    final mapping = switch (raw) {
      'useful' => const _ChoiceMapping(ArchiveCorrectionChoice.exactlyRight),
      'tooVague' ||
      'too_vague' => const _ChoiceMapping(ArchiveCorrectionChoice.wrongWording),
      'notRelevant' || 'not_relevant' => const _ChoiceMapping(
        ArchiveCorrectionChoice.wrongEvidence,
      ),
      _ => null,
    };
    return mapping == null ? null : _build(seed, mapping, json);
  }

  static ArchiveCorrection _build(
    ArchiveCorrectionMigrationSeed seed,
    _ChoiceMapping mapping,
    Map<String, dynamic> json,
  ) {
    final createdAt = _legacyTimestamp(json) ?? seed.createdAt;
    return ArchiveCorrection(
      correctionId: seed.correctionId,
      archiveScope: seed.archiveScope,
      targetProofId: seed.targetProofId,
      targetProofFingerprint: seed.targetProofFingerprint,
      semanticFramingFingerprint: seed.semanticFramingFingerprint,
      wordingFingerprint: seed.wordingFingerprint,
      affectedEvidenceRefs: seed.affectedEvidenceRefs,
      choice: mapping.choice,
      qualifier: mapping.qualifier,
      createdAt: createdAt,
      updatedAt: createdAt,
      sourceSurface: seed.sourceSurface,
    );
  }

  static DateTime? _legacyTimestamp(Map<String, dynamic> json) {
    final raw = json['createdAt'] ?? json['answeredAt'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}

class _ChoiceMapping {
  const _ChoiceMapping(this.choice, [this.qualifier]);

  final ArchiveCorrectionChoice choice;
  final ArchiveCorrectionQualifier? qualifier;
}
