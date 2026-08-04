library;

import '../ai_engines/models/ai_accuracy_feedback.dart';
import '../ai_engines/models/hypothesis_evolution.dart';

enum TranscriptEvidenceRole { supporting, contradicting, related }

enum ExplainableInsightKind { observation, pattern, change }

enum EvidenceSourceType { voice, text, unknown }

enum EvidenceTemporalRole { single, then, now }

enum EvidenceConfidenceBand {
  earlyObservation,
  someSupportingEvidence,
  repeatedAcrossMoments,
  stronglySupported,
}

extension ExplainableConclusionConfidence on ExplainableConclusion {
  EvidenceConfidenceBand get confidenceBand {
    final supportingSources = evidence
        .where((item) => item.role == TranscriptEvidenceRole.supporting)
        .map((item) => item.entryId)
        .toSet()
        .length;
    if (confidence >= 86 && supportingSources >= 3) {
      return EvidenceConfidenceBand.stronglySupported;
    }
    if (supportingSources >= 2) {
      return EvidenceConfidenceBand.repeatedAcrossMoments;
    }
    if (confidence >= 55) {
      return EvidenceConfidenceBand.someSupportingEvidence;
    }
    return EvidenceConfidenceBand.earlyObservation;
  }

  String get confidenceLabel => switch (confidenceBand) {
    EvidenceConfidenceBand.earlyObservation => 'Early observation',
    EvidenceConfidenceBand.someSupportingEvidence => 'Some supporting evidence',
    EvidenceConfidenceBand.repeatedAcrossMoments =>
      'Repeated across several moments',
    EvidenceConfidenceBand.stronglySupported =>
      'Strongly supported by your archive',
  };
}

extension TranscriptEvidenceRoleWireName on TranscriptEvidenceRole {
  String get wireName => switch (this) {
    TranscriptEvidenceRole.supporting => 'support',
    TranscriptEvidenceRole.contradicting => 'counter',
    TranscriptEvidenceRole.related => 'context',
  };

  static TranscriptEvidenceRole? parse(Object? value) => switch (value) {
    'support' || 'supporting' => TranscriptEvidenceRole.supporting,
    'counter' || 'contradicting' => TranscriptEvidenceRole.contradicting,
    'context' || 'related' => TranscriptEvidenceRole.related,
    _ => null,
  };
}

class TranscriptEvidenceCitation {
  const TranscriptEvidenceCitation({
    required this.entryId,
    required this.quote,
    required this.startUtf16,
    required this.endUtf16,
    required this.role,
    this.audioTimestampMs,
    this.audioEndTimestampMs,
    this.audioVaultReference,
    this.sourceCapturedAt,
    this.sourceType = EvidenceSourceType.unknown,
    this.temporalRole = EvidenceTemporalRole.single,
    this.confidenceScore = 1,
  });

  final String entryId;
  final String quote;
  final int startUtf16;
  final int endUtf16;
  final TranscriptEvidenceRole role;
  final int? audioTimestampMs;
  final int? audioEndTimestampMs;
  final String? audioVaultReference;
  final DateTime? sourceCapturedAt;
  final EvidenceSourceType sourceType;
  final EvidenceTemporalRole temporalRole;
  final double confidenceScore;

  bool get hasPlayableAudio =>
      audioTimestampMs != null &&
      audioTimestampMs! >= 0 &&
      audioVaultReference?.trim().isNotEmpty == true;

  String get sourceEntryId => entryId;
  String get exactQuote => quote;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'quote': quote,
    'sourceEntryId': entryId,
    'exactQuote': quote,
    if (audioTimestampMs != null) 'audioTimestampMs': audioTimestampMs,
    if (audioEndTimestampMs != null) 'audioEndTimestampMs': audioEndTimestampMs,
    if (audioVaultReference?.trim().isNotEmpty == true)
      'audioVaultReference': audioVaultReference!.trim(),
    if (sourceCapturedAt != null)
      'sourceCapturedAt': sourceCapturedAt!.toUtc().toIso8601String(),
    'sourceType': sourceType.name,
    'temporalRole': temporalRole.name,
    'confidenceScore': confidenceScore,
    'startUtf16': startUtf16,
    'endUtf16': endUtf16,
    'role': role.wireName,
  };

  static TranscriptEvidenceCitation? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final role = TranscriptEvidenceRoleWireName.parse(json['role']);
    final start = json['startUtf16'];
    final end = json['endUtf16'];
    final confidence = json['confidenceScore'];
    final audioTimestamp = json['audioTimestampMs'];
    final audioEndTimestamp = json['audioEndTimestampMs'];
    if (role == null ||
        start is! int ||
        end is! int ||
        (confidence != null && confidence is! num) ||
        (audioTimestamp != null && audioTimestamp is! int) ||
        (audioEndTimestamp != null && audioEndTimestamp is! int)) {
      return null;
    }
    final sourceType = EvidenceSourceType.values
        .where((item) => item.name == json['sourceType'])
        .firstOrNull;
    final temporalRole = EvidenceTemporalRole.values
        .where((item) => item.name == json['temporalRole'])
        .firstOrNull;
    return TranscriptEvidenceCitation(
      entryId:
          json['sourceEntryId']?.toString() ??
          json['entryId']?.toString() ??
          '',
      quote: json['exactQuote']?.toString() ?? json['quote']?.toString() ?? '',
      startUtf16: start,
      endUtf16: end,
      role: role,
      audioTimestampMs: audioTimestamp as int?,
      audioEndTimestampMs: audioEndTimestamp as int?,
      audioVaultReference: json['audioVaultReference']?.toString(),
      sourceCapturedAt: DateTime.tryParse(
        json['sourceCapturedAt']?.toString() ?? '',
      )?.toUtc(),
      sourceType: sourceType ?? EvidenceSourceType.unknown,
      temporalRole: temporalRole ?? EvidenceTemporalRole.single,
      confidenceScore: (confidence as num?)?.toDouble() ?? 1,
    );
  }
}

class ExplainableAlternative {
  const ExplainableAlternative({
    required this.statement,
    required this.rationale,
    this.confidence,
  });

  final String statement;
  final String rationale;
  final int? confidence;

  String get reason => rationale;

  Map<String, dynamic> toJson() => {
    'statement': statement,
    'reason': rationale,
    if (confidence != null) 'confidence': confidence,
  };

  static ExplainableAlternative? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    return ExplainableAlternative(
      statement: json['statement']?.toString() ?? '',
      rationale:
          json['rationale']?.toString() ?? json['reason']?.toString() ?? '',
      confidence: json['confidence'] is int ? json['confidence'] as int : null,
    );
  }
}

class ExplainableConclusionProvenance {
  const ExplainableConclusionProvenance({
    required this.source,
    required this.generatedAt,
    required this.schemaVersion,
    this.model,
    this.sourceRevision,
    this.parentVersion,
  });

  final String source;
  final DateTime generatedAt;
  final int schemaVersion;
  final String? model;
  final String? sourceRevision;
  final int? parentVersion;

  String get generatedBy => source;

  Map<String, dynamic> toJson() => {
    'generatedBy': source,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    if (model != null) 'model': model,
    if (sourceRevision != null) 'promptVersion': sourceRevision,
  };

  static ExplainableConclusionProvenance? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final generatedAt = DateTime.tryParse(
      json['generatedAt']?.toString() ?? '',
    );
    final generatedBy = json['generatedBy']?.toString();
    final schemaVersion = json['schemaVersion'] is int
        ? json['schemaVersion'] as int
        : (generatedBy == 'model' || generatedBy == 'deterministic' ? 1 : null);
    if (generatedAt == null || schemaVersion == null) return null;
    return ExplainableConclusionProvenance(
      source: json['source']?.toString() ?? generatedBy ?? '',
      generatedAt: generatedAt,
      schemaVersion: schemaVersion,
      model: json['model']?.toString(),
      sourceRevision:
          json['sourceRevision']?.toString() ??
          json['promptVersion']?.toString(),
      parentVersion: json['parentVersion'] is int
          ? json['parentVersion'] as int
          : null,
    );
  }
}

class ExplainableConclusion {
  const ExplainableConclusion({
    required this.id,
    required this.statement,
    required this.confidence,
    required this.reasoning,
    required this.uncertaintyNote,
    required this.evidence,
    required this.alternatives,
    required this.provenance,
    this.kind = ExplainableInsightKind.observation,
    this.nextRecordingPrompt,
    this.historyVersion = 1,
    this.isLegacy = false,
    this.confidenceKnown = true,
    this.feedbackState = AiFeedbackState.pending,
    this.feedbackTimestamp,
    this.correctionNote,
    this.theoryId,
    this.evolutionHistory = const [],
  });

  static const schemaVersion = 4;

  final String id;
  final String statement;
  final int confidence;
  final List<String> reasoning;
  final String uncertaintyNote;
  final List<TranscriptEvidenceCitation> evidence;
  final List<ExplainableAlternative> alternatives;
  final ExplainableConclusionProvenance provenance;
  final ExplainableInsightKind kind;
  final String? nextRecordingPrompt;
  final int historyVersion;
  final bool isLegacy;
  final bool confidenceKnown;
  final AiFeedbackState feedbackState;
  final DateTime? feedbackTimestamp;
  final String? correctionNote;
  final String? theoryId;
  final List<ConfidenceSnapshot> evolutionHistory;

  int get confidencePercent => confidence;
  int get confidencePercentage => confidence;
  ExplainableAlternative get alternativeExplanation => alternatives.first;
  String get uncertainty => uncertaintyNote;

  ExplainableConclusion copyWith({
    String? id,
    String? statement,
    int? confidence,
    List<String>? reasoning,
    String? uncertaintyNote,
    List<TranscriptEvidenceCitation>? evidence,
    List<ExplainableAlternative>? alternatives,
    ExplainableConclusionProvenance? provenance,
    ExplainableInsightKind? kind,
    String? nextRecordingPrompt,
    int? historyVersion,
    bool? isLegacy,
    bool? confidenceKnown,
    AiFeedbackState? feedbackState,
    DateTime? feedbackTimestamp,
    String? correctionNote,
    String? theoryId,
    List<ConfidenceSnapshot>? evolutionHistory,
  }) => ExplainableConclusion(
    id: id ?? this.id,
    statement: statement ?? this.statement,
    confidence: confidence ?? this.confidence,
    reasoning: reasoning ?? this.reasoning,
    uncertaintyNote: uncertaintyNote ?? this.uncertaintyNote,
    evidence: evidence ?? this.evidence,
    alternatives: alternatives ?? this.alternatives,
    provenance: provenance ?? this.provenance,
    kind: kind ?? this.kind,
    nextRecordingPrompt: nextRecordingPrompt ?? this.nextRecordingPrompt,
    historyVersion: historyVersion ?? this.historyVersion,
    isLegacy: isLegacy ?? this.isLegacy,
    confidenceKnown: confidenceKnown ?? this.confidenceKnown,
    feedbackState: feedbackState ?? this.feedbackState,
    feedbackTimestamp: feedbackTimestamp ?? this.feedbackTimestamp,
    correctionNote: correctionNote ?? this.correctionNote,
    theoryId: theoryId ?? this.theoryId,
    evolutionHistory: evolutionHistory ?? this.evolutionHistory,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'statement': statement,
    'confidencePercent': confidence,
    'confidence': confidence,
    'reasoning': reasoning,
    'uncertaintyNote': uncertaintyNote,
    'uncertainty': uncertaintyNote,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'alternatives': alternatives.map((item) => item.toJson()).toList(),
    'alternativeExplanation': alternativeExplanation.toJson(),
    'provenance': provenance.toJson(),
    'kind': kind.name,
    if (nextRecordingPrompt?.trim().isNotEmpty == true)
      'nextRecordingPrompt': nextRecordingPrompt!.trim(),
    'historyVersion': historyVersion,
    if (isLegacy) 'legacyMode': true,
    if (!confidenceKnown) 'confidenceKnown': false,
    'feedbackState': feedbackState.name,
    if (feedbackTimestamp != null)
      'feedbackTimestamp': feedbackTimestamp!.toUtc().toIso8601String(),
    if (correctionNote?.trim().isNotEmpty == true)
      'correctionNote': correctionNote!.trim(),
    if (theoryId?.trim().isNotEmpty == true) 'theoryId': theoryId,
    'evolutionHistory': evolutionHistory
        .map((snapshot) => snapshot.toJson())
        .toList(growable: false),
  };

  static ExplainableConclusion? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final id = json['id']?.toString() ?? '';
    final statement = json['statement']?.toString() ?? '';
    if (id.isEmpty || statement.isEmpty) return null;
    final kindValue = json['kind'];
    final kind = kindValue == null
        ? ExplainableInsightKind.observation
        : ExplainableInsightKind.values
              .where((item) => item.name == kindValue)
              .firstOrNull;
    if (kind == null) return null;
    final provenance = ExplainableConclusionProvenance.fromJson(
      json['provenance'],
    );
    final isV4 =
        json['legacyMode'] != true &&
        (provenance?.schemaVersion == schemaVersion ||
            json.containsKey('reasoning') ||
            json.containsKey('alternativeExplanation') ||
            json.containsKey('uncertainty'));
    if (!isV4) return null;
    final confidence = json['confidencePercent'] ?? json['confidence'];
    if (provenance == null ||
        provenance.schemaVersion != schemaVersion ||
        confidence is! int ||
        (json['confidence'] != null &&
            json['confidencePercent'] != null &&
            json['confidence'] != json['confidencePercent'])) {
      return null;
    }
    final reasoning = (json['reasoning'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    if (reasoning.isEmpty) return null;
    final evidence = (json['evidence'] as List? ?? const [])
        .map(TranscriptEvidenceCitation.fromJson)
        .whereType<TranscriptEvidenceCitation>()
        .toList();
    final alternatives = (json['alternatives'] as List? ?? const [])
        .map(ExplainableAlternative.fromJson)
        .whereType<ExplainableAlternative>()
        .toList();
    final primaryAlternative = ExplainableAlternative.fromJson(
      json['alternativeExplanation'],
    );
    if (alternatives.isEmpty && primaryAlternative != null) {
      alternatives.add(primaryAlternative);
    }
    if (alternatives.isEmpty ||
        (primaryAlternative != null &&
            (alternatives.first.statement != primaryAlternative.statement ||
                alternatives.first.reason != primaryAlternative.reason))) {
      return null;
    }
    final uncertainty =
        json['uncertainty']?.toString() ??
        json['uncertaintyNote']?.toString() ??
        '';
    if (uncertainty.isEmpty) return null;
    if (json['uncertainty'] != null &&
        json['uncertaintyNote'] != null &&
        json['uncertainty'] != json['uncertaintyNote']) {
      return null;
    }
    return ExplainableConclusion(
      id: id,
      statement: statement,
      confidence: confidence,
      reasoning: reasoning,
      uncertaintyNote: uncertainty,
      evidence: evidence,
      alternatives: alternatives,
      provenance: provenance,
      kind: kind,
      nextRecordingPrompt: json['nextRecordingPrompt']?.toString(),
      historyVersion: json['historyVersion'] is int
          ? json['historyVersion'] as int
          : 1,
      feedbackState: _feedbackState(
        json['feedbackState'] ?? json['userFeedbackState'],
      ),
      feedbackTimestamp: DateTime.tryParse(
        json['feedbackTimestamp']?.toString() ?? '',
      )?.toUtc(),
      correctionNote:
          json['correctionNote']?.toString() ??
          json['userCorrectionNote']?.toString(),
      theoryId: json['theoryId']?.toString(),
      evolutionHistory: _evolutionHistory(json['evolutionHistory']),
    );
  }

  static AiFeedbackState _feedbackState(Object? value) {
    try {
      final wireState = value?.toString() ?? 'pending';
      return AiFeedbackState.values.byName(
        wireState == 'deferred' ? 'later' : wireState,
      );
    } on ArgumentError {
      return AiFeedbackState.pending;
    }
  }

  static List<ConfidenceSnapshot> _evolutionHistory(Object? value) =>
      List.unmodifiable(
        (value as List? ?? const [])
            .map(ConfidenceSnapshot.fromJson)
            .whereType<ConfidenceSnapshot>(),
      );
}
