import '../features/explainable_conclusion/explainable_conclusion.dart';
import '../features/explainable_conclusion/explainable_conclusion_validator.dart';

class Reflection {
  const Reflection({
    required this.mood,
    required this.emotionalIntensity,
    required this.recurringThemes,
    required this.exactLanguagePattern,
    required this.concreteObservation,
    required this.repeatedSignal,
    this.tensionOrContradiction,
    this.avoidedOrVagueArea,
    this.nextSmallAction,
    this.patternObservations = const [],
    this.explainableConclusion,
  });

  final String mood;
  final int emotionalIntensity;
  final List<String> recurringThemes;
  final String exactLanguagePattern;
  final String concreteObservation;
  final String repeatedSignal;
  final String? tensionOrContradiction;
  final String? avoidedOrVagueArea;
  final String? nextSmallAction;
  final List<String> patternObservations;
  final ExplainableConclusion? explainableConclusion;

  factory Reflection.fromJson(Map<String, dynamic> json) {
    final themes = (json['recurringThemes'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final patterns = (json['patternObservations'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    return Reflection(
      mood: json['mood'] as String? ?? '',
      emotionalIntensity: (json['emotionalIntensity'] as num?)?.toInt() ?? 0,
      recurringThemes: themes,
      exactLanguagePattern: json['exactLanguagePattern'] as String? ?? '',
      concreteObservation: json['concreteObservation'] as String? ?? '',
      repeatedSignal: json['repeatedSignal'] as String? ?? '',
      tensionOrContradiction: _optionalString(json['tensionOrContradiction']),
      avoidedOrVagueArea: _optionalString(json['avoidedOrVagueArea']),
      nextSmallAction: _optionalString(json['nextSmallAction']),
      patternObservations: patterns,
      explainableConclusion: ExplainableConclusion.fromJson(
        json['explainableConclusion'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'mood': mood,
    'emotionalIntensity': emotionalIntensity,
    'recurringThemes': recurringThemes,
    'hiddenConcern': '',
    'positiveSignal': '',
    'recommendation': '',
    'exactLanguagePattern': exactLanguagePattern,
    'concreteObservation': concreteObservation,
    'repeatedSignal': repeatedSignal,
    if (tensionOrContradiction != null)
      'tensionOrContradiction': tensionOrContradiction,
    if (avoidedOrVagueArea != null) 'avoidedOrVagueArea': avoidedOrVagueArea,
    if (nextSmallAction != null) 'nextSmallAction': nextSmallAction,
    if (patternObservations.isNotEmpty)
      'patternObservations': patternObservations,
    if (explainableConclusion != null)
      'explainableConclusion': explainableConclusion!.toJson(),
  };

  /// Validates cloud output against the exact transcript that will be saved.
  ///
  /// The API normally receives the final entry id. `current-entry` is
  /// accepted only for compatibility with older responses and is rebound
  /// before validation and persistence.
  Reflection validatedForPersistence({
    required String transcript,
    required String entryId,
  }) {
    final source = explainableConclusion;
    if (source == null) {
      return Reflection.deterministicTranscriptOnly(
        transcript: transcript,
        entryId: entryId,
      );
    }
    final rebound = _rebindCurrentEntry(source, entryId);
    final gated = ExplainableConclusionRenderGate.visible(
      rebound,
      canonicalTranscripts: {entryId: transcript},
    );
    if (gated == null) {
      return Reflection.deterministicTranscriptOnly(
        transcript: transcript,
        entryId: entryId,
      );
    }
    final supporting = rebound.evidence
        .where((item) => item.role == TranscriptEvidenceRole.supporting)
        .firstOrNull;
    if (supporting == null) {
      return Reflection.deterministicTranscriptOnly(
        transcript: transcript,
        entryId: entryId,
      );
    }
    return Reflection(
      mood: mood,
      emotionalIntensity: emotionalIntensity,
      recurringThemes: recurringThemes,
      exactLanguagePattern: supporting.quote,
      concreteObservation: rebound.statement.trim(),
      repeatedSignal: _deterministicRepeatedSignal(transcript),
      tensionOrContradiction: null,
      avoidedOrVagueArea: null,
      nextSmallAction: null,
      patternObservations: [
        supporting.quote,
        rebound.statement.trim(),
        _deterministicRepeatedSignal(transcript),
      ].where((item) => item.isNotEmpty).toList(growable: false),
      explainableConclusion: rebound,
    );
  }

  static Reflection deterministicTranscriptOnly({
    required String transcript,
    required String entryId,
  }) {
    final bounds = _firstMeaningfulSlice(transcript);
    if (bounds == null) {
      return const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation:
            'There is not enough spoken detail for a specific observation yet.',
        repeatedSignal: 'Nothing repeated clearly in this entry.',
      );
    }
    final quote = transcript.substring(bounds.$1, bounds.$2);
    final statement = 'Your words include “$quote”.';
    final now = DateTime.now().toUtc();
    return Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: const [],
      exactLanguagePattern: quote,
      concreteObservation: statement,
      repeatedSignal: _deterministicRepeatedSignal(transcript),
      patternObservations: [quote, statement],
      explainableConclusion: ExplainableConclusion(
        id: 'deterministic:$entryId:${bounds.$1}-${bounds.$2}',
        statement: statement,
        confidence: 55,
        reasoning: [
          'The conclusion repeats an exact slice of the current transcript.',
          'No broader recurrence or intent is inferred from this single slice.',
        ],
        uncertaintyNote:
            'This identifies exact wording only; it does not establish a broader pattern.',
        evidence: [
          TranscriptEvidenceCitation(
            entryId: entryId,
            quote: quote,
            startUtf16: bounds.$1,
            endUtf16: bounds.$2,
            role: TranscriptEvidenceRole.supporting,
          ),
        ],
        alternatives: const [
          ExplainableAlternative(
            statement: 'This wording may describe only this moment.',
            rationale:
                'One transcript slice cannot establish recurrence or intent.',
          ),
        ],
        provenance: ExplainableConclusionProvenance(
          source: 'deterministic',
          generatedAt: now,
          schemaVersion: ExplainableConclusion.schemaVersion,
          sourceRevision: 'exact-slice-v1',
        ),
      ),
    );
  }

  static String? _optionalString(dynamic value) {
    if (value is! String) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  static ExplainableConclusion _rebindCurrentEntry(
    ExplainableConclusion source,
    String entryId,
  ) => ExplainableConclusion(
    id: source.id,
    statement: source.statement,
    confidence: source.confidence,
    reasoning: source.reasoning,
    uncertaintyNote: source.uncertaintyNote,
    evidence: [
      for (final citation in source.evidence)
        TranscriptEvidenceCitation(
          entryId: citation.entryId == 'current-entry'
              ? entryId
              : citation.entryId,
          quote: citation.quote,
          startUtf16: citation.startUtf16,
          endUtf16: citation.endUtf16,
          role: citation.role,
          audioTimestampMs: citation.audioTimestampMs,
          audioEndTimestampMs: citation.audioEndTimestampMs,
          audioVaultReference: citation.audioVaultReference,
          sourceCapturedAt: citation.sourceCapturedAt,
          sourceType: citation.sourceType,
          temporalRole: citation.temporalRole,
          confidenceScore: citation.confidenceScore,
        ),
    ],
    alternatives: source.alternatives,
    provenance: source.provenance,
    kind: source.kind,
    nextRecordingPrompt: source.nextRecordingPrompt,
    historyVersion: source.historyVersion,
    isLegacy: source.isLegacy,
    confidenceKnown: source.confidenceKnown,
    feedbackState: source.feedbackState,
    feedbackTimestamp: source.feedbackTimestamp,
    correctionNote: source.correctionNote,
    theoryId: source.theoryId,
    evolutionHistory: source.evolutionHistory,
  );

  static (int, int)? _firstMeaningfulSlice(String transcript) {
    final start = transcript.indexOf(RegExp(r'\S'));
    if (start < 0) return null;
    final remainder = transcript.substring(start);
    final ending = remainder.indexOf(RegExp(r'[.!?\n]'));
    var end = ending >= 0
        ? start + ending + 1
        : (start + 120 < transcript.length ? start + 120 : transcript.length);
    while (end > start && RegExp(r'\s').hasMatch(transcript[end - 1])) {
      end--;
    }
    if (end > start &&
        _isHighSurrogate(transcript.codeUnitAt(end - 1)) &&
        end < transcript.length) {
      end++;
    }
    return end > start ? (start, end) : null;
  }

  static String _deterministicRepeatedSignal(String transcript) =>
      'Nothing repeated clearly in this entry.';

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
}
