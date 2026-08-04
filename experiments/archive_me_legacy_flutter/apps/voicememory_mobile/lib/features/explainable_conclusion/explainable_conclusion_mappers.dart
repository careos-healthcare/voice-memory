import '../../models/reflection.dart';
import '../archive_synthesis/archive_synthesis_models.dart';
import '../evidence_trail/evidence_trail_models.dart';
import '../first_session/first_session_pattern_model.dart';
import 'explainable_conclusion.dart';
import 'explainable_conclusion_validator.dart';

class ExplainableConclusionMappingResult {
  const ExplainableConclusionMappingResult({
    this.conclusion,
    this.validation,
    this.sourceUnavailable = false,
  });

  final ExplainableConclusion? conclusion;
  final ExplainableConclusionValidationResult? validation;
  final bool sourceUnavailable;

  bool get isValid => conclusion != null && validation?.isValid == true;

  ValidatedExplainableConclusion? gated(
    Map<String, String> canonicalTranscripts,
  ) {
    final value = conclusion;
    if (value == null) return null;
    return ExplainableConclusionRenderGate.visible(
      value,
      canonicalTranscripts: canonicalTranscripts,
    );
  }
}

abstract final class ExplainableConclusionMappers {
  static ExplainableConclusionMappingResult fromArchiveSynthesis({
    required ArchiveSynthesisConclusion source,
    required Map<String, String> canonicalTranscripts,
  }) {
    final provenance = source.provenance;
    if (source.isLegacy) {
      return const ExplainableConclusionMappingResult(sourceUnavailable: true);
    }
    final citations = <TranscriptEvidenceCitation>[];
    for (final evidence in source.evidence) {
      final role = _role(evidence.role);
      if (evidence.quote == null ||
          evidence.startUtf16 == null ||
          evidence.endUtf16 == null ||
          role == null) {
        return const ExplainableConclusionMappingResult(
          sourceUnavailable: true,
        );
      }
      citations.add(
        TranscriptEvidenceCitation(
          entryId: evidence.entryId,
          quote: evidence.quote!,
          startUtf16: evidence.startUtf16!,
          endUtf16: evidence.endUtf16!,
          role: role,
          sourceCapturedAt: evidence.sourceCapturedAt,
          sourceType: _sourceType(evidence.sourceType),
        ),
      );
    }
    if (provenance == null) {
      return const ExplainableConclusionMappingResult(sourceUnavailable: true);
    }
    return _validate(
      ExplainableConclusion(
        id: source.id,
        statement: source.statement,
        confidence: source.confidencePercent,
        reasoning: source.reasoning,
        uncertaintyNote: source.uncertaintyNote,
        evidence: citations,
        alternatives: source.alternatives,
        provenance: provenance,
      ),
      canonicalTranscripts,
    );
  }

  static ExplainableConclusionMappingResult fromFirstSessionPattern({
    required FirstSessionPattern source,
    required List<TranscriptEvidenceCitation> exactEvidence,
    required Map<String, String> canonicalTranscripts,
  }) {
    if (exactEvidence.isEmpty) {
      return const ExplainableConclusionMappingResult(sourceUnavailable: true);
    }
    return _validate(
      ExplainableConclusion(
        id: source.id,
        statement: source.title,
        confidence: (source.confidenceScore * 100).round(),
        reasoning: [source.whyNoticed],
        uncertaintyNote: source.watchForText,
        evidence: exactEvidence,
        alternatives: source.alternativePatterns
            .map(
              (item) => ExplainableAlternative(
                statement: item.title,
                rationale: item.whyNoticed,
                confidence: (item.confidenceScore * 100).round(),
              ),
            )
            .toList(),
        provenance: ExplainableConclusionProvenance(
          source: 'first_session_pattern',
          generatedAt: source.createdAt,
          schemaVersion: ExplainableConclusion.schemaVersion,
        ),
      ),
      canonicalTranscripts,
    );
  }

  static ExplainableConclusionMappingResult fromReflection({
    required String conclusionId,
    required String statement,
    required Reflection source,
    required List<TranscriptEvidenceCitation> exactEvidence,
    required List<ExplainableAlternative> alternatives,
    required int confidence,
    required DateTime generatedAt,
    required Map<String, String> canonicalTranscripts,
  }) {
    if (exactEvidence.isEmpty) {
      return const ExplainableConclusionMappingResult(sourceUnavailable: true);
    }
    final uncertainty = source.avoidedOrVagueArea?.trim().isNotEmpty == true
        ? source.avoidedOrVagueArea!
        : source.tensionOrContradiction ?? '';
    return _validate(
      ExplainableConclusion(
        id: conclusionId,
        statement: statement,
        confidence: confidence,
        reasoning: [source.concreteObservation, source.repeatedSignal],
        uncertaintyNote: uncertainty,
        evidence: exactEvidence,
        alternatives: alternatives,
        provenance: ExplainableConclusionProvenance(
          source: 'reflection',
          generatedAt: generatedAt,
          schemaVersion: ExplainableConclusion.schemaVersion,
        ),
      ),
      canonicalTranscripts,
    );
  }

  static ExplainableConclusionMappingResult fromEvidenceTrail({
    required String conclusionId,
    required EvidenceTrailPayload source,
    required List<ExplainableAlternative> alternatives,
    required DateTime generatedAt,
    required Map<String, String> canonicalTranscripts,
  }) {
    final citations = <TranscriptEvidenceCitation>[];
    for (final item in source.sources) {
      if (item.startUtf16 == null || item.endUtf16 == null) {
        return const ExplainableConclusionMappingResult(
          sourceUnavailable: true,
        );
      }
      citations.add(
        TranscriptEvidenceCitation(
          entryId: item.entryId,
          quote: item.excerpt,
          startUtf16: item.startUtf16!,
          endUtf16: item.endUtf16!,
          role: switch (item.role) {
            EvidenceSourceRole.supporting => TranscriptEvidenceRole.supporting,
            EvidenceSourceRole.contradicting =>
              TranscriptEvidenceRole.contradicting,
            EvidenceSourceRole.related => TranscriptEvidenceRole.related,
          },
          sourceCapturedAt: item.recordedAt,
          sourceType: _sourceType(item.sourceType),
        ),
      );
    }
    return _validate(
      ExplainableConclusion(
        id: conclusionId,
        statement: source.title,
        confidence: source.confidencePercent ?? 0,
        reasoning: [source.whySummary],
        uncertaintyNote: source.whySummary,
        evidence: citations,
        alternatives: alternatives,
        provenance: ExplainableConclusionProvenance(
          source: 'evidence_trail',
          generatedAt: generatedAt,
          schemaVersion: ExplainableConclusion.schemaVersion,
        ),
      ),
      canonicalTranscripts,
    );
  }

  static ExplainableConclusionMappingResult _validate(
    ExplainableConclusion conclusion,
    Map<String, String> canonicalTranscripts,
  ) {
    final validation = ExplainableConclusionValidator.validate(
      conclusion,
      canonicalTranscripts: canonicalTranscripts,
    );
    return ExplainableConclusionMappingResult(
      conclusion: conclusion,
      validation: validation,
    );
  }

  static TranscriptEvidenceRole? _role(String? raw) => switch (raw) {
    'support' || 'supporting' => TranscriptEvidenceRole.supporting,
    'counter' || 'contradicting' => TranscriptEvidenceRole.contradicting,
    'context' || 'related' => TranscriptEvidenceRole.related,
    _ => null,
  };

  static EvidenceSourceType _sourceType(String? raw) =>
      switch (raw?.toLowerCase()) {
        'voice' || 'audio' => EvidenceSourceType.voice,
        'text' || 'written' => EvidenceSourceType.text,
        _ => EvidenceSourceType.unknown,
      };
}
