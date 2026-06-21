import 'package:flutter/foundation.dart';

import '../archive_evidence/archive_evidence_heuristics.dart';
import 'patterns_human_copy.dart';
import 'transcript_evidence_extractor.dart';

enum PatternCopySource { evidenceFirst, fallback, highConfidencePressure }

class EvidenceFirstPatternCopyInput {
  const EvidenceFirstPatternCopyInput({
    required this.transcripts,
    required this.evidenceCount,
    required this.entryCount,
    required this.confidence,
    this.candidateTheme,
    this.possibleRepeat = false,
    this.analysisAvailable = true,
    this.confidenceBand,
  });

  final List<String> transcripts;
  final int evidenceCount;
  final int entryCount;
  final double confidence;
  final String? candidateTheme;
  final bool possibleRepeat;
  final bool analysisAvailable;
  final ArchiveConfidenceBand? confidenceBand;

  factory EvidenceFirstPatternCopyInput.fromHumanInput(
    PatternHumanCopyInput input,
  ) {
    return EvidenceFirstPatternCopyInput(
      transcripts: input.allTranscriptText,
      evidenceCount: input.evidenceCount,
      entryCount: input.entryCount,
      confidence: input.confidenceScore ?? 0,
      candidateTheme: input.candidateTheme,
      possibleRepeat: input.possibleRepeat,
      analysisAvailable: input.analysisAvailable,
      confidenceBand: input.confidenceBand,
    );
  }
}

class EvidenceFirstPatternCopyBundle {
  const EvidenceFirstPatternCopyBundle({
    required this.source,
    required this.heroTitle,
    required this.heroBody,
    required this.cardTitle,
    required this.exactEvidencePhrases,
    required this.evidencePhrasesLabel,
    required this.interpretation,
    required this.interpretationLabel,
    required this.confidenceCopy,
    required this.whatToNoticeNext,
    required this.whatToNoticeLabel,
    required this.ctaText,
  });

  final PatternCopySource source;
  final String heroTitle;
  final String heroBody;
  final String cardTitle;
  final List<String> exactEvidencePhrases;
  final String evidencePhrasesLabel;
  final String interpretation;
  final String interpretationLabel;
  final String confidenceCopy;
  final String whatToNoticeNext;
  final String whatToNoticeLabel;
  final String ctaText;
}

abstract class EvidenceFirstPatternCopyResolver {
  EvidenceFirstPatternCopyResolver._();

  static const _highConfidenceThreshold = 0.68;
  static const _minRepeatedPhrases = 2;

  static EvidenceFirstPatternCopyBundle resolve(
    EvidenceFirstPatternCopyInput input,
  ) {
    final repeatedPhrases = TranscriptEvidenceExtractor.extractRepeatedPhrases(
      input.transcripts,
    );

    if (!input.analysisAvailable ||
        input.evidenceCount < 2 ||
        repeatedPhrases.length < _minRepeatedPhrases) {
      _logFallback('not_enough_repeated_words');
      return _fallbackBundle(input);
    }

    final pressureTheme =
        TranscriptEvidenceExtractor.hasPressureWorkTheme(repeatedPhrases);
    final source = _copySource(input, repeatedPhrases, pressureTheme);

    _log(
      evidenceCount: input.evidenceCount,
      repeatedPhrases: repeatedPhrases,
      confidence: input.confidence,
      source: source,
    );

    return EvidenceFirstPatternCopyBundle(
      source: source,
      heroTitle: PatternHumanCopy.evidenceFirstHeroTitle,
      heroBody: pressureTheme
          ? PatternHumanCopy.evidenceFirstHeroBodyPressure
          : PatternHumanCopy.evidenceFirstHeroBodyGeneric,
      cardTitle: PatternHumanCopy.evidenceFirstCardTitle,
      exactEvidencePhrases: repeatedPhrases,
      evidencePhrasesLabel: PatternHumanCopy.repeatedWordsLabel,
      interpretation: _interpretation(
        repeatedPhrases: repeatedPhrases,
        pressureTheme: pressureTheme,
        source: source,
      ),
      interpretationLabel: PatternHumanCopy.interpretationLabel,
      confidenceCopy: _confidenceCopy(input.confidence, source),
      whatToNoticeNext: pressureTheme
          ? PatternHumanCopy.evidenceFirstWhatToNoticePressure
          : PatternHumanCopy.evidenceFirstWhatToNoticeGeneric,
      whatToNoticeLabel: PatternHumanCopy.whatToNoticeLabel,
      ctaText: PatternHumanCopy.fallbackCta,
    );
  }

  static PatternCopySource _copySource(
    EvidenceFirstPatternCopyInput input,
    List<String> repeatedPhrases,
    bool pressureTheme,
  ) {
    if (pressureTheme &&
        input.evidenceCount >= 3 &&
        input.confidence >= _highConfidenceThreshold &&
        input.possibleRepeat &&
        repeatedPhrases.length >= _minRepeatedPhrases) {
      return PatternCopySource.highConfidencePressure;
    }
    return PatternCopySource.evidenceFirst;
  }

  static String _interpretation({
    required List<String> repeatedPhrases,
    required bool pressureTheme,
    required PatternCopySource source,
  }) {
    if (pressureTheme) {
      if (source == PatternCopySource.highConfidencePressure) {
        return PatternHumanCopy.evidenceFirstInterpretationPressureStrong;
      }
      return PatternHumanCopy.evidenceFirstInterpretationPressure;
    }
    return PatternHumanCopy.evidenceFirstInterpretationGeneric;
  }

  static String _confidenceCopy(double confidence, PatternCopySource source) {
    return PatternHumanCopy.evidenceFirstConfidenceCautious;
  }

  static EvidenceFirstPatternCopyBundle _fallbackBundle(
    EvidenceFirstPatternCopyInput input,
  ) {
    return EvidenceFirstPatternCopyBundle(
      source: PatternCopySource.fallback,
      heroTitle: PatternHumanCopy.fallbackEvidenceFirstHeroTitle,
      heroBody: PatternHumanCopy.fallbackEvidenceFirstHeroBody,
      cardTitle: PatternHumanCopy.evidenceFirstCardTitle,
      exactEvidencePhrases: const [],
      evidencePhrasesLabel: PatternHumanCopy.repeatedWordsLabel,
      interpretation: PatternHumanCopy.fallbackMainObservationEvidence,
      interpretationLabel: PatternHumanCopy.interpretationLabel,
      confidenceCopy: PatternHumanCopy.evidenceFirstConfidenceCautious,
      whatToNoticeNext: PatternHumanCopy.fallbackWhatToNoticeEvidence,
      whatToNoticeLabel: PatternHumanCopy.whatToNoticeLabel,
      ctaText: PatternHumanCopy.fallbackCta,
    );
  }

  static PatternHumanCopyBundle toHumanCopyBundle(
    EvidenceFirstPatternCopyBundle copy,
  ) {
    final kind = switch (copy.source) {
      PatternCopySource.evidenceFirst => PatternHumanCopyKind.evidenceFirst,
      PatternCopySource.highConfidencePressure =>
        PatternHumanCopyKind.highConfidencePressure,
      PatternCopySource.fallback => PatternHumanCopyKind.fallback,
    };

    return PatternHumanCopyBundle(
      kind: kind,
      heroTitle: copy.heroTitle,
      heroBody: copy.heroBody,
      cardTitle: copy.cardTitle,
      mainObservation: copy.interpretation,
      evidenceLabel: copy.evidencePhrasesLabel,
      evidenceBody: copy.exactEvidencePhrases.isEmpty
          ? PatternHumanCopy.fallbackEvidenceBody
          : copy.exactEvidencePhrases.join(', '),
      exactEvidencePhrases: copy.exactEvidencePhrases,
      interpretationLabel: copy.interpretationLabel,
      whatChangedTitle: PatternHumanCopy.confidenceLabel,
      whatChangedBody: copy.confidenceCopy,
      whatToTestTitle: copy.whatToNoticeLabel,
      whatToTestBody: copy.whatToNoticeNext,
      threadOverTimeTitle: PatternHumanCopy.threadOverTimeTitle,
      firstAppearedLabel: PatternHumanCopy.firstAppearedLabel,
      returnedLabel: PatternHumanCopy.returnedLabel,
      currentSignalLabel: PatternHumanCopy.currentSignalLabel,
      firstAppearedBody: PatternHumanCopy.genericThreadBody,
      returnedBody: PatternHumanCopy.genericThreadBody,
      currentSignalBody: PatternHumanCopy.currentSignalBody,
      ctaText: copy.ctaText,
      worthWatchingLine: copy.confidenceCopy,
      copySource: copy.source,
    );
  }

  static void _log({
    required int evidenceCount,
    required List<String> repeatedPhrases,
    required double confidence,
    required PatternCopySource source,
  }) {
    final phraseList = repeatedPhrases.join('|');
    debugPrint(
      'ARCHIVEME_EVIDENCE_FIRST_COPY evidenceCount=$evidenceCount '
      'repeatedPhrases=$phraseList confidence=${confidence.toStringAsFixed(2)}',
    );
    debugPrint(
      'ARCHIVEME_PATTERN_COPY_SOURCE source=${source.name}',
    );
  }

  static void _logFallback(String reason) {
    debugPrint('ARCHIVEME_EVIDENCE_FIRST_COPY_FALLBACK reason=$reason');
    debugPrint('ARCHIVEME_PATTERN_COPY_SOURCE source=fallback');
  }
}
