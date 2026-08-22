/// Versioned, archive-scoped feedback about an admitted proof.
///
/// This model intentionally contains structural metadata only. It has no field
/// for free-form notes or source content.
enum ArchiveCorrectionChoice {
  exactlyRight,
  partlyRight,
  wrong,
  wrongWording,
  wrongEvidence,
  ignoreForever,
}

/// Optional, closed-set context that refines a correction without storing text.
enum ArchiveCorrectionQualifier {
  tooEarly,
  lowConfidence,
  scopeTooBroad,
  scopeTooNarrow,
}

class ArchiveCorrection {
  const ArchiveCorrection({
    required this.correctionId,
    required this.archiveScope,
    required this.targetProofId,
    required this.targetProofFingerprint,
    required this.semanticFramingFingerprint,
    required this.wordingFingerprint,
    required this.affectedEvidenceRefs,
    required this.choice,
    required this.createdAt,
    required this.updatedAt,
    required this.sourceSurface,
    this.qualifier,
    this.disputedEvidenceRefs = const [],
    this.preferredWording,
    this.schemaVersion = currentSchemaVersion,
    this.superseded = false,
  });

  factory ArchiveCorrection.fromJson(Map<String, dynamic> json) {
    final createdAt = _dateTime(json['createdAt']);
    return ArchiveCorrection(
      correctionId: _string(json['correctionId']),
      archiveScope: _string(json['archiveScope']),
      targetProofId: _string(json['targetProofId']),
      targetProofFingerprint: _string(json['targetProofFingerprint']),
      semanticFramingFingerprint: _string(json['semanticFramingFingerprint']),
      wordingFingerprint: _string(json['wordingFingerprint']),
      affectedEvidenceRefs: _stringList(json['affectedEvidenceRefs']),
      disputedEvidenceRefs: _stringList(json['disputedEvidenceRefs']),
      preferredWording: json['preferredWording'] is String
          ? json['preferredWording'] as String
          : null,
      choice: _enumByName(
        ArchiveCorrectionChoice.values,
        json['choice'],
        ArchiveCorrectionChoice.partlyRight,
      ),
      qualifier: _nullableEnumByName(
        ArchiveCorrectionQualifier.values,
        json['qualifier'],
      ),
      createdAt: createdAt,
      updatedAt: _dateTime(json['updatedAt'], fallback: createdAt),
      sourceSurface: _string(json['sourceSurface']),
      schemaVersion: json['schemaVersion'] is int
          ? json['schemaVersion'] as int
          : currentSchemaVersion,
      superseded: json['superseded'] == true,
    );
  }

  static const currentSchemaVersion = 1;

  final String correctionId;
  final String archiveScope;
  final String targetProofId;
  final String targetProofFingerprint;
  final String semanticFramingFingerprint;
  final String wordingFingerprint;
  final List<String> affectedEvidenceRefs;

  /// The subset of [affectedEvidenceRefs] the user named as wrong evidence.
  /// Empty means the whole citation set was disputed.
  final List<String> disputedEvidenceRefs;

  /// A label the user chose in place of generated wording. It is the user's own
  /// words about their own archive: it stays archive-scoped, never reaches
  /// analytics or logs, and is never treated as evidence for anything.
  final String? preferredWording;

  final ArchiveCorrectionChoice choice;
  final ArchiveCorrectionQualifier? qualifier;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String sourceSurface;
  final int schemaVersion;
  final bool superseded;

  ArchiveCorrection copyWith({DateTime? updatedAt, bool? superseded}) {
    return ArchiveCorrection(
      correctionId: correctionId,
      archiveScope: archiveScope,
      targetProofId: targetProofId,
      targetProofFingerprint: targetProofFingerprint,
      semanticFramingFingerprint: semanticFramingFingerprint,
      wordingFingerprint: wordingFingerprint,
      affectedEvidenceRefs: affectedEvidenceRefs,
      disputedEvidenceRefs: disputedEvidenceRefs,
      preferredWording: preferredWording,
      choice: choice,
      qualifier: qualifier,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceSurface: sourceSurface,
      schemaVersion: schemaVersion,
      superseded: superseded ?? this.superseded,
    );
  }

  Map<String, dynamic> toJson() => {
    'correctionId': correctionId,
    'archiveScope': archiveScope,
    'targetProofId': targetProofId,
    'targetProofFingerprint': targetProofFingerprint,
    'semanticFramingFingerprint': semanticFramingFingerprint,
    'wordingFingerprint': wordingFingerprint,
    'affectedEvidenceRefs': List<String>.of(affectedEvidenceRefs),
    if (disputedEvidenceRefs.isNotEmpty)
      'disputedEvidenceRefs': List<String>.of(disputedEvidenceRefs),
    if (preferredWording != null) 'preferredWording': preferredWording,
    'choice': choice.name,
    if (qualifier != null) 'qualifier': qualifier!.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'sourceSurface': sourceSurface,
    'schemaVersion': schemaVersion,
    'superseded': superseded,
  };

  static String _string(Object? value) => value is String ? value : '';

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return List.unmodifiable(value.whereType<String>());
  }

  static DateTime _dateTime(Object? value, {DateTime? fallback}) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    if (raw is! String) return fallback;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }

  static T? _nullableEnumByName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}