import 'explainable_conclusion.dart';

enum ExplainableConclusionBlockReason {
  emptyId,
  emptyStatement,
  missingReasoning,
  invalidReasoning,
  invalidConfidence,
  nonPositiveConfidence,
  confidenceExceedsEvidenceCap,
  genericStatement,
  identityOrDiagnosisLanguage,
  insufficientTopicAlignment,
  topicDomainMismatch,
  emptyUncertaintyNote,
  meaninglessUncertaintyNote,
  missingAlternative,
  invalidAlternative,
  duplicateAlternative,
  missingEvidence,
  missingSupportingEvidence,
  emptyEvidenceExcerpt,
  evidenceExcerptTooShort,
  quoteIsAllStopWords,
  duplicateEvidence,
  missingTranscript,
  invalidOffsets,
  splitSurrogatePair,
  quoteMismatch,
  invalidEvidenceConfidence,
  invalidSourceType,
  invalidAudioRange,
  missingSourceCapturedAt,
  impossibleTimestampOrder,
  insufficientPatternSources,
  changeRequiresDistinctSources,
  changeEvidenceNotDistinct,
  missingThenEvidence,
  missingNowEvidence,
  legacyReceiptUnsupported,
  invalidProvenance,
}

class ExplainableConclusionValidationResult {
  const ExplainableConclusionValidationResult._({
    required this.conclusion,
    required this.blockReasons,
    required this.evidenceConfidenceCap,
  });

  final ExplainableConclusion conclusion;
  final List<ExplainableConclusionBlockReason> blockReasons;
  final int evidenceConfidenceCap;

  bool get isValid => blockReasons.isEmpty;
}

class ValidatedExplainableConclusion {
  const ValidatedExplainableConclusion._(this.value);

  final ExplainableConclusion value;
}

class ExplainableConclusionRenderGate {
  const ExplainableConclusionRenderGate._();

  static ValidatedExplainableConclusion? visible(
    ExplainableConclusion conclusion, {
    required Map<String, String> canonicalTranscripts,
  }) {
    final result = ExplainableConclusionValidator.validate(
      conclusion,
      canonicalTranscripts: canonicalTranscripts,
    );
    return result.isValid ? ValidatedExplainableConclusion._(conclusion) : null;
  }
}

abstract final class ExplainableConclusionValidator {
  /// Minimum non-whitespace characters in a citable quote.
  ///
  /// Two characters is not a quotation, it is a fragment. A short quote is
  /// still allowed when it is semantically complete — see
  /// [_isMeaningfulQuote] and the short-quote fixtures.
  static const minimumUsableQuoteLength = 4;

  /// A quote must contribute at least this many content words.
  static const minimumQuoteContentWords = 1;

  static const minimumTopicAlignment = 1;

  static final RegExp _emptyUncertainty = RegExp(
    r'^(?:none|n/?a|no uncertainty|certain|unknown)[.!]?$',
    caseSensitive: false,
  );
  static final RegExp _genericStatement = RegExp(
    r'^(?:this (?:may|might|could) (?:be|mean)|something (?:may|might)|'
    r'you may be experiencing|there (?:may|might) be|a possible pattern)',
    caseSensitive: false,
  );
  static final RegExp _identityOrDiagnosisLanguage = RegExp(
    r'\b(?:you are|your personality|personality trait|diagnos(?:is|ed)|'
    r'disorder|deep truth|who you really are|you always|you never)\b',
    caseSensitive: false,
  );
  static final RegExp _word = RegExp(r"[a-z0-9']+");
  static const _stopWords = {
    'about',
    'after',
    'again',
    'also',
    'archive',
    'archiveme',
    'because',
    'been',
    'before',
    'could',
    'described',
    'doing',
    'feel',
    'feeling',
    'feels',
    'felt',
    'from',
    'have',
    'into',
    'might',
    'moment',
    'more',
    'noticed',
    'possible',
    'rather',
    'said',
    'something',
    'that',
    'their',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'through',
    'under',
    'very',
    'what',
    'when',
    'where',
    'which',
    'with',
    'would',
    'your',
  };

  static ExplainableConclusionValidationResult validate(
    ExplainableConclusion conclusion, {
    required Map<String, String> canonicalTranscripts,
  }) {
    final reasons = <ExplainableConclusionBlockReason>{};
    if (conclusion.id.trim().isEmpty) {
      reasons.add(ExplainableConclusionBlockReason.emptyId);
    }
    if (conclusion.statement.trim().isEmpty) {
      reasons.add(ExplainableConclusionBlockReason.emptyStatement);
    }
    if (conclusion.isLegacy) {
      reasons.add(ExplainableConclusionBlockReason.legacyReceiptUnsupported);
    }
    if (conclusion.reasoning.isEmpty) {
      reasons.add(ExplainableConclusionBlockReason.missingReasoning);
    } else if (conclusion.reasoning.any((step) => step.trim().length < 8)) {
      reasons.add(ExplainableConclusionBlockReason.invalidReasoning);
    }
    if (conclusion.confidence < 0 || conclusion.confidence > 100) {
      reasons.add(ExplainableConclusionBlockReason.invalidConfidence);
    } else if (conclusion.confidence == 0 || !conclusion.confidenceKnown) {
      reasons.add(ExplainableConclusionBlockReason.nonPositiveConfidence);
    }
    final statement = conclusion.statement.trim();
    if (_genericStatement.hasMatch(statement)) {
      reasons.add(ExplainableConclusionBlockReason.genericStatement);
    }
    if (_identityOrDiagnosisLanguage.hasMatch(statement)) {
      reasons.add(ExplainableConclusionBlockReason.identityOrDiagnosisLanguage);
    }
    final uncertainty = conclusion.uncertaintyNote.trim();
    if (uncertainty.isEmpty) {
      reasons.add(ExplainableConclusionBlockReason.emptyUncertaintyNote);
    } else if (uncertainty.length < 12 ||
        _emptyUncertainty.hasMatch(uncertainty)) {
      reasons.add(ExplainableConclusionBlockReason.meaninglessUncertaintyNote);
    }
    if (conclusion.alternatives.isEmpty) {
      reasons.add(ExplainableConclusionBlockReason.missingAlternative);
    }
    for (final alternative in conclusion.alternatives) {
      final confidence = alternative.confidence;
      final statement = alternative.statement.trim();
      final rationale = alternative.rationale.trim();
      if (statement.length < 3 ||
          rationale.length < 8 ||
          (confidence != null && (confidence < 0 || confidence > 100))) {
        reasons.add(ExplainableConclusionBlockReason.invalidAlternative);
      }
      if (statement.toLowerCase() ==
          conclusion.statement.trim().toLowerCase()) {
        reasons.add(ExplainableConclusionBlockReason.duplicateAlternative);
      }
    }
    if (conclusion.provenance.source.trim().isEmpty ||
        conclusion.provenance.schemaVersion !=
            ExplainableConclusion.schemaVersion) {
      reasons.add(ExplainableConclusionBlockReason.invalidProvenance);
    }
    if (conclusion.evidence.isEmpty) {
      reasons.add(ExplainableConclusionBlockReason.missingEvidence);
    }
    if (!conclusion.evidence.any(
      (item) => item.role == TranscriptEvidenceRole.supporting,
    )) {
      reasons.add(ExplainableConclusionBlockReason.missingSupportingEvidence);
    }

    final evidenceKeys = <String>{};
    for (final citation in conclusion.evidence) {
      if (citation.quote.trim().isEmpty) {
        reasons.add(ExplainableConclusionBlockReason.emptyEvidenceExcerpt);
      } else if (_compactLength(citation.quote) < minimumUsableQuoteLength) {
        reasons.add(ExplainableConclusionBlockReason.evidenceExcerptTooShort);
      } else if (!_isMeaningfulQuote(citation.quote)) {
        reasons.add(ExplainableConclusionBlockReason.quoteIsAllStopWords);
      }
      final evidenceKey =
          '${citation.entryId}:${citation.startUtf16}:${citation.endUtf16}:'
          '${citation.role.name}:${citation.temporalRole.name}';
      if (!evidenceKeys.add(evidenceKey)) {
        reasons.add(ExplainableConclusionBlockReason.duplicateEvidence);
      }
      if (citation.confidenceScore < 0 || citation.confidenceScore > 1) {
        reasons.add(ExplainableConclusionBlockReason.invalidEvidenceConfidence);
      }
      if (citation.sourceType == EvidenceSourceType.unknown) {
        reasons.add(ExplainableConclusionBlockReason.invalidSourceType);
      }
      final audioStart = citation.audioTimestampMs;
      final audioEnd = citation.audioEndTimestampMs;
      if ((audioStart != null && audioStart < 0) ||
          (audioEnd != null &&
              (audioStart == null || audioEnd <= audioStart))) {
        reasons.add(ExplainableConclusionBlockReason.invalidAudioRange);
      }
      final capturedAt = citation.sourceCapturedAt;
      if (capturedAt == null) {
        reasons.add(ExplainableConclusionBlockReason.missingSourceCapturedAt);
      } else if (capturedAt.isAfter(conclusion.provenance.generatedAt)) {
        reasons.add(ExplainableConclusionBlockReason.impossibleTimestampOrder);
      }
      final transcript = canonicalTranscripts[citation.entryId];
      if (transcript == null) {
        reasons.add(ExplainableConclusionBlockReason.missingTranscript);
        continue;
      }
      final start = citation.startUtf16;
      final end = citation.endUtf16;
      if (start < 0 || end <= start || end > transcript.length) {
        reasons.add(ExplainableConclusionBlockReason.invalidOffsets);
        continue;
      }
      if (_splitsSurrogatePair(transcript, start) ||
          _splitsSurrogatePair(transcript, end)) {
        reasons.add(ExplainableConclusionBlockReason.splitSurrogatePair);
        continue;
      }
      if (transcript.substring(start, end) != citation.quote) {
        reasons.add(ExplainableConclusionBlockReason.quoteMismatch);
      }
    }

    final supporting = conclusion.evidence
        .where((item) => item.role == TranscriptEvidenceRole.supporting)
        .toList(growable: false);
    final distinctSupportingSources = supporting
        .map((item) => item.entryId)
        .toSet();
    if (supporting.isNotEmpty &&
        !_hasMinimumTopicAlignment(statement, supporting)) {
      reasons.add(ExplainableConclusionBlockReason.insufficientTopicAlignment);
    }
    if (supporting.isNotEmpty &&
        _hasTopicDomainMismatch(statement, supporting)) {
      reasons.add(ExplainableConclusionBlockReason.topicDomainMismatch);
    }
    if (conclusion.kind == ExplainableInsightKind.pattern &&
        distinctSupportingSources.length < 2) {
      reasons.add(ExplainableConclusionBlockReason.insufficientPatternSources);
    }
    if (conclusion.kind == ExplainableInsightKind.change) {
      final thenEvidence = supporting
          .where((item) => item.temporalRole == EvidenceTemporalRole.then)
          .toList(growable: false);
      final nowEvidence = supporting
          .where((item) => item.temporalRole == EvidenceTemporalRole.now)
          .toList(growable: false);
      if (thenEvidence.isEmpty) {
        reasons.add(ExplainableConclusionBlockReason.missingThenEvidence);
      }
      if (nowEvidence.isEmpty) {
        reasons.add(ExplainableConclusionBlockReason.missingNowEvidence);
      }
      if (thenEvidence.isNotEmpty && nowEvidence.isNotEmpty) {
        final datedThen = thenEvidence
            .where((item) => item.sourceCapturedAt != null)
            .toList(growable: false);
        final datedNow = nowEvidence
            .where((item) => item.sourceCapturedAt != null)
            .toList(growable: false);
        final thenSource = datedThen.isEmpty
            ? thenEvidence.first
            : datedThen.reduce(
                (earlier, item) =>
                    item.sourceCapturedAt!.isBefore(earlier.sourceCapturedAt!)
                    ? item
                    : earlier,
              );
        final nowSource = datedNow.isEmpty
            ? nowEvidence.first
            : datedNow.reduce(
                (later, item) =>
                    item.sourceCapturedAt!.isAfter(later.sourceCapturedAt!)
                    ? item
                    : later,
              );
        final thenAt = thenSource.sourceCapturedAt;
        final nowAt = nowSource.sourceCapturedAt;
        if (thenSource.entryId == nowSource.entryId ||
            thenAt == null ||
            nowAt == null ||
            !thenAt.isBefore(nowAt)) {
          reasons.add(
            ExplainableConclusionBlockReason.changeRequiresDistinctSources,
          );
        }
        if (_normalizedEvidence(thenSource.quote) ==
            _normalizedEvidence(nowSource.quote)) {
          reasons.add(
            ExplainableConclusionBlockReason.changeEvidenceNotDistinct,
          );
        }
      }
    }

    final cap = evidenceConfidenceCap(conclusion.evidence);
    if (conclusion.confidence >= 0 &&
        conclusion.confidence <= 100 &&
        conclusion.confidence > cap) {
      reasons.add(
        ExplainableConclusionBlockReason.confidenceExceedsEvidenceCap,
      );
    }

    return ExplainableConclusionValidationResult._(
      conclusion: conclusion,
      blockReasons: List.unmodifiable(reasons),
      evidenceConfidenceCap: cap,
    );
  }

  static int evidenceConfidenceCap(List<TranscriptEvidenceCitation> evidence) {
    final supporting = evidence
        .where((item) => item.role == TranscriptEvidenceRole.supporting)
        .toList(growable: false);
    final supportingCount = supporting
        .map((item) => item.entryId)
        .toSet()
        .length;
    final contradictingCount = evidence
        .where((item) => item.role == TranscriptEvidenceRole.contradicting)
        .length;
    final base = switch (supportingCount) {
      0 => 0,
      1 => 70,
      2 => 85,
      _ => 95,
    };
    final structuralCap = (base - (contradictingCount.clamp(0, 3) * 15)).clamp(
      0,
      95,
    );
    final evidenceQualityCap = supporting.isEmpty
        ? 0
        : (supporting
                      .map((item) => item.confidenceScore)
                      .reduce((a, b) => a < b ? a : b) *
                  100)
              .round()
              .clamp(0, 100);
    return structuralCap < evidenceQualityCap
        ? structuralCap
        : evidenceQualityCap;
  }

  static bool _hasMinimumTopicAlignment(
    String statement,
    List<TranscriptEvidenceCitation> supporting,
  ) {
    final statementTokens = _contentTokens(statement);
    final evidenceTokens = {
      for (final citation in supporting) ..._contentTokens(citation.quote),
    };
    if (evidenceTokens.isEmpty) return true;
    return statementTokens.intersection(evidenceTokens).length >=
        minimumTopicAlignment;
  }

  static bool _hasTopicDomainMismatch(
    String statement,
    List<TranscriptEvidenceCitation> evidence,
  ) {
    final claimTokens = _allTokens(statement);
    final evidenceTokens = evidence
        .expand((citation) => _allTokens(citation.quote))
        .toSet();
    final claimRelationship = claimTokens.intersection(_relationshipDomain);
    final claimWork = claimTokens.intersection(_workDomain);
    final evidenceRelationship = evidenceTokens.intersection(
      _relationshipDomain,
    );
    final evidenceWork = evidenceTokens.intersection(_workDomain);
    if (claimRelationship.isNotEmpty &&
        claimWork.isEmpty &&
        evidenceWork.isNotEmpty &&
        evidenceRelationship.isEmpty) {
      return true;
    }
    return claimWork.isNotEmpty &&
        claimRelationship.isEmpty &&
        evidenceRelationship.isNotEmpty &&
        evidenceWork.isEmpty;
  }

  static Set<String> _allTokens(String value) => _word
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .toSet();

  static const _relationshipDomain = {
    'relationship',
    'partner',
    'friend',
    'friendship',
    'family',
    'mother',
    'father',
    'sister',
    'brother',
  };
  static const _workDomain = {
    'work',
    'job',
    'project',
    'meeting',
    'deadline',
    'manager',
    'colleague',
    'client',
  };

  static Set<String> _contentTokens(String value) => _word
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .where((token) => token.length >= 4 && !_stopWords.contains(token))
      .map(_normalizedTopicToken)
      .toSet();

  static String _normalizedTopicToken(String token) => switch (token) {
    'answered' ||
    'answering' ||
    'response' ||
    'responded' ||
    'responding' => 'answer',
    'checked' || 'checking' => 'check',
    _ => token,
  };

  static int _compactLength(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').length;

  /// A quote earns its place by carrying content, not length.
  ///
  /// "I stopped." is short but complete and citable. "of the" is the same
  /// length and says nothing, so it cannot stand as evidence.
  static bool _isMeaningfulQuote(String quote) {
    final words = _word
        .allMatches(quote.toLowerCase())
        .map((match) => match.group(0)!)
        .toList(growable: false);
    if (words.isEmpty) return false;
    final content = words
        .where((word) => !_quoteStopWords.contains(word))
        .toList(growable: false);
    return content.length >= minimumQuoteContentWords;
  }

  static const _quoteStopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'been',
    'but',
    'by',
    'for',
    'from',
    'had',
    'has',
    'have',
    'he',
    'her',
    'him',
    'his',
    'i',
    'if',
    'in',
    'is',
    'it',
    'its',
    'me',
    'my',
    'of',
    'on',
    'or',
    'our',
    'she',
    'so',
    'that',
    'the',
    'their',
    'them',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'to',
    'us',
    'was',
    'we',
    'were',
    'with',
    'you',
    'your',
  };

  static bool _splitsSurrogatePair(String value, int boundary) {
    if (boundary <= 0 || boundary >= value.length) return false;
    final before = value.codeUnitAt(boundary - 1);
    final after = value.codeUnitAt(boundary);
    return _isHighSurrogate(before) && _isLowSurrogate(after);
  }

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

  static bool _isLowSurrogate(int codeUnit) =>
      codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

  static String _normalizedEvidence(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[\u2018\u2019]'), "'")
      .replaceAll(RegExp('[\u201c\u201d]'), '"')
      .replaceAll(RegExp(r'\s+'), ' ');
}
