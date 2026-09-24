/// Aggregate outcome from running the first-pattern QA harness.
class FirstPatternQualityResult {
  const FirstPatternQualityResult({
    required this.total,
    required this.accepted,
    required this.rejected,
    required this.fallbackCount,
    required this.lowConfidenceCount,
    required this.correctionRecommendedCount,
    required this.accuracyRate,
    required this.categoryBreakdown,
    required this.failures,
    required this.overconfidentWrongCount,
    required this.vagueFallbackAcceptedCount,
    required this.negationHandledCount,
    required this.ambiguousHandledCount,
    required this.vagueNeutralSampleCount,
    required this.ambiguousSampleCount,
    required this.negationSampleCount,
  });

  final int total;
  final int accepted;
  final int rejected;
  final int fallbackCount;
  final int lowConfidenceCount;
  final int correctionRecommendedCount;
  final double accuracyRate;
  final Map<String, int> categoryBreakdown;
  final List<FirstPatternQualityFailure> failures;
  final int overconfidentWrongCount;
  final int vagueFallbackAcceptedCount;
  final int negationHandledCount;
  final int ambiguousHandledCount;
  final int vagueNeutralSampleCount;
  final int ambiguousSampleCount;
  final int negationSampleCount;

  static const double hardAccuracyMinimum = 0.85;
  static const double overconfidentThreshold = 0.65;

  bool get passesHardQaGates {
    if (accuracyRate < hardAccuracyMinimum) return false;
    if (overconfidentWrongCount > 0) return false;
    if (vagueNeutralSampleCount > 0 &&
        vagueFallbackAcceptedCount < (vagueNeutralSampleCount * 0.6).ceil()) {
      return false;
    }
    if (ambiguousSampleCount > 0 && ambiguousHandledCount == 0) return false;
    return true;
  }

  String get summaryText {
    final pct = (accuracyRate * 100).toStringAsFixed(1);
    final buffer = StringBuffer()
      ..writeln('First pattern QA: $pct% accuracy ($accepted/$total accepted)')
      ..writeln('Rejected: $rejected | Fallback: $fallbackCount')
      ..writeln(
        'Low confidence: $lowConfidenceCount | Correction recommended: $correctionRecommendedCount',
      )
      ..writeln(
        'Overconfident wrong: $overconfidentWrongCount | '
        'Vague/neutral OK: $vagueFallbackAcceptedCount/$vagueNeutralSampleCount',
      )
      ..writeln(
        'Negation handled: $negationHandledCount/$negationSampleCount | '
        'Ambiguous handled: $ambiguousHandledCount/$ambiguousSampleCount',
      )
      ..writeln('Hard gates pass: $passesHardQaGates')
      ..writeln('Category breakdown (accepted):');
    for (final entry in categoryBreakdown.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
    if (failures.isNotEmpty) {
      buffer.writeln('Failures (${failures.length}):');
      for (final f in failures.take(12)) {
        buffer.writeln(
          '  [${f.sampleId}] expected=${f.expectedCategory} actual="${f.actualTitle}" '
          'confidence=${f.confidenceScore.toStringAsFixed(2)}',
        );
        buffer.writeln('    reflection: ${f.reflectionText}');
        buffer.writeln('    reason: ${f.matchReason}');
      }
      if (failures.length > 12) {
        buffer.writeln('  … and ${failures.length - 12} more');
      }
    }
    return buffer.toString();
  }
}

class FirstPatternQualityFailure {
  const FirstPatternQualityFailure({
    required this.sampleId,
    required this.reflectionText,
    required this.expectedCategory,
    required this.actualTitle,
    required this.confidenceScore,
    required this.matchReason,
  });

  final String sampleId;
  final String reflectionText;
  final String expectedCategory;
  final String actualTitle;
  final double confidenceScore;
  final String matchReason;
}
