import 'dart:math' as math;

import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/jargon_aware_analyzer.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Passive biomarker processing from voice journal transcripts.
class CognitiveAnalyzer {
  const CognitiveAnalyzer({JargonAwareAnalyzer? jargonAnalyzer})
    : _jargonAnalyzer = jargonAnalyzer ?? const JargonAwareAnalyzer();

  final JargonAwareAnalyzer _jargonAnalyzer;

  /// Attaches transcript-derived biomarkers before journal persistence.
  JournalEntry enrichEntry(JournalEntry entry) {
    final biomarkers = analyzeTranscript(entry.transcript);
    if (entry.biomarkers == biomarkers) return entry;
    return entry.copyWith(biomarkers: biomarkers);
  }

  CognitiveBiomarkers analyzeTranscript(String transcript) {
    final tokens = _tokenize(transcript);
    return CognitiveBiomarkers(
      lexicalDiversity: _lexicalDiversity(transcript),
      cohesionDrift: _cohesionDrift(transcript),
      emotionalVolatility: _emotionalVolatility(transcript, tokens),
    );
  }

  double _lexicalDiversity(String transcript) {
    if (transcript.trim().isEmpty) return 1;
    return _jargonAnalyzer.calculateNormalizedTtr(transcript);
  }

  static List<String> _tokenize(String transcript) {
    final cleaned = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];
    return cleaned.split(' ');
  }

  static double _cohesionDrift(String transcript) {
    final sentences = transcript
        .split(RegExp('[.!?]+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();
    if (sentences.length < 2) return 0;

    final sentenceWordCounts = sentences
        .map((sentence) => _tokenize(sentence).length)
        .toList();
    if (sentenceWordCounts.every((count) => count == 0)) return 0;

    final mean =
        sentenceWordCounts.reduce((a, b) => a + b) / sentenceWordCounts.length;
    if (mean == 0) return 0;

    final variance =
        sentenceWordCounts
            .map((count) {
              final delta = count - mean;
              return delta * delta;
            })
            .reduce((a, b) => a + b) /
        sentenceWordCounts.length;

    final coefficientOfVariation = math.sqrt(variance) / mean;
    return coefficientOfVariation.clamp(0.0, 1.0);
  }

  static double _emotionalVolatility(String transcript, List<String> tokens) {
    if (transcript.trim().isEmpty) return 0;

    final wordCount = tokens.isEmpty ? 1 : tokens.length;

    final exclamationScore = ('!'.allMatches(transcript).length / wordCount * 2)
        .clamp(0.0, 1.0);

    final letterMatches = RegExp('[A-Za-z]').allMatches(transcript);
    var capsIntensity = 0.0;
    if (letterMatches.isNotEmpty) {
      var uppercaseLetters = 0;
      for (final match in letterMatches) {
        final char = transcript[match.start];
        if (char == char.toUpperCase() && char != char.toLowerCase()) {
          uppercaseLetters++;
        }
      }
      capsIntensity = (uppercaseLetters / letterMatches.length).clamp(0.0, 1.0);
    }

    final emphasisMatches = RegExp(
      r'[!?]{2,}|\b[A-Z]{2,}\b',
    ).allMatches(transcript).length;
    final emphasisScore = (emphasisMatches / wordCount * 3).clamp(0.0, 1.0);

    return ((exclamationScore + capsIntensity + emphasisScore) / 3).clamp(
      0.0,
      1.0,
    );
  }
}